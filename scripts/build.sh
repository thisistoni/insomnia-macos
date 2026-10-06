#!/bin/zsh
set -eu
cd "${0:A:h}/.."
swift build -c release
APP="$PWD/build/Insomnia.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Insomnia "$APP/Contents/MacOS/Insomnia"
cp Resources/Insomnia-Chime.wav "$APP/Contents/Resources/"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi
SIGN_IDENTITY="${INSOMNIA_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/Developer ID Application:/ { print $2; exit }')}"
if [ -z "$SIGN_IDENTITY" ]; then SIGN_IDENTITY="-"; fi
if [ "$SIGN_IDENTITY" = "-" ]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi
print "Built $APP"
