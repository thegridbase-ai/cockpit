#!/usr/bin/env bash
# One-shot fix for cloudflared 2026.3 service install bug.
# Run with: sudo bash ~/Documents/GitHub/cockpit/scripts/fix-cloudflared.sh
set -e

PLIST="/Library/LaunchDaemons/com.cloudflare.cloudflared.plist"

echo "==> Current ProgramArguments:"
plutil -p "$PLIST" | grep -A 10 ProgramArguments

# Wipe and rebuild the ProgramArguments array.
plutil -remove ProgramArguments "$PLIST"
plutil -insert ProgramArguments -json '["/opt/homebrew/bin/cloudflared","--no-autoupdate","--config","/etc/cloudflared/config.yml","tunnel","run"]' "$PLIST"

echo "==> Patched ProgramArguments:"
plutil -p "$PLIST" | grep -A 10 ProgramArguments

echo "==> Reloading service..."
launchctl bootout system/com.cloudflare.cloudflared 2>/dev/null || true
launchctl bootstrap system "$PLIST"

echo "==> Waiting 4s for tunnel to connect..."
sleep 4
launchctl print system/com.cloudflare.cloudflared 2>&1 | grep -E "state|last exit" | head -5
echo "✓ done"
