# Notification style

Beacon task alerts show only the reminder title, followed by an urgency flag: none has no suffix, low uses ⚐, medium uses ⚑, and high uses 🚩. Subtitle and body are empty. List names, notes, and snooze instructions are omitted.

macOS controls notification layout and supports plain text titles, so these symbols have fixed system appearances rather than the app’s configurable urgency colors. Urgency does not change timing, sound, Focus behavior, or permissions.

## Actions

Task notifications offer **Snooze…** and **Done**. Snooze opens a compact chooser in Beacon using the configured positive snooze intervals, sorted and deduplicated. Defaults are 15 minutes, 30 minutes, 1 hour, 2 hours, 4 hours, 8 hours, and 1 day. Cancel, Escape, and clicking outside do not change the reminder. Saving rechecks the reminder and uses the existing recurring/one-off snooze behavior. Errors remain visible in the chooser. The row’s More times… action opens the same interface.

The foreground action is necessary because native notification actions do not provide a custom nested time menu. Legacy Snooze and Snooze longer identifiers remain supported for older delivered notifications.

The daily overview remains “A moment for your day” / “See what needs your attention in Beacon.” Existing delivered notifications retain their previous text; new requests use the current format.

## Icon

The existing cream lighthouse on teal is compiled from Resources/Assets.xcassets/AppIcon.appiconset. Xcode generates Assets.car, AppIcon.icns, CFBundleIconName and CFBundleIconFile; both Debug and Release select AppIcon. The build script checks that these outputs exist. Regenerate the PNGs with Scripts/generate-app-icon.swift Resources/Assets.xcassets/AppIcon.appiconset. The build script registers the packaged app with LaunchServices after signing. On the development machine, older duplicate Beacon registrations were removed and the obsolete running copy was closed. No reminders or notification database were deleted.

## Verification

133 unit tests and 27 app integration checks passed. Coverage includes every urgency suffix, Unicode titles, empty task subtitle/body, unchanged scheduling across urgency levels, native category identifiers and foreground options, and persisted snooze dates. Integration test reminders were cleaned up. The normal signed Mac build passed.

The chooser was visually checked with sample data, including keyboard blocking, failed-save feedback, and Escape dismissal. A disposable native notification was confirmed delivered and removed using its unique identifier. This does not verify a live notification action click. The compiled catalog was inspected with assetutil and contains the AppIcon renditions. A fresh delivery succeeded after the catalog migration, but the final Notification Center icon appearance could not be verified through UI automation.

For a delivery-only preview, launch the built app with `--notification-preview --report <path>`. This requires existing notification permission, skips normal reminder access/scheduling, and removes only its own temporary notification. It has no real task action target.

## Platform references

- [Apple notification guidance](https://developer.apple.com/design/human-interface-guidelines/notifications)
- [Notification title](https://developer.apple.com/documentation/usernotifications/unmutablenotificationcontent/title)
- [Foreground actions](https://developer.apple.com/documentation/usernotifications/unnotificationactionoptions/foreground)
- [Handling notification actions](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions)
