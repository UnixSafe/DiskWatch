#!/bin/bash
# Fabrique une image disque prete a distribuer, avec la fenetre
# « glissez l'application dans Applications ».
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(sed -n 's/^VERSION="\(.*\)"$/\1/p' build.sh)
APP=${1:-$HOME/Applications/DiskWatch.app}
VOL="DiskWatch $VERSION"
DMG="DiskWatch-$VERSION.dmg"

[ -d "$APP" ] || { echo "✗ Application introuvable : $APP"; echo "  Lance d'abord ./build.sh"; exit 1; }

echo "▸ Preparation…"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE" "$TMPDMG" 2>/dev/null || true' EXIT
cp -R "$APP" "$STAGE/DiskWatch.app"
ln -s /Applications "$STAGE/Applications"

# Image lecture-ecriture, le temps de poser la mise en page.
TMPDMG=$(mktemp -u).dmg
SIZE=$(( $(du -sm "$STAGE" | cut -f1) + 20 ))
hdiutil create -quiet -srcfolder "$STAGE" -volname "$VOL" \
  -fs HFS+ -format UDRW -size "${SIZE}m" "$TMPDMG"

echo "▸ Mise en page…"
DEV=$(hdiutil attach -readwrite -noverify -noautoopen "$TMPDMG" | grep '^/dev/' | head -1 | awk '{print $1}')
MNT="/Volumes/$VOL"
sleep 2

osascript <<AS >/dev/null 2>&1 || echo "  (mise en page ignoree : Finder indisponible)"
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 160, 740, 540}
    set theOptions to the icon view options of container window
    set arrangement of theOptions to not arranged
    set icon size of theOptions to 112
    set position of item "DiskWatch.app" of container window to {140, 190}
    set position of item "Applications" of container window to {400, 190}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
AS

sync
hdiutil detach "$DEV" -quiet || hdiutil detach "$DEV" -force -quiet

echo "▸ Compression…"
rm -f "$DMG"
hdiutil convert -quiet "$TMPDMG" -format UDZO -imagekey zlib-level=9 -o "$DMG"

echo "✅ $DMG  ($(du -h "$DMG" | cut -f1))"
echo
echo "L'application est signee « ad hoc ». Au premier lancement, macOS la"
echo "bloquera : clic droit sur DiskWatch.app ▸ Ouvrir, puis Ouvrir a nouveau."
