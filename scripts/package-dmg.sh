#!/bin/zsh
set -eu
cd "${0:A:h}/.."
APP="$PWD/build/Insomnia.app"
codesign --verify --deep --strict "$APP"
xcrun stapler validate "$APP"
STAGING="$PWD/build/dmg-staging"
mkdir -p "$STAGING" build/release
ditto "$APP" "$STAGING/Insomnia.app"
ln -sfn /Applications "$STAGING/Applications"
DMG="$PWD/build/release/Insomnia-macOS-arm64.dmg"
hdiutil create -ov -volname Insomnia -srcfolder "$STAGING" -format UDZO "$DMG"
SIGN_IDENTITY="${INSOMNIA_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/Developer ID Application:/ { print $2; exit }')}"
if [ -z "$SIGN_IDENTITY" ] || [ "$SIGN_IDENTITY" = "-" ]; then
  print -u2 "A Developer ID identity is required for the distribution DMG."
  exit 1
fi
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
print "Signed DMG ready for notarization: $DMG"
