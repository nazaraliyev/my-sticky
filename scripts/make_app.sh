#!/bin/bash
# Builds Nota.app — a self-contained macOS app bundle from the SwiftPM binary.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Nota"
CONFIG="release"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

cd "$ROOT"

echo "▶ Building ($CONFIG)…"
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

echo "▶ Assembling $APP …"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/packaging/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

if [ -f "$ROOT/packaging/$APP_NAME.icns" ]; then
  cp "$ROOT/packaging/$APP_NAME.icns" "$APP/Contents/Resources/$APP_NAME.icns"
fi

echo "▶ Ad-hoc code signing…"
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "  (codesign skipped — app still runs locally)"

echo "✅ Built: $APP"
echo "   Run with:  open \"$APP\""
