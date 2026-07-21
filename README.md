# Herdr Gateway

Rust Herdr plugin and token-protected mobile gateway for Muqun.

Herdr Gateway exposes a small HTTP API for reading Herdr workspaces, tabs, panes,
agents, pane output, and sending pane input. It talks to the local Herdr socket
API and is intended to be reached from trusted devices over a private network
such as Tailscale.

## Install

One command that checks your system and installs the plugin (macOS and Linux;
Windows is not supported yet):

```sh
curl -fsSL https://raw.githubusercontent.com/BANG88/herdr-gateway/main/install.sh | sh
```

It needs [Herdr](https://herdr.dev). Install downloads a prebuilt binary for
your platform, so no Rust toolchain is required -- it is only used as a fallback
if no release binary matches your OS/arch.

Or install directly with Herdr's plugin installer:

```sh
herdr plugin install BANG88/herdr-gateway
```

Run setup once:

```sh
herdr plugin action invoke herdr.gateway.setup
```

Start the gateway:

```sh
herdr plugin action invoke herdr.gateway.start
```

Open the manager panel to view the QR code, approve pairing requests, and start
or stop the gateway:

```sh
herdr plugin pane open --plugin herdr.gateway --entrypoint manage
```

In the manager panel, press `u` to edit the public gateway URL. Press `a` to
auto-detect it again. Saving the URL updates both the gateway config and the
pairing QR code.

Stop the gateway:

```sh
herdr plugin action invoke herdr.gateway.stop
```

## Update

Herdr has no separate update step, and **you do not need to uninstall first** --
reinstalling a GitHub-managed plugin replaces its checkout in place. Re-run the
same one command:

```sh
curl -fsSL https://raw.githubusercontent.com/BANG88/herdr-gateway/main/install.sh | sh
```

or reinstall directly:

```sh
herdr plugin install BANG88/herdr-gateway
```

Pin a specific version with `--ref`:

```sh
herdr plugin install BANG88/herdr-gateway --ref v0.3.0
```

After updating, restart the gateway so the new build takes over:

```sh
herdr plugin action invoke herdr.gateway.stop
herdr plugin action invoke herdr.gateway.start
```

> Working from a local checkout (`herdr plugin link .`)? Herdr refuses to install
> over a local link, so update it in place with `git pull && cargo build
> --release` instead, or `herdr plugin unlink herdr.gateway` first to switch to
> the GitHub-managed build.

## Development

Use `plugin link` while working from a local checkout:

```sh
cargo test
cargo build --release
herdr plugin link .
herdr plugin action invoke herdr.gateway.setup
herdr plugin action invoke herdr.gateway.start
herdr plugin pane open --plugin herdr.gateway --entrypoint manage
```

If you previously installed the GitHub-managed plugin, uninstall it before
linking a local checkout:

```sh
herdr plugin uninstall herdr.gateway
```

## Pairing

The manager panel displays a QR code for Muqun. The QR code contains only the
gateway URL and server ID:

```text
muqun://pair?u=<gateway_url>&s=<server_id>
```

It does not contain the bearer token.

The gateway URL is configurable. During `setup`, Herdr Gateway chooses a default
URL in this order:

1. `https://<tailscale-magic-name>` when Tailscale is running and Tailscale Serve appears to be forwarding the gateway port.
2. `http://<tailscale-ip>:23847` when Tailscale is running.
3. `http://127.0.0.1:23847` as a local fallback.

For automatic setup, the listener is restricted to the matching interface:
localhost for Tailscale Serve HTTPS, the detected Tailscale IPv4 address for
direct tailnet access, or localhost for the fallback. An explicit
`--public-url` keeps the listener on all interfaces because that mode is an
intentional user override.

You can override it from the manager panel with `u`. When running the binary
directly from a local checkout, `setup --public-url <url>` is also supported.

The port defaults to 23847 and is set with `setup --port <port>`. That default
sits outside the common service range and outside the Linux and macOS ephemeral
ranges, so it rarely collides with anything else on the machine. `start`,
`stop`, and the manager panel all read the port back from the config, and
`stop` only signals processes that really are the gateway.

For Tailscale HTTPS, configure Tailscale Serve to forward HTTPS traffic to the
local gateway port, then set the URL to the MagicDNS HTTPS name:

```text
https://<machine>.<tailnet>.ts.net
```

HTTPS through Tailscale Serve is recommended. Direct HTTP over a Tailscale IP
is supported for private tailnets, but its safety still depends on your
Tailscale ACLs and the security of every device in that tailnet.

Pairing flow:

1. Muqun scans the QR code.
2. Muqun sends a pairing request with a request ID and device name.
3. The manager panel hides the QR code and shows the device name plus a short confirmation code.
4. Enter the confirmation code in Muqun.
5. Muqun claims the pairing request and receives a token minted for that device.

Pending pairing state is held in gateway process memory and is not written to
disk.

## Devices and revocation

Every successful pairing mints a token belonging to that one device, stored
hashed in `devices.json`. Revoking a device cuts off only that device; the
others keep working.

There are two kinds of credential, and they are not interchangeable:

- **Device tokens** are the only thing that authorises a control route. They
  exist on the paired device and are stored hashed on the server.
- **The admin token** in `pairing.json` belongs to the local manager panel and
  authorises exactly one route, `GET /api/pair/pending`. It is never handed out
  to a device. Because it sits in plaintext on disk, it deliberately cannot
  reach the routes that run commands on the host.

```sh
herdr-gateway devices             # list paired devices and when each was last seen
herdr-gateway revoke <device_id>  # revoke one device
herdr-gateway revoke --all        # revoke every device
```

The same thing is available over the API, so Muqun can show and revoke devices
from its settings screen:

```text
GET    /api/pairings
DELETE /api/pairings/:deviceId
```

## API

OpenAPI documentation is available from the running gateway:

```text
GET /docs
GET /openapi.json
```

Control routes require a paired device's bearer token:

```http
Authorization: Bearer <device_token>
```

`POST /api/pair/request` and `POST /api/pair/claim` are unauthenticated, since
that is how a device gets its token. `GET /api/pair/pending` takes the admin
token instead of a device token.

Routes:

- `GET /health`
- `POST /api/pair/request`
- `POST /api/pair/claim`
- `GET /api/pair/pending`
- `GET /api/pairings`
- `DELETE /api/pairings/:deviceId`
- `POST /api/devices/push-token`
- `DELETE /api/devices/push-token`
- `GET /api/sessions`
- `GET /api/sessions/default/events`
- `GET /api/sessions/default/snapshot`
- `GET /api/sessions/default/workspaces`
- `POST /api/sessions/default/workspaces`
- `POST /api/sessions/default/workspaces/:workspaceId/focus`
- `PATCH /api/sessions/default/workspaces/:workspaceId`
- `DELETE /api/sessions/default/workspaces/:workspaceId`
- `GET /api/sessions/default/tabs`
- `POST /api/sessions/default/tabs`
- `POST /api/sessions/default/tabs/:tabId/focus`
- `PATCH /api/sessions/default/tabs/:tabId`
- `DELETE /api/sessions/default/tabs/:tabId`
- `GET /api/sessions/default/panes`
- `GET /api/sessions/default/panes/:paneId`
- `POST /api/sessions/default/panes/:paneId/focus`
- `PATCH /api/sessions/default/panes/:paneId`
- `DELETE /api/sessions/default/panes/:paneId`
- `POST /api/sessions/default/panes/:paneId/split`
- `GET /api/sessions/default/agents`
- `GET /api/sessions/default/agents/:target`
- `POST /api/sessions/default/agents/:target/focus`
- `POST /api/sessions/default/agents/:target/send`
- `GET /api/sessions/default/panes/:paneId/output?source=recent-unwrapped&lines=200`
- `POST /api/sessions/default/panes/:paneId/send-text`
- `POST /api/sessions/default/panes/:paneId/send-keys`

The gateway registers Muqun Expo push tokens and watches Herdr agent lifecycle
events in the background. It sends a notification when an agent becomes
blocked, and when an agent transitions from working to idle. Duplicate status
events are ignored; tapping a notification opens the matching server in Muqun.

## Compatibility and API versions

The Gateway API has its own Semantic Version (`apiVersion`), independent from
the Gateway binary version and the installed Herdr version. `/health` and the
authenticated `/api/meta` endpoint return the API version, capability names,
Gateway version, Herdr version, Herdr protocol, and the supported Herdr protocol
range. Muqun should feature-detect capabilities and treat missing version fields
as a legacy Gateway instead of rejecting the server.

Breaking Gateway API changes increment the API major version. Herdr
compatibility follows Herdr's socket protocol number rather than Herdr's package
version. Calendar dates may be appended as release build metadata, but are not
used to decide compatibility. Existing unversioned routes remain available for
older Muqun releases.

Pairing confirmation codes expire after two minutes and are consumed atomically
after the first successful claim. A consumed or expired code cannot be reused,
and eight failed attempts invalidate the pending code.

Security defaults:

- No raw Herdr API proxy is exposed.
- Control routes require a paired device's bearer token.
- The admin token cannot reach a control route, only the pending-pairing read.
- QR pairing does not expose any token.
- Each device gets its own token and can be revoked on its own.
- Token verification uses a constant-time hash comparison against every candidate.
- Device names are rejected if they contain control characters, so a pairing request cannot forge the manager panel with terminal escapes.
- `config.json`, `pairing.json`, and `devices.json` are written with `0600` permissions.
- `stop` only signals processes whose name matches the gateway.
- Pairing requests are rate-limited and confirmation codes permit only eight attempts.
- API responses disable caching and hide local backend error details.
- Push registrations are capped and can be removed when notifications are disabled.
- Pane output reads are capped at 1000 lines.
- Pane and agent text sends are capped at 64 KiB.
- Pane key sends are capped at 32 keys per request.

Prefer Tailscale Serve HTTPS whenever it is available. Direct HTTP over a
Tailscale IP remains supported for user-managed private networks, but HTTP does
not provide transport encryption by itself; the security of that connection
depends on the tailnet and its access controls.

## Publishing

Herdr discovers community plugins from public GitHub repositories tagged with
the `herdr-plugin` topic. The repository should contain `herdr-plugin.toml` at
the repository root, or in the subdirectory passed to `herdr plugin install`.

## License

MIT
