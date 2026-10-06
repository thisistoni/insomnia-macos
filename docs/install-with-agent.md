# Install with your coding agent

Copy this prompt into an agent that can operate your Mac:

```text
Install Insomnia, the macOS menu-bar keep-awake app from
https://github.com/thisistoni/insomnia-macos .

First read the repository README and latest release notes. Confirm this is
Insomnia for macOS, not the unrelated API client with the same name. Check
that this Mac runs macOS 14 or later. Prefer the published Apple-silicon ZIP
when compatible. Download it and SHA256SUMS from the same tagged release;
verify the checksum and codesign signature before installation. Explain if
the release is a preview or is not notarized. Never strip quarantine,
disable Gatekeeper, or grant security permissions automatically.

Check whether /Applications/Insomnia.app already exists. Do not overwrite
an unrelated app: inspect its bundle identifier first. This app uses
 dev.local.stillonclone. For a same-app update, quit it gracefully, preserve
a recoverable backup, then install the bundle in /Applications and open it.
If there is no compatible binary, build from the tagged source using the
README instructions; ask me to install Xcode Command Line Tools if missing.

Verify the menu-bar icon and settings appear. Explain Keep Mac awake and
Allow sleep. Only connect agents I explicitly choose, preserve their
existing hooks, and let me review any hook-trust prompt. Let me approve
Accessibility/Input Monitoring myself when needed. Do not claim closed-lid
behavior is verified until I perform the physical test in the README.
Report the installed version, source release URL and any remaining steps.
```
