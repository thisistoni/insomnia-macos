<p align="center">
  <img src="Resources/Insomnia-Icon.png" width="128" alt="Insomnia icon">
</p>
<h1 align="center">Insomnia</h1>
<p align="center">Let your Mac work. Let yourself rest.</p>
<p align="center">Native macOS · No account · No telemetry · Free and open source</p>
<p align="center">
  <a href="https://github.com/thisistoni/insomnia-macos/releases/latest"><img src="https://img.shields.io/github/v/release/thisistoni/insomnia-macos?style=flat-square&color=66bfff" alt="Latest release"></a>
  <a href="https://github.com/thisistoni/insomnia-macos/actions/workflows/ci.yml"><img src="https://github.com/thisistoni/insomnia-macos/actions/workflows/ci.yml/badge.svg" alt="Build and test"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-66bfff?style=flat-square" alt="macOS 14 or later">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-66bfff?style=flat-square" alt="MIT license"></a>
</p>
<p align="center"><a href="https://github.com/thisistoni/insomnia-macos/releases/latest/download/Insomnia-macOS-arm64.dmg"><strong>Download for Apple silicon</strong></a> · <a href="docs/install-with-agent.md">Install with your agent</a></p>

Insomnia lives in your menu bar and keeps your Mac awake for long-running jobs, downloads and coding agents. Start a timed session, hold Fn, or let connected agents manage their own sessions.

Requires **macOS 14+ and Apple silicon** for the published download. Closed-lid job continuity was checked on AC and battery on an Apple-silicon Mac running macOS 26. Intel hardware is unvalidated. Closed-lid control uses a private macOS interface, so verify it on your Mac and after macOS updates.

<p align="center"><img src="docs/screenshots/panel.png" width="326" alt="Insomnia menu-bar session panel"></p>

## A little eye on your work

- **Filled eye:** keeping your Mac awake. **Crossed-out eye:** sleep allowed.
- Click the eye for the session panel. Right-click for quick actions.
- **Keep Mac awake** starts a session; **Allow sleep** restores normal sleep.
- Choose 15 minutes, 30 minutes, 1, 2 or 4 hours, or use the maximum-session limit.
- Battery, battery-temperature and thermal-pressure guards stop a session when needed.
- Optional Fn activation, screen locking on lid close, custom chime and launch at login.
- Optional Claude Code, Codex, Cursor and OpenCode lifecycle bridges support concurrent agent sessions. Bridges are experimental and vendor-version dependent. Agent completion only ends sessions started by automation.
- A separate watchdog restores power behavior if the app stops, hangs or loses its helper.

<p align="center"><img src="docs/screenshots/settings.png" width="510" alt="Insomnia Wake settings"></p>

## Install

1. [Download the signed and Apple-notarized DMG](https://github.com/thisistoni/insomnia-macos/releases/latest/download/Insomnia-macOS-arm64.dmg).
2. Open it and drag **Insomnia** into **Applications**.
3. Open Insomnia from Applications. Click the eye in your menu bar.

The app has no terminal requirement. A [ZIP and checksums](https://github.com/thisistoni/insomnia-macos/releases/latest) are also available. Insomnia is unrelated to the API client with the same name; check before replacing an existing app.

Want your agent to handle installation? Copy the [installation prompt](docs/install-with-agent.md).

### Build from source

Install Xcode Command Line Tools (`xcode-select --install`), then:

```sh
git clone https://github.com/thisistoni/insomnia-macos.git
cd insomnia-macos
./scripts/build.sh
```

Move `build/Insomnia.app` into Applications using Finder and open it. Local builds use an available Developer ID signature or an ad-hoc signature; they are not automatically notarized. Review any macOS Privacy & Security prompt without disabling Gatekeeper or removing quarantine.

## Permissions

Manual sessions work without extra permissions. Enable these only if you want their features:

| Permission | Feature | Where |
| --- | --- | --- |
| Input Monitoring | Hold Fn to keep awake | Settings → Wake → Keyboard access |

The buttons open the relevant System Settings page. macOS owns the approval; the app cannot enable these permissions for you. “Lock screen when lid closes” is off by default for computer use. Enable it in Wake → Session to lock on an awake lid-close transition; Accessibility is required. Insomnia does not force display sleep. macOS automatic-lock policies still apply.

## Connect coding agents

In **Settings → Automation**, choose Connect beside an agent and restart it. Codex additionally requires reviewing and trusting the definitions through `/hooks`. Insomnia never approves an agent's permission requests. Allow sleep pauses automatic reactivation until current agent sessions are inactive.

Existing hook configurations are backed up and merged; Disconnect removes Insomnia's handlers. Keep the app in Applications so the executable path stays stable. Connections must be refreshed if you move it. Only agent name, session ID, state and timestamp are retained—never prompts, source code, tool arguments or transcripts. Events older than one minute are ignored.

The bridges follow [Claude Code hooks](https://code.claude.com/docs/en/hooks), [Codex hooks](https://developers.openai.com/codex/hooks), [Cursor hooks](https://cursor.com/docs/hooks), and [OpenCode plugins](https://opencode.ai/docs/plugins/). These bridges are experimental: Codex lifecycle events have been observed locally, while live Claude Code, Cursor and OpenCode compatibility remains unverified. Cursor approval-wait detection is not implemented. Manual sessions cover tools without a suitable lifecycle bridge.

## Check closed-lid behavior

Use a hard, ventilated surface; never keep an awake Mac in a bag. Disconnect external displays. Start a job that writes timestamps, choose Keep Mac awake, close the lid for 60 seconds, then reopen it and confirm the log has no interruption. Repeat on AC and battery. A locked screen or successful API call does not prove the Mac stayed awake. No temperature limit guarantees physical safety.

## Development

```sh
swift test
./scripts/build.sh
# Quit Insomnia before this hardware cleanup check:
./scripts/verify-runtime.py
```

No third-party runtime dependencies. Open `Package.swift` in Xcode. [Architecture and limits](docs/architecture.md), [verification](VERIFICATION.md), [release workflow](docs/releasing.md), and [contributing](CONTRIBUTING.md) explain the implementation and checks.

## Troubleshooting

- **Can't start a session:** read the panel message. Required missing sensors prevent waking; check General → Safety. Desktop Macs may not expose battery sensors.
- **Agent doesn't activate it:** restart the agent, verify its hooks are loaded/trusted, and confirm Insomnia is running. A connection button only confirms configuration is installed.
- **Fn doesn't respond:** grant Input Monitoring and follow any macOS restart prompt.
- **Unexpected sleep:** check timers, safety limits, the stay-awake-after-opening setting and recent Activity. Avoid running another lid-control app alongside Insomnia.

## License

[MIT](LICENSE). An independent implementation inspired by StillOn; no original binary or commercial licensing code is distributed. Icon created with AI; chime generated for this project.
