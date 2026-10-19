#!/bin/bash
# Compile DiskWatch et installe l'app dans ~/Applications (ou le dossier passé en argument).
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="DiskWatch"
DEST="${1:-$HOME/Applications}"
APP="$DEST/$APP_NAME.app"
VERSION="2.1"
TARGET="arm64-apple-macos14.0"

echo "▸ Compilation ($(find "$SRC_DIR/Sources" -name '*.swift' | wc -l | tr -d ' ') fichiers)…"
mkdir -p "$SRC_DIR/.build"
# shellcheck disable=SC2046
swiftc -O -target "$TARGET" \
  -framework AppKit -framework SwiftUI -framework Charts \
  -framework UserNotifications -framework ServiceManagement \
  -o "$SRC_DIR/.build/$APP_NAME" \
  $(find "$SRC_DIR/Sources" -name '*.swift' | sort)

echo "▸ Construction du bundle…"
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.5
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv "$SRC_DIR/.build/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>              <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>       <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>        <string>com.unixsafe.diskwatch</string>
  <key>CFBundleExecutable</key>        <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>       <string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key>           <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>    <string>14.0</string>
  <key>LSUIElement</key>               <true/>
  <key>NSHumanReadableCopyright</key>  <string>UnixSafe — Licence MIT</string>
</dict>
</plist>
PLIST

echo "▸ Signature ad hoc…"
codesign --force --sign - "$APP"

rmdir "$SRC_DIR/.build" 2>/dev/null || true
echo "✅ Installé : $APP"
