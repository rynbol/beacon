# Calendar in Beacon for Mac

Calendar is a viewing companion to reminders. The sidebar has a Calendar agenda with a week strip and date picker. Today shows the next events alongside reminders (or a compact agenda above them in a narrow window). Dates use a readable month-name button with a calendar picker. Event details expand inline and expose location, notes, supported meeting links, and a follow-up reminder draft. Follow-ups start in Someday and do not change the event.

## Accounts and colors

Choose Calendar → Connect Calendar in Beacon and grant macOS Calendar access. Apple requires full Calendar permission to read events through EventKit; Beacon's CalendarStore contains no event-writing calls.

Add Google through Apple Calendar → Add Account → Google, with Calendar sync enabled. Beacon reads the iCloud, Google, and other event calendars made available through EventKit on this Mac. Some shared Google calendars may need to be enabled in Google's sync settings. There is no separate Google OAuth client or server in Beacon.

Calendar colors come from Apple Calendar and appear consistently on the calendar filters, sidebar legend, event stripes, event source labels, and event details. Calendar visibility and color controls live in Settings, with no account-chip strip on the main Calendar page. The arrow beside each calendar filter offers Beacon-only color overrides. The sidebar only offers calendars with events on the selected date (today in the Today view), including hidden calendars so they can be re-enabled. The list scrolls when more than four calendars match. Hiding calendars and changing colors persist across launches; they do not change Apple Calendar or Google.

## Refresh contract

Beacon re-reads events on:

- Initial window appearance and returning the app to the foreground.
- Switching sidebar views, including clicking the already-selected view.
- Selecting a day, moving between weeks, changing the date picker, or toggling a calendar's visibility.
- The Refresh button or Command-R.
- Calendar database change notifications, debounced by 350 ms.
- The foreground minute refresh.

Navigation is debounced by 120 ms and reads Calendar independently of reminder notification scheduling. User-driven refreshes ask EventKit to refresh its sources at most once per five seconds, then fetch fresh values from the local Calendar database. Local reads still run for each settled navigation. Database-change and minute refreshes read without starting another source refresh, avoiding a feedback loop. The view displays when Calendar was last read; it does not claim this is the time Google finished syncing. Google/iCloud propagation, network availability, and macOS account sync can delay remote changes. Arriving database changes trigger a new read.

Refreshes are serialized and coalesced. Results from a date range the user has already left are discarded. A read failure retains the last successful values with an error; denied access clears private event data from the feed. Today is fetched alongside the selected week when browsing another week. Event occurrences are identified by calendar, event ID, and occurrence start; overlapping query windows are deduplicated.

All-day and multi-day events respect exclusive end dates. Canceled events are excluded. Event notifications remain the calendar app's responsibility, preventing Beacon from adding a second notification schedule for meetings.

## Verification

Automated coverage checks repeated reads, concurrent navigation, stale-result rejection, visibility filtering, read failure vs denied access, all-day boundaries, occurrence identity, and safe meeting-link recognition. All 104 shared tests pass, including localized time ranges, overnight dates, and exclusive all-day end dates. The packaged Mac preview was checked for Calendar and Today layouts, Work color changes across views, hide/show toggles, event details, and a follow-up draft with nil due date. The updated preview also verified first-click date navigation with event details open, the readable date selector, the removed chip strip, and Settings X dismissal. UI checks used sample calendars and the preview was closed afterward. Live Google/iCloud sync and permission state still require the connected account.

Sources: [EventKit](https://developer.apple.com/documentation/eventkit/ekeventstore), [database changes](https://developer.apple.com/documentation/eventkit/updating-with-notifications), [Google calendars in Apple Calendar](https://support.google.com/calendar/answer/99358).
