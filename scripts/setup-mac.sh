#!/usr/bin/env bash
# Cockpit Mac Remote Setup
#
# Installs cloudflared + noVNC + websockify on this Mac, creates a Cloudflare
# Tunnel to mac.thegridbase.com, and sets everything up as launchd services so
# it survives reboots.
#
# Idempotent: safe to re-run. After first run, set up Cloudflare Access (see
# docs/CLOUDFLARE_ACCESS.md) and enable macOS Screen Sharing manually.

set -euo pipefail

DOMAIN="mac.thegridbase.com"
TUNNEL_NAME="cockpit-mac"
NOVNC_PATH="$HOME/.cockpit-mac/novnc"
WEBSOCKIFY_PORT=6080
VNC_PORT=5900
WS_PLIST="$HOME/Library/LaunchAgents/com.cockpit.websockify.plist"

color()  { printf "\033[%sm%s\033[0m\n" "$1" "$2"; }
ok()     { color "32" "✓ $1"; }
info()   { color "36" "→ $1"; }
warn()   { color "33" "! $1"; }
fatal()  { color "31" "✗ $1"; exit 1; }

# ─── Prerequisites ────────────────────────────────────────────────────────────
command -v brew >/dev/null 2>&1 || fatal "Homebrew required. Install from https://brew.sh"
command -v git  >/dev/null 2>&1 || brew install git

info "Installing cloudflared and websockify (idempotent)"
brew list cloudflared >/dev/null 2>&1 || brew install cloudflared
# websockify is a Python package — use pipx for isolation
if ! command -v websockify >/dev/null 2>&1; then
  brew list pipx >/dev/null 2>&1 || brew install pipx
  pipx ensurepath >/dev/null 2>&1 || true
  pipx install websockify
fi
# pipx installs to ~/.local/bin which may not be on PATH yet in this shell
export PATH="$HOME/.local/bin:$PATH"
ok "tools ready"

# ─── noVNC ────────────────────────────────────────────────────────────────────
if [ ! -d "$NOVNC_PATH" ]; then
  info "Downloading noVNC"
  mkdir -p "$(dirname "$NOVNC_PATH")"
  git clone --depth 1 https://github.com/novnc/noVNC.git "$NOVNC_PATH"
fi
# Replace the index.html with our custom keyboard overlay
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CUSTOM_INDEX="$REPO_ROOT/novnc-custom/index.html"
if [ -f "$CUSTOM_INDEX" ]; then
  rm -f "$NOVNC_PATH/index.html"
  cp "$CUSTOM_INDEX" "$NOVNC_PATH/index.html"
  ok "noVNC custom keyboard overlay installed"
else
  if [ ! -e "$NOVNC_PATH/index.html" ] || [ -L "$NOVNC_PATH/index.html" ]; then
    ln -sf vnc.html "$NOVNC_PATH/index.html"
  fi
  warn "custom overlay not found at $CUSTOM_INDEX — using default noVNC"
fi

# ─── Cloudflare auth ──────────────────────────────────────────────────────────
if [ ! -f "$HOME/.cloudflared/cert.pem" ]; then
  info "Cloudflare login — browser will open. Pick thegridbase.com when asked."
  cloudflared tunnel login
fi
ok "cloudflared authenticated"

# ─── Tunnel ───────────────────────────────────────────────────────────────────
if ! cloudflared tunnel list 2>/dev/null | awk '{print $2}' | grep -qx "$TUNNEL_NAME"; then
  info "Creating tunnel: $TUNNEL_NAME"
  cloudflared tunnel create "$TUNNEL_NAME"
fi
TUNNEL_ID=$(cloudflared tunnel list | awk -v n="$TUNNEL_NAME" '$2==n {print $1}')
[ -n "$TUNNEL_ID" ] || fatal "Tunnel creation failed"
ok "tunnel $TUNNEL_ID"

mkdir -p "$HOME/.cloudflared"
cat > "$HOME/.cloudflared/config.yml" <<YAML
tunnel: $TUNNEL_ID
credentials-file: $HOME/.cloudflared/$TUNNEL_ID.json
ingress:
  - hostname: $DOMAIN
    service: http://localhost:$WEBSOCKIFY_PORT
  - service: http_status:404
YAML
ok "tunnel config written"

info "Routing DNS $DOMAIN → tunnel"
cloudflared tunnel route dns "$TUNNEL_NAME" "$DOMAIN" 2>&1 | grep -v "already exists" || true

# ─── cloudflared as launchd service ───────────────────────────────────────────
info "Installing cloudflared as launchd service (sudo prompt incoming)"
if sudo launchctl list 2>/dev/null | grep -q "com.cloudflare.cloudflared"; then
  sudo cloudflared service uninstall 2>/dev/null || true
fi
sudo cloudflared service install
# Service runs as root and reads config from /etc/cloudflared
sudo mkdir -p /etc/cloudflared
sudo cp "$HOME/.cloudflared/config.yml" /etc/cloudflared/
sudo cp "$HOME/.cloudflared/$TUNNEL_ID.json" /etc/cloudflared/
# cloudflared 2026.3 service install bug: ProgramArguments missing tunnel run + config
# Patch the plist to add the required args.
PLIST_PATH="/Library/LaunchDaemons/com.cloudflare.cloudflared.plist"
if sudo plutil -p "$PLIST_PATH" 2>/dev/null | grep -q '"--config"'; then
  : # already patched
else
  sudo plutil -insert ProgramArguments.1 -string "--no-autoupdate" "$PLIST_PATH"
  sudo plutil -insert ProgramArguments.2 -string "--config" "$PLIST_PATH"
  sudo plutil -insert ProgramArguments.3 -string "/etc/cloudflared/config.yml" "$PLIST_PATH"
  sudo plutil -insert ProgramArguments.4 -string "tunnel" "$PLIST_PATH"
  sudo plutil -insert ProgramArguments.5 -string "run" "$PLIST_PATH"
fi
sudo launchctl bootout system/com.cloudflare.cloudflared 2>/dev/null || true
sudo launchctl bootstrap system "$PLIST_PATH"
ok "cloudflared service installed and started"

# ─── websockify launchd agent ─────────────────────────────────────────────────
info "Installing websockify as launchd agent"
WEBSOCKIFY_BIN=$(command -v websockify)
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$WS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.cockpit.websockify</string>
  <key>ProgramArguments</key>
  <array>
    <string>$WEBSOCKIFY_BIN</string>
    <string>--web</string>
    <string>$NOVNC_PATH</string>
    <string>$WEBSOCKIFY_PORT</string>
    <string>localhost:$VNC_PORT</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/cockpit-websockify.log</string>
  <key>StandardErrorPath</key><string>/tmp/cockpit-websockify.log</string>
</dict>
</plist>
PLIST
launchctl unload "$WS_PLIST" 2>/dev/null || true
launchctl load -w "$WS_PLIST"
ok "websockify service running on :$WEBSOCKIFY_PORT"

# ─── Summary ──────────────────────────────────────────────────────────────────
cat <<DONE

$(color 32 "════════════════════════════════════════════════════════════════")
$(color 32 "Setup complete")
$(color 32 "════════════════════════════════════════════════════════════════")

Now do these THREE manual steps:

  1. Turn on macOS Screen Sharing
     • System Settings → General → Sharing → Screen Sharing  [ON]
     • Click the (i) next to it → "Allow access for: Only these users"
       Add yourself. Set a strong VNC password (16+ chars):
       "VNC viewers may control screen with password" → set
     • Keep the Mac awake:
       System Settings → Lock Screen → "Turn display off on battery..." Never
       (or use 'caffeinate -d' when needed)

  2. Set up Cloudflare Access (5 min, free)
     Open docs/CLOUDFLARE_ACCESS.md and follow it.

  3. Test
     → Visit https://$DOMAIN from any browser (your laptop first):
       a. You'll see a Cloudflare Access Google login.
       b. After login, noVNC connect screen opens.
       c. Click "Connect" → enter your VNC password.
       d. Your Mac screen appears.
     → Then test from Tesla: Cockpit → Mac card → same flow.

Tail logs:
  cloudflared:  sudo log show --predicate 'process == "cloudflared"' --last 5m
  websockify:   tail -f /tmp/cockpit-websockify.log

Uninstall:
  sudo cloudflared service uninstall
  launchctl unload $WS_PLIST
  rm -rf $NOVNC_PATH $WS_PLIST $HOME/.cloudflared
DONE
