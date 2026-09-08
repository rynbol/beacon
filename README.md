# Beacon for Mac

A native reminder workspace over Apple Reminders, redesigned September 2026.

Start with [the redesign and research notes](docs/REDESIGN.md). The earlier architecture proposal remains in [DESIGN.md](DESIGN.md) as historical context; its milestone table and reliability claims are not the current implementation contract.

## Build and open

Requires macOS 26 and Xcode 26. The packaging script uses Xcode to generate Siri/Shortcuts metadata.

```sh
swift test
./Scripts/build-mac-app.sh
open build/Beacon.app
```

For a design preview with sample reminders:

```sh
open -n build/Beacon.app --args --preview
```

The preview does not request Reminders access or save task changes. It displays a clear error if a write is attempted. Normal launch uses the existing `dev.dylan.beacon` identity and your existing preferences and sidecar.

## Using Beacon

- Capture a reminder in the field above the list. Include a phrase such as “tomorrow at 9am” and review the interpreted date before pressing Return.
- Cmd-N opens the full editor for notes, date presets, list selection, and repeat rules. New reminders and quick entry inherit the view: Today → now, Upcoming → tomorrow at 9 AM, Calendar → selected day, All/Someday/Completed → undated. An explicit date overrides the default.
- Cmd-F searches titles, notes, and list names in the current view.
- Use the circle to complete a task and the labeled Snooze menu to defer it.
- Navigate All reminders, Today, Upcoming, Someday, and recently Completed in the sidebar.
- Cmd-comma opens settings for accent, grouping, alert permissions, snooze intervals, and quiet hours.
- The footer shows Reminders connectivity and alert status. Its information button opens the scheduling plan.

Tasks remain in Apple Reminders. Beacon stores preferences, snooze deadlines, and mute state locally. Completing or editing a reminder changes the Apple Reminders item. New undated captures go into Someday and stay silent until dated. Existing distant Someday dates remain readable; new Someday reminders keep a nil due date.

## Verification and scope

The unit suite covers parsing, grouping, recurrence calculations, notification planning, quiet hours, spacing, and the new snooze/premature-alert regressions. This branch contains the Mac app. The separate minimal iPhone worktree is not included in this repository publication.

Normal launch requests Reminders and Notifications permissions if needed. The build script uses the existing Beacon Dev signing certificate when available. Live notification delivery, Focus, sleep/wake, and recurring writes require device validation. `Scripts/e2e.sh` is an optional integration harness that creates real scratch reminders; it is not part of the unit suite.

The app refreshes on activation, external Reminders changes, and once a minute while running. Future tasks enter the 36-hour one-shot planning horizon on refresh; daily task alerts are only installed once due. No claim is made that every reminder can notify indefinitely without running the app.

## Source

- `Sources/BeaconApp`: SwiftUI Mac interface, view model, notification responses.
- `Sources/BeaconKit`: scheduling, task models, EventKit writes, local sidecar.
- `Tests/BeaconKitTests`: automated tests.
- `docs/REDESIGN.md`: research, design decisions, behavior changes, and limits.

See [the security review](SECURITY.md) for the public source review, permissions, and limitations.

## Voice and iPhone

Dictate with **⌘⇧M**, also shown when hovering over the microphone. Enable macOS Dictation under System Settings → Keyboard. ⌘M keeps its standard Minimize behavior.

Siri can still use “Remind me to…” through Apple Reminders. Beacon treats undated items as Someday and keeps explicit dates. There is no attempt to override Apple's built-in command. App Shortcuts also expose “Add a reminder in Beacon” and “Show my reminders in Beacon.”

See [the full iPhone installation plan](docs/IPHONE-DEPLOYMENT.md). The iPhone implementation is maintained in a separate local worktree.

## Calendar on Mac

Open **Calendar** in the sidebar, then **Connect Calendar**. Work, Personal, and other calendars use their native colors; each calendar filter offers a Beacon-only color override. Add your Google account through Apple Calendar to see it here. Today includes an upcoming-events agenda.

Events are re-read when switching views/dates, toggling calendars, returning to Beacon, or pressing **⌘R**. Calendar database changes also refresh the list. The last-read time is shown; remote Google/iCloud updates still depend on macOS account sync. Event details can open meeting links or create a Someday follow-up reminder. See [Calendar behavior and validation](docs/CALENDAR.md).
