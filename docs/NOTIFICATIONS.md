# Notification style

Beacon keeps notifications task-first, with a short context line and restrained wording. macOS controls the banner layout, fonts, and colors; urgency is expressed in text rather than relying on colored emoji or pretending the app can theme Notification Center.

## References

- [Things: Setting a Reminder](https://culturedcode.com/things/support/articles/2803585/) describes reminders as gentle nudges and supports explicit snooze durations. Beacon keeps its existing persistent reminder behavior rather than adopting Things' single-alert behavior.
- [Todoist: Introduction to reminders](https://www.todoist.com/help/todoist/features/introduction-to-reminders-9PezfU) distinguishes scheduled, relative, and recurring reminders and explains snoozing. Beacon similarly keeps notification wording tied to the actual snooze interval.
- [Apple: Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications) recommends concise, informative content. [UNMutableNotificationContent](https://developer.apple.com/documentation/usernotifications/unmutablenotificationcontent) supplies title, subtitle, body, and action-category metadata.

These are product/documentation references, not a claim that the examples below copy another app's notification text.

## Treatment

- Title: the reminder's own title.
- Subtitle: `High urgency · Work`, `Medium urgency · Personal`, or `Low urgency · Work`. None is omitted; an empty list name adds no separator. Long list names are bounded, with whitespace collapsed.
- Initial body: `A little nudge. Snooze for 15 minutes.` Low uses `When you have a moment.` High uses `Give this one a moment.`
- Follow-up: `Still on your list. Snooze for 15 minutes.` The interval always comes from the current snooze rung, including for named daily reminders.
- Daily overview: `A moment for your day` / `See what needs your attention in Beacon.` No counts or relative dates that become false while the app is closed.
- Actions: Snooze, Snooze longer, Done. Existing identifiers and task routing remain intact.
- Icon: the existing lighthouse mark in cream on Beacon teal. The bundled `.icns` is rendered at all Mac sizes by `Scripts/generate-app-icon.swift`, then assembled with `iconutil -c icns build/Beacon.iconset -o Resources/Beacon.icns`.

Urgency changes context and tone only. It does not change firing times, sound, Focus behavior, or notification permissions. Private notes are not added to notification previews. Existing delivered notifications keep their old content; new pending requests receive the new copy when the updated app rebuilds the plan.

## Verification

Unit coverage includes all urgency levels, empty/long list names, whitespace and Unicode handling, exact snooze intervals, unchanged firing times across urgency levels, and native request subtitle/body/action routing. The icon was rendered and visually inspected. Live banner rendering, icon-cache refresh, sound, and action-button clicks are separate device checks; a request-construction test is not proof of delivery.

Validation: 133 unit tests and 27 app integration checks passed. The normal Mac build passed, including signature verification, and the packaged bundle contains the icon referenced by its Info.plist. Integration test reminders were removed successfully.
