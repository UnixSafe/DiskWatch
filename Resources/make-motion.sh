#!/bin/bash
# Rend l'illustration animée du README : 120 images, puis assemblage en GIF.
set -euo pipefail
cd "$(dirname "$0")"
command -v ffmpeg >/dev/null || { echo "✗ ffmpeg requis"; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
echo "▸ Rendu des images…"
swift make-motion.swift "$TMP"

echo "▸ Assemblage du GIF…"
ffmpeg -y -loglevel error -framerate 20 -i "$TMP/f%03d.png" \
  -vf "scale=760:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
  -loop 0 ../docs/motion.gif

echo "✅ docs/motion.gif ($(du -h ../docs/motion.gif | cut -f1))"
