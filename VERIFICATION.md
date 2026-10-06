# Verification

Local review on 6 October 2026: Apple-silicon Mac, macOS 26, Swift 6.3.2.

## Confirmed

- Nine unit tests pass, including the regression that agent completion cannot end a manual session, charging-aware battery limits, unavailable sensors, thermal pressure, concurrent agents, waiting policy, expiration, stale/out-of-order events and preserving/idempotent hook updates.
- Release bundle builds and Developer ID signature verification pass. Apple notarization Accepted; ticket stapling/validation and Gatekeeper assessment pass for the local release package.
- Actual helper STOP, EOF, heartbeat timeout SIGTERM and sustained-heartbeat checks acquire/release real public sleep assertions and remove the ownership receipt.
- Synthetic lifecycle events were tested against the installed hook entrypoint; multiple sessions aggregated correctly. These are not evidence of live vendor-agent compatibility.
- Native UI inspected for the session panel, settings pages, quick menu, tab switching and permission state. Manual wake/sleep, chime preview and Accessibility recognition were exercised locally.
- Physical AC check: user completed the requested no-external-display procedure. A separate timestamp job recorded 77 samples across 81.1 seconds with the lid closed. Maximum observed interval across the run was 2.512 seconds, with no closed-lid-length pause. The screen locked while the job continued. The first battery check then exposed a 90-second clamshell-sleep gap. Sleep-notification handling and heartbeat refresh were corrected; Battery retest passed: 138 samples across 147 seconds with the lid closed, unplugged; maximum observed interval was 1.503 seconds.

## Scope and limitations

- Screen locking is now opt-in and defaults off. The UI toggle and permission state were checked; existing preferences migrate without resetting. Computer-use continuity with the lid closed has not been separately exercised.
- Codex lifecycle events and agent attribution were observed locally. Claude Code, Cursor and OpenCode live jobs/approval flows remain unverified; agent bridges are explicitly experimental.

Intel hardware and power efficiency relative to other apps are not validated. The physical checks apply to this Mac and tested power conditions; they are not a guarantee for every Mac or macOS version.
