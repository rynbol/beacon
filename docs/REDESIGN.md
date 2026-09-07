# Beacon for Mac — redesign, September 2026

The brief: primarily redesign the existing Mac app; retain Apple Reminders as the source of truth. The prior project is preserved in `../beacon-backups/beacon-before-rebuild-20260906.tar.gz`.

## Research and decisions

- [Unforgetful](https://www.unforgetful.app/) centers Reminders interoperability, repeated reminders, and snooze history. Retain that useful core. Avoid a complicated task-management system.
- [Due's capture workflow](https://www.dueapp.com/support/osx/setting-a-reminder.html) emphasizes entering what and when together. Beacon now has inline capture with a date interpretation preview; it parses on submission, leaving the text intact while typing.
- [Due's auto-snooze controls](https://www.dueapp.com/support/osx/fine-tuning-reminders.html) make repeat notification timing configurable. Beacon keeps its existing editable ladder and exposes a labeled Snooze action on every active row.
- [Apple's notification guide](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SchedulingandHandlingLocalNotifications.html) distinguishes repeating triggers from one-shot triggers and requires explicit cancellation. A daily trigger cannot express a future start date. Beacon now only arms daily task alerts for tasks already due; future tasks use dated one-shot alerts within the planning horizon.
- [Apple's local notification documentation](https://developer.apple.com/documentation/UserNotifications/scheduling-a-notification-locally-from-your-app) describes system-scheduled delivery. Scheduling is not proof that a banner reached the user. The app must distinguish planned alerts, permissions, and the master switch.

## Design

A native, desktop-sized workspace with an ivory canvas, soft teal accent, quiet separators, serif page headings, and readable system type for actions. A compact sidebar provides All reminders, Today, Upcoming, Someday, and recently Completed. All reminders is the default; counts make the other views visible. These are local views, not new folders in Apple Reminders.

Quick capture stays above the list. Each reminder shows its source list, due text, completion control, recurrence/mute status, and a labeled snooze menu. Search matches titles, notes, and list names. Cmd-N opens the full editor, Cmd-F focuses search, Cmd-comma opens settings, and Return submits quick capture. The footer separates the Reminders connection from alert status.

The editor retains date presets and recurrence controls, with more space, descriptive fields, and visible save errors. Failed writes keep the draft open. New undated captures appear in Today instead of being silently assigned a date ten years in the future.

## Behavior fixes

- Persist the exact selected recurring snooze deadline, independent of the next ladder rung.
- Do not install daily task alerts ahead of a future due date or snooze deadline.
- Align notification snooze text with the interval the action actually uses.
- Deduplicate snooze choices at the end of the ladder.
- Serialize refreshes; refresh on foreground and every minute while running.
- Turning alerts off cancels pending requests even when fetching Reminders fails.
- Clear a prior scheduling error before a fresh attempt.
- Preserve failed capture/editor drafts.

## Limits

This rebuild targets macOS 26. It does not produce an iPhone app. Notification delivery, Focus behavior, sleep/wake, and recurring EventKit writes still need verification on the user's actual device. Far-future reminders depend on later app refreshes to enter the one-shot planning horizon. Daily digests and task beacons are retained from the previous engine, not a guarantee that every task alerts forever. Existing Someday dates remain compatible with the prior version's ten-year-date convention.

Use `--preview` for a sample-data design review without reading or writing Reminders.
