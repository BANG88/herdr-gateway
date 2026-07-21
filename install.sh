#!/usr/bin/env sh
# One-command install and update for the Herdr Gateway plugin.
#
#   curl -fsSL https://raw.githubusercontent.com/BANG88/herdr-gateway/main/install.sh | sh
#
# Re-running updates to the latest: Herdr has no separate update step, so a
# reinstall refreshes the managed plugin. macOS and Linux only for now.
set -eu

REPO="BANG88/herdr-gateway"
PLUGIN_ID="herdr.gateway"

green() { printf '\033[1;32m%s\033[0m\n' "$1"; }
info()  { printf '\033[1;36m==>\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m!\033[0m  %s\n' "$1"; }
die()   { printf '\033[1;31mError:\033[0m %s\n' "$1" >&2; exit 1; }

# 1. Operating system -- Windows is not supported yet.
case "$(uname -s)" in
  Darwin) info "Detected macOS" ;;
  Linux)  info "Detected Linux" ;;
  *)      die "Unsupported OS '$(uname -s)'. macOS and Linux only for now." ;;
esac

# 2. Herdr itself must be installed -- it hosts the plugin.
command -v herdr >/dev/null 2>&1 \
  || die "Herdr is not installed. Get it from https://herdr.dev first."

# 3. Install downloads a prebuilt binary, so Rust is optional -- only needed as
#    a fallback when no release binary matches this OS/arch.
if ! command -v cargo >/dev/null 2>&1; then
  warn "Rust (cargo) not found. That is fine -- a prebuilt binary will be used."
  echo "   (If none matches your platform, install Rust from https://rustup.rs and retry.)"
fi

# 4. Install or update. Reinstalling a GitHub-managed plugin replaces its
#    checkout in place -- no uninstall needed. A local dev link is the one case
#    Herdr refuses to install over, so detect it and explain instead of failing.
existing="$(herdr plugin list 2>/dev/null | grep "$PLUGIN_ID" || true)"
if printf '%s' "$existing" | grep -q '\[local:'; then
  warn "Herdr Gateway is installed as a local dev link, not a GitHub plugin."
  echo "   Update that checkout in place:"
  echo "     git -C <your-checkout> pull && cargo build --release"
  echo "   Or switch to the GitHub-managed version:"
  echo "     herdr plugin unlink $PLUGIN_ID && herdr plugin install $REPO --yes"
  exit 0
elif [ -n "$existing" ]; then
  info "Herdr Gateway is already installed -- updating to the latest..."
else
  info "Installing Herdr Gateway..."
fi
herdr plugin install "$REPO" --yes

green "Herdr Gateway is ready."
echo
echo "Next steps:"
echo "  1. Configure it once:   herdr plugin action invoke $PLUGIN_ID.setup"
echo "  2. Start it:            herdr plugin action invoke $PLUGIN_ID.start"
echo "  3. Show the pairing QR: herdr plugin pane open --plugin $PLUGIN_ID --entrypoint manage"
echo
echo "Then scan the QR from the Muqun app on a device on the same Tailscale network."
