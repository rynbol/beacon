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

## Alignment follow-up

The follow-up on macOS 26.5.1 reproduced a roughly 17-point right-edge shift when a compact reminder list began to overflow. AppKit's overlay scroller setting alone did not prevent SwiftUI from reserving a gutter. The shared scroll wrapper now hides SwiftUI indicators and fills the available content width; native scrolling remains intact. The header, capture field, group rules, and reminder list retain a common right edge at the top and bottom of the list.

Other fixes give shared cards consistent full width, align the Settings and section headings, distribute the four theme tiles evenly with backgrounds filling their height, center the editor title independently of the unequal Close/Save controls, and use a common icon column and text inset for Repeat, Urgency, List, and their separators. The Later menu is vertically centered with the date buttons.

Rechecked in the isolated preview at a compact native quarter-tile window (approximately 900 × 614) and a wide native Fill window:

- Reminder list scrolling and Today layout; stable content edges with and without overflow.
- All five Settings sections; full-width Help cards and aligned notification/snooze controls.
- A long Calendar include label wrapping across two lines, with Accounts & sync expanded; the temporary filter was removed afterward.
- New reminder with a multiline title and expanded weekly repeat controls; scrolled through the bottom of the form with the header remaining centered and visible. Draft dismissed without saving.
- Calendar Day, expanded event details, scrolling to the follow-up action, and Next 7 days; content stays aligned as details introduce overflow.
- Appearance panel centered in the wide window, with even theme tiles. Preview closed after inspection.

After these fixes, all 128 unit tests and all 27 app integration checks passed again. The normal app and sample preview built successfully, and the integration harness confirmed its temporary reminders were removed.

These checks cover the reproduced alignment issues, not every window size or system display configuration. The layout changes do not alter reminder or Calendar data rules.

## Selection-control follow-up

Replaced the editor/Settings menu pickers with a shared themed choice popover and replaced snooze/repeat spinners with consistent minus/plus controls. Purposeful checks ran in the isolated sample preview:

- Urgency: click selection, arrow/Return selection, current checkmark, Escape cancellation, and Return with a filled draft (no Save attempt).
- List: Personal to Work updates the draft. Later: choosing 1 hour updates the displayed due time.
- Repeat: Weekly to Monthly, interval 1 to 2, ending after a count, count 10 to 9; the rule and upcoming dates update together.
- Grouping: By time to By list and back. Quiet hours: selected hour scrolls into view; keyboard selection at the last hour stays in bounds; restored 22:00–08:00 afterward.
- Snooze: first interval changes from 15 to 30 minutes and back.
- Popovers: light and Dark surfaces inspected; the hour list uses the shared thin overlay scroller. Clicking Notes dismisses a picker without discarding the draft.
- A fast Up → Escape sequence initially dismissed Settings too. Guarding parent shortcuts through the native closing transition fixed that reproduced sequence; Settings remained open and its value unchanged. Parent shortcuts become available again after the picker closes.

All test drafts were discarded, preview preferences restored, and the preview closed. The 128-unit-test suite passed; preview and normal app builds passed. This follow-up verified editor bindings and UI interactions, not live EventKit writes or notification delivery; the earlier integration results are recorded separately above.

## Section motion

Main destinations, Settings sections, and Calendar Day / Next 7 days now share a 16-point slide with a 240 ms ease-out and fade. The sidebar and footer remain stationary. The modifier observes only the selected section and preserves view identity, so data refreshes do not replay the entrance and quick-entry text is retained. Reduce Motion suppresses both displacement and fading through SwiftUI's accessibility environment.

Preview navigation checked all six destinations, all five Settings sections, both Calendar tabs, retained quick-entry text, settled alignment, and dismissal. Preview closed without saving its draft. Normal and preview builds passed. The OS Reduce Motion preference was not changed during the walkthrough; its branch was verified in source. Implementation uses SwiftUI's [triggered phase animator](https://developer.apple.com/documentation/swiftui/view/phaseanimator(_:trigger:content:animation:)), with no new dependency.

### Click-away keyboard focus

Added a window-scoped mouse observer that releases editable-text focus when clicking a non-editable area, without consuming the click. Text fields, multiline editors, and their scrollbars retain native interaction; other windows are unaffected. Observer cleanup occurs when the host detaches. Main and preview builds passed. Sample UI confirmed a physical blank-area click removes Search focus, and Search can subsequently be focused and typed into again. Additional coordinate navigation checks were limited by intermittent computer-use `noWindowsAvailable` errors.
