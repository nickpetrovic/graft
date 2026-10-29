#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
WORK="$(mktemp -d /tmp/graft-icon.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

swift "$ROOT/scripts/draw-icon.swift" "$WORK/icon-1024.png"
mkdir "$WORK/AppIcon.iconset"
for size in 16 32 128 256 512; do
  sips -z $size $size "$WORK/icon-1024.png" --out "$WORK/AppIcon.iconset/icon_${size}x${size}.png" > /dev/null
  sips -z $((size * 2)) $((size * 2)) "$WORK/icon-1024.png" --out "$WORK/AppIcon.iconset/icon_${size}x${size}@2x.png" > /dev/null
done
iconutil -c icns "$WORK/AppIcon.iconset" -o "$ROOT/Resources/AppIcon.icns"
print "wrote Resources/AppIcon.icns"
