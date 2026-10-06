#!/bin/zsh
set -eu
cd "${0:A:h}/.."
APP="$PWD/build/Insomnia.app"
codesign --verify --deep --strict "$APP"
mkdir -p build/release
ARCH=$(lipo -archs "$APP/Contents/MacOS/Insomnia")
if [[ "$ARCH" != arm64 ]]; then
  print -u2 "Expected an arm64 release; found $ARCH"
  exit 1
fi
ditto -c -k --sequesterRsrc --keepParent "$APP" build/release/Insomnia-macOS-arm64.zip
(cd build/release && shasum -a 256 Insomnia-macOS-arm64.zip > SHA256SUMS)
print "Packaged build/release/Insomnia-macOS-arm64.zip"
