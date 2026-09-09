# Beacon Mac UI and integration audit — 2026-09-08

## Changes

Settings now uses a wider panel with persistent section navigation: Appearance, Calendars, Notifications, Snooze, and Help. Theme presets and existing color preferences remain intact. Snooze intervals have their own section, account instructions are expandable, and native controls have explicit accessibility labels. The footer's Alerts button opens Notifications directly. X, Escape, and outside-click dismissal are retained.

The reminder editor is shorter, with the common date choices visible and relative-time choices in a native Later menu. Urgency and list values align on the right. Repeat removal was previously invisible; it now clears the editor's repeat rule. Choosing an end date now exposes a date control. Cmd-N is disabled during dialogs, and the native New Window command no longer takes over when capture is unavailable. This protects the current draft.

Calendar selections use the chosen highlight rather than hardcoded Ocean. Source rows use quiet separators, event details use the app's sans-serif typography, and overnight details avoid repeating the start date. Empty reminder states use the same typography. The diagnostic schedule labels future entries “Scheduled times” and wraps its permission explanation.

No additional kit was installed. Existing copy-in components remain where useful; new Settings navigation and form behavior use SwiftUI controls. The app sidebar and current destination structure remain unchanged.

## Automated verification

- 128 unit tests passed, including theme contrast, parsing, urgency, completed-day boundaries, recurrence, scheduling, Calendar refresh, and keyword/range filtering.
- Updated integration harness: 27 checks passed through Beacon.app with its real EventKit access. Checked create/update, notes, dates, urgency preservation/change, undated Someday, repeat add/remove, snooze date changes, completion and undo, clearing dates, grouping, notification request construction, Calendar source consistency and filtering.
- All three temporary test reminders were deleted and the active store was checked for leftovers. The harness no longer sweeps earlier test runs or applies a replacement notification plan during an ordinary run. Explicit legacy `--cleanup` mode remains separate.
- `Scripts/e2e.sh` launches a separate instance and exits unsuccessfully for a missing or failing report.
- Normal and sample-data preview builds passed.

## UI walkthrough

Performed in the isolated sample-data preview; actual reminder writes are blocked in that mode.

| Flow | Result |
| --- | --- |
| All reminders, Today, Upcoming, Someday, Completed, Calendar | Navigation and displayed data checked |
| Settings Appearance, Calendars, Notifications, Snooze, Help | Layout and controls inspected; sections remain reachable |
| Settings X, Escape, outside click | Dismiss correctly |
| Themes | Paper and Dark checked in the new layout; previous theme audit also verified Beige/Mist and persistence |
| New reminder / Cmd-N | All defaults to Someday, Today to now, Upcoming to tomorrow at 9 AM |
| Cmd-N during draft | Draft text remains; no extra window after fix |
| Search / Cmd-F | No-match state appears; clear restores list |
| Relative dates | Later menu exposes 15 minutes, 1/2/4 hours and 7 days; native menu automation could not reliably select an item |
| Repeat | End-date picker appears; Remove repeat returns to non-repeating controls |
| Calendar details → follow-up | Title, date context and meeting URL prefill a draft |
| Preview Save | Explicit write-protection error; no live reminder created |
| Calendar hide/show | Seven sample events reduce to three when Work is hidden |
| Include/exclude | `dEsIgN` leaves one event; excluding `REVIEW` then leaves zero; test filters removed afterward |
| Alerts footer | Opens Notifications directly |
| Schedule | Read-only sheet opens with sample plan; Escape dismisses |

Preview preferences used for testing were restored and the preview closed. New UI testing findings were fixed before the final builds.

## Limits

This is an integration run plus a manual UI walkthrough, not a claim that every system path has been tested. Audible notification delivery, Siri speech recognition, Dictation audio, Focus/sleep/wake, remote Google/iCloud propagation, and iPhone behavior were not exercised in this audit. No notification permission was changed. Unit tests and request construction cannot establish delivery. Native menu automation was unreliable for selecting the new Later items; their available options and the shared date calculations were inspected.
