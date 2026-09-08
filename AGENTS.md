# Beacon project direction

- The user's goal is a personal recreation of Unforgetful, the subscription reminder app named in DESIGN.md. Prioritize its documented behavior and the user's preferred interface over inventing a different productivity product.
- Mac first. The user said design was the primary problem with the old implementation.
- Do not continuously inspect, capture, activate, or watch the user's app. Use UI access only for a specific edit or purposeful test, and stop as soon as that check is complete. Prefer source inspection and automated checks for routine work.
- Keep Apple Reminders as the source of truth and preserve existing reminders. Use isolated sample data for UI write tests.
- Separate documented reference features, implemented behavior, and device-verified behavior. Passing planner tests is not proof of end-to-end notification delivery.

- Platform direction chosen by the user: preserve the sidebar/workspace design for macOS; use the minimal single-list design for the future iPhone app. The minimal Mac preview is a design reference, not an installable iOS app.

- Capture rule: Mac manual capture inherits its view: Today uses now, Upcoming uses tomorrow at 9am, Calendar uses the selected day at 9am (now if today), and All/Someday/Completed default to nil. Typed or explicitly chosen dates override this default. Siri-created Apple Reminders and capture without view context still use Someday when no date is supplied. Preserve nil due dates; do not manufacture distant dates. Explicit today/tomorrow/time remains scheduled. Someday-only tasks should not generate alerts or a digest.

- Mac Calendar: show account calendars with consistent colors; refresh on view/date/filter navigation, foreground, explicit refresh, and EventKit changes. Keep event reads separate from reminder scheduling. The last-read timestamp is not proof of completed Google/iCloud sync.
