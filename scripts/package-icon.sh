#!/bin/zsh
set -eu
cd "${0:A:h}/.."
mkdir -p Resources/AppIcon.iconset
for dimension in 16 32 128 256 512; do
 sips -z "$dimension" "$dimension" Resources/Insomnia-Icon.png --out "Resources/AppIcon.iconset/icon_${dimension}x${dimension}.png" >/dev/null
 doubled=$((dimension * 2))
 sips -z "$doubled" "$doubled" Resources/Insomnia-Icon.png --out "Resources/AppIcon.iconset/icon_${dimension}x${dimension}@2x.png" >/dev/null
done
iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
