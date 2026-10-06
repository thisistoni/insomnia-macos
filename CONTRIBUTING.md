# Contributing

Open an issue for bugs or focused feature proposals. For a UI issue, include the macOS version, a screenshot of Insomnia only, and steps to reproduce. Do not post agent transcripts or private diagnostics.

Build with `./scripts/build.sh`, run `swift test`, and format Swift using `xcrun swift-format format -i -r Sources Tests Package.swift`. Keep pull requests focused. Changes to power ownership must exercise the actual helper cleanup checks with the main app stopped.

Hardware testing is valuable: report Mac model, macOS version, battery/AC, external-display status, and whether a timestamp-writing job continued during a 60-second closed-lid test on a ventilated surface. An API returning success alone is not evidence of that behavior.
