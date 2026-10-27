#!/bin/sh
# Renders the AppIcon set from icon.svg.tmpl (needs rsvg-convert + ImageMagick).
# Usage: design/app-icon/generate.sh   (run from the repo root)
set -e
D=design/app-icon
OUT=lottoApp2/Assets.xcassets/AppIcon.appiconset
render() { # name BG0 BG1 GOLD0 GOLD1 CORAL0 CORAL1 TEAL0 TEAL1 CHAIN CHAINOP HLOP [gray]
  sed -e "s/@BG0@/$2/;s/@BG1@/$3/;s/@GOLD0@/$4/;s/@GOLD1@/$5/;s/@CORAL0@/$6/;s/@CORAL1@/$7/" \
      -e "s/@TEAL0@/$8/;s/@TEAL1@/$9/;s/@CHAIN@/${10}/;s/@CHAINOP@/${11}/;s/@HLOP@/${12}/" \
      $D/icon.svg.tmpl | rsvg-convert -w 1024 -h 1024 - -o /tmp/icon-$1.png
  EXTRA=""; [ -n "${13}" ] && EXTRA="-colorspace Gray"
  magick /tmp/icon-$1.png -background black -alpha remove -alpha off $EXTRA -depth 8 PNG24:$OUT/$1.png
  [ -n "${13}" ] && magick $OUT/$1.png -colorspace Gray -depth 8 PNG24:$OUT/$1.png || true
}
render AppIcon        "#3730A3" "#7C3AED" "#FFE27A" "#F5A800" "#FF9A8B" "#F0524F" "#6EE7D8" "#0F9D94" "#C7D2FE" 0.85 0.45
render AppIcon-Dark   "#14103A" "#3B1F7A" "#F2CF63" "#C98A00" "#F28678" "#C73E3B" "#58D4C5" "#0B7F78" "#A5B4FC" 0.7  0.3
render AppIcon-Tinted "#000000" "#2A2A2A" "#FFFFFF" "#B0B0B0" "#E0E0E0" "#808080" "#C8C8C8" "#707070" "#FFFFFF" 0.8  0.3 gray
for s in 16 32 128 256 512; do
  magick $OUT/AppIcon.png -resize ${s}x${s} PNG24:$OUT/mac-$s.png
  magick $OUT/AppIcon.png -resize $((s*2))x$((s*2)) PNG24:$OUT/mac-$s@2x.png
done
