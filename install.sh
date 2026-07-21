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

# 3. Rust builds the gateway during install. Point at the one-liner if missing.
if ! command -v cargo >/dev/null 2>&1; then
  warn "Rust (cargo) is required to build the gateway and was not found."
  echo "   Install it with:"
  echo "     curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
  die "Install Rust, open a new shell, then run this again."
fi

# 4. Install or update. The command is identical either way; a reinstall pulls
#    the latest and rebuilds. --yes keeps a piped run non-interactive.
if herdr plugin list 2>/dev/null | grep -q "$PLUGIN_ID"; then
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
