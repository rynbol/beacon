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

## Upcoming calendar events

Calendar offers Day and Next 7 days tabs in a compact toolbar. Upcoming reads a rolling interval from now to the same local time seven calendar days later, including events already in progress and excluding events at or after the end boundary. Results are sorted by start time and grouped by start date. The fetched ranges always include this interval, even when browsing another week.

Settings → Calendars → Upcoming calendar events stores multiple Include and Exclude keyword labels locally. Keywords match substrings of event titles, ignoring case and diacritics. Any Include match is sufficient; an empty Include list accepts every title. Any Exclude match vetoes an event. Blank labels are ignored and labels are deduplicated without case sensitivity. Add commits a label; click its X to remove it. These filters apply only to the Calendar Upcoming agenda, not reminder Upcoming or the Day view. Hidden calendars are respected; matching hidden calendars keep their sidebar toggle so they can be re-enabled.

Verification: 120 automated tests pass, with 16 focused on Upcoming. Coverage includes all 512 casing variants of “interview” in both include and exclude rules, Unicode/diacritic folding, literal phrases, title-only matching, keyword precedence, empty labels, hidden calendars, deterministic occurrence ordering, ongoing/all-day/zero-duration boundaries, advancing time, both DST transitions, year/leap-day transitions, and re-filtering after feed refresh without changing the day-view data. These are deterministic local tests; they do not prove live Google/iCloud sync or Settings persistence end to end. Sample-data UI checks verified mixed-case inclusion, exclusion overriding inclusion, label removal, and week-spanning results.

Layout verification: the sample-data Mac preview was checked after consolidating the Calendar toolbar and removing repeated Upcoming headings. Filters opens the Calendars settings tab directly; General, Calendars, and Alerts organize the settings into scrollable panes. Keyword rows constrain long labels to the panel width, and the narrow Today agenda has a bounded scroll area so reminders retain space. The preview was closed after checking navigation and Settings dismissal.

### Personal event notes

Expanded event cards offer a single **Add personal note** row when empty. Saved notes use selectable text matching the calendar description, with a pencil beside the heading and an inline plain-text editor. Longer notes have a five-line preview with Show full notes/Show less. The lock beside the heading explains local-only autosave on hover and to accessibility clients. Edits save immediately; Done returns to the preview. Clearing the text removes the local note. The same note is available from Day, Next 7 days, and Today’s shared event card.

Notes live in `~/Library/Application Support/Beacon/calendar-personal-notes.json`, with atomic writes and owner-only file permissions. They never enter EventKit, calendar descriptions, or generated follow-up reminders, and Beacon does not sync them. The design preview uses its own `BeaconDesignPreview` directory. Failed writes retain the draft in memory and show a retry action; an unreadable file is never overwritten.

Identity uses the calendar and event identifiers, plus the original occurrence date for recurring events. This preserves notes when an event’s start time changes and keeps recurring occurrences separate. Provider/account rebuilds that replace identifiers may break that association; those provider behaviors have not been device-tested. Notes for events that disappear are retained locally.

Validation: 148 unit tests passed, including save/reload/clear, Unicode and multiline content, failed-write recovery, corrupt-file preservation, recurrence identity, and preview isolation. Both macOS bundles built successfully. Sample-preview UI checks covered autofocus, multiline editing, compact saved layout, Day/Next 7 days consistency, persistence after quitting/relaunching, and clearing a note. No live calendar events or reminders were modified.

Notes UI refinement validated in the sample preview: empty state, editor autofocus, matching typography, saved selectable text, long-note expand/collapse, re-editing, and clearing. Main and preview macOS builds passed.
