#!/usr/bin/env bash
# Rasterizes the brand SVG into the 1024x1024 app icon (opaque, no alpha).
# Run from the repository root. Requires librsvg (rsvg-convert) and ImageMagick.
set -euo pipefail

SRC="art/loopline-icon.svg"
OUT="ios/Loopline/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
TMP="$(mktemp -t loopline-icon-XXXX).png"

rsvg-convert -w 1024 -h 1024 "$SRC" -o "$TMP"
# iOS app icons must be fully opaque — flatten onto the brand blue and drop alpha.
magick "$TMP" -background "#5468FF" -flatten -alpha remove -alpha off "PNG24:$OUT"
rm -f "$TMP"

echo "Wrote $OUT"
