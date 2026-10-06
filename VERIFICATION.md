# Verification

Local review on 6 October 2026: Apple-silicon Mac, macOS 26, Swift 6.3.2.

## Confirmed

- Eight unit tests pass, including the regression that agent completion cannot end a manual session, charging-aware battery limits, unavailable sensors, thermal pressure, concurrent agents, waiting policy, expiration, stale/out-of-order events and preserving/idempotent hook updates.
- Release bundle builds and Developer ID signature verification pass. Apple notarization Accepted; ticket stapling/validation and Gatekeeper assessment pass for the local release package.
- Actual helper STOP, EOF, heartbeat timeout SIGTERM and sustained-heartbeat checks acquire/release real public sleep assertions and remove the ownership receipt.
- Synthetic lifecycle events were tested against the installed hook entrypoint; multiple sessions aggregated correctly. These are not evidence of live vendor-agent compatibility.
- Native UI inspected for the session panel, settings pages, quick menu, tab switching and permission state. Manual wake/sleep, chime preview and Accessibility recognition were exercised locally.
- Physical AC check: user completed the requested no-external-display procedure. A separate timestamp job recorded 77 samples across 81.1 seconds with the lid closed. Maximum observed interval across the run was 2.512 seconds, with no closed-lid-length pause. The screen locked while the job continued. The first battery check then exposed a 90-second clamshell-sleep gap. Sleep-notification handling and heartbeat refresh were corrected; physical battery retest is pending.

## Release gates still open

- Physical closed-lid job continuity on battery without external displays.
- Live Claude Code, Codex, Cursor and OpenCode jobs and approval flows on declared supported versions.

Intel hardware and power efficiency relative to other apps are not validated. The release remains local until the required checks are completed; no production-readiness claim is made.
