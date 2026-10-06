# Insomnia

- Native macOS 14+ menu-bar app. Swift Package, no third-party runtime dependencies.
- `Sources/Insomnia` owns AppKit/SwiftUI, hardware access and integrations. `Sources/InsomniaCore` owns pure policy and hook merging.
- Verify changes with `swift test` and `./scripts/build.sh`. Format with `xcrun swift-format format -i -r Sources Tests Package.swift`.
- Hardware cleanup checks: `./scripts/verify-runtime.py`, only while the app is stopped. Do not equate these checks with physically verified closed-lid behavior.
- Preserve the legacy bundle identifier, support folder and `--stillon-hook` token: existing permissions, preferences and installed hooks depend on them.
- Do not commit build output, local events, agent configuration, signing credentials or private diagnostics. Source icon and packaged ICNS are intentional assets.
- Releases must describe notarization and hardware verification honestly. Never remove quarantine or disable Gatekeeper in installers.
- UI labels stay concise; no default explanatory subtitles. Keep wake/sleep wording consistent.
