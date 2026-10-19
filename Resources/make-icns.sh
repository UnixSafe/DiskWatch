#!/bin/bash
# Rend l'icone en 1024 px puis assemble le .icns dans toutes les tailles.
set -euo pipefail
cd "$(dirname "$0")"

echo "▸ Rendu de l'illustration…"
swift make-icon.swift icon-1024.png

SET=DiskWatch.iconset
rm -rf "$SET"; mkdir "$SET"
for s in 16 32 64 128 256 512 1024; do
  sips -z $s $s icon-1024.png --out "$SET/icon_${s}x${s}.png" >/dev/null
done
# Variantes @2x attendues par iconutil
for s in 16 32 128 256 512; do
  cp "$SET/icon_$((s*2))x$((s*2)).png" "$SET/icon_${s}x${s}@2x.png"
done
rm -f "$SET/icon_64x64.png" "$SET/icon_1024x1024.png"

iconutil -c icns "$SET" -o DiskWatch.icns
rm -rf "$SET"
echo "✅ DiskWatch.icns ($(du -h DiskWatch.icns | cut -f1))"
