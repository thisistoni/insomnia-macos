# Releases

1. Run `swift test` and `./scripts/build.sh` on Apple silicon. Stop the GUI and run `./scripts/verify-runtime.py`. Exercise the native UI and physical displayless AC/battery checks in the README.
2. Set the marketing/build versions in `Resources/Info.plist`. Build with `INSOMNIA_SIGN_IDENTITY` set to the release Developer ID identity (otherwise the build script uses an available Developer ID or ad-hoc signature).
3. Run `./scripts/package-release.sh`. It creates an Apple-silicon ZIP and SHA256SUMS in `build/release`.
4. For a notarized release, configure a local notarytool keychain profile. Submit the ZIP with `xcrun notarytool submit ... --keychain-profile PROFILE --wait`, verify Accepted, staple the app using `xcrun stapler staple build/Insomnia.app`, then repackage. Verify `spctl --assess --type execute -v build/Insomnia.app` and `xcrun stapler validate build/Insomnia.app`.
5. Create the Finder installer with `./scripts/package-dmg.sh` after stapling the app. Submit the DMG to notarytool, verify Accepted, then staple and validate the DMG. Regenerate SHA256SUMS for both ZIP and DMG. Publish a tagged GitHub release with the DMG, ZIP and checksums. Label unnotarized or hardware-unverified releases as previews and document both limits in the notes. Never embed signing credentials in the repository or scripts.

CI builds and tests pull requests. Its ad-hoc build artifact is not a notarized public distribution. Intel builds are possible from source but remain unvalidated; do not label the Apple-silicon ZIP universal.

## Screenshots

Capture settings with the native app UI. To export the exact session-panel view, quit all Insomnia instances, then run:

```sh
build/Insomnia.app/Contents/MacOS/Insomnia --export-panel "$PWD/docs/screenshots/panel.png"
```

This renders current local state and exits. Inspect images for private information before committing. Screenshots in this repository show actual views, not mockups.

## Signing certificate renewal

The locally verified 1.0 bundle uses a secure timestamp and a certificate from the previous Developer ID authority, expiring 1 February 2027. Apple states that already signed/notarized Mac apps with secure timestamps keep working. Future releases must move to a G2-issued Developer ID Application certificate. See [Apple's replacement guide](https://developer.apple.com/help/account/certificates/replace-developer-id-certificates). Explicitly set `INSOMNIA_SIGN_IDENTITY` after installing the replacement so the build cannot select the older identity.
