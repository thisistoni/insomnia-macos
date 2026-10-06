# Architecture

`InsomniaCore` contains battery and thermal policy, timestamped agent-session aggregation, automation ownership and preserving hook configuration updates. Unit tests run without changing power settings.

`Insomnia` contains the menu-bar delegate, SwiftUI views, app model, IOKit sensor/power access and agent bridges. The GUI owns the helper via a pipe. The helper owns lid control and an optional public idle-sleep assertion. A heartbeat watchdog, EOF and signal handlers release those resources. A lock serializes competing cleanup paths. Heartbeats refresh the shared clamshell override after powerd reevaluates power/display state. A closed-lid pending-sleep notification does not prematurely release the session. An activity token prevents App Nap from throttling the GUI watchdog while armed; it does not prevent display sleep. The app checks for an unexpected helper exit and recovers its ownership receipt.

Manual and automatic sessions have distinct ownership: agent completion ends automatic sessions only. Allow sleep pauses reactivation until all agent sessions are inactive. Timers, maximum duration and safety cutoffs apply to either owner.

The bundle ID `dev.local.stillonclone`, support directory `~/Library/Application Support/StillOnClone`, OpenCode bridge filename and `--stillon-hook` argument remain compatibility identifiers from the first local version. Public module names and UI use Insomnia. Changing those identifiers would require a migration and renewed OS permissions.

Agent bridges match the vendor documentation linked in the README. Configured does not mean loaded: restart the agent, and review Codex hooks through `/hooks`. All bridges need live validation for the installed agent version. Events older than a minute are ignored; abandoned sessions expire at the configured maximum duration.

## Known limits

- Private lid control can change between macOS releases.
- Required unavailable battery/temperature readings prevent waking; desktop Macs without those sensors may need the corresponding guards disabled deliberately.
- Power settings can conflict with another keep-awake app; use one at a time.
- Settings and activity are local. History is limited to 100 entries and cleared when the app exits.
- There is no background updater, cloud account or persistent agent transcript.

## Possible follow-ups

A notarized automatic-update mechanism and Homebrew cask would make updates easier after the first public release. A graphical continuity check would also make hardware validation more accessible. These are follow-ups; neither is present in the current app.
