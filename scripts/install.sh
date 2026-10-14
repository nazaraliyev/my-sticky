#!/bin/bash
# Builds Nota.app, installs it into /Applications and registers it to start at login.
# Run once (and again only after changing the code) — no rebuild needed on reboot.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Nota"
DEST_DIR="/Applications"
[ -w "$DEST_DIR" ] || DEST_DIR="$HOME/Applications"
DEST="$DEST_DIR/$APP_NAME.app"

"$ROOT/scripts/make_app.sh"

echo "▶ Quitting running $APP_NAME (if any)…"
osascript -e "tell application id \"com.nazar.nota\" to quit" >/dev/null 2>&1 || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
  pgrep -x "$APP_NAME" >/dev/null || break
  sleep 0.5
done
pkill -x "$APP_NAME" 2>/dev/null || true

echo "▶ Installing to $DEST …"
mkdir -p "$DEST_DIR"
rm -rf "$DEST"
ditto "$ROOT/dist/$APP_NAME.app" "$DEST"

echo "▶ Launching and enabling start at login…"
open "$DEST" --args --enable-login-item

echo "✅ Installed: $DEST"
echo "   Starts automatically at login (toggle: menu bar → \"Login-da başlat\")."
