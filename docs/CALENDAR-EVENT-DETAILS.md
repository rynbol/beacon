# Calendar event details

Day, Next 7 days, and Today use a shared expandable Swiftcn card. The header contains the event title, formatted time, and calendar source once. A chevron communicates the expanded state. Details reveal downward from beneath the header over 260 ms, clipped to their own region; neighboring rows move with the expansion. Reduce Motion disables animation.

Location and notes align with the header text. Notes initially occupy up to five lines and can expand in the page without a nested scroll area. Meeting and follow-up actions use the existing button styles and wrap vertically when horizontal space is insufficient. The header, close button, and Escape can collapse the event. Switching to another event closes the previous one; navigation/filter changes clear selections that are no longer visible. Calendar reads and follow-up defaults are unchanged.

Validation: regular and preview Mac builds succeeded; 137 unit tests passed. Sample UI checks covered expansion in Day/Next 7 days/Today, switching between events, an event without a meeting link, full notes, Escape, and opening a follow-up editor with the expected title and source notes. The all-day sample label was present in the weekly list. Screenshots verified the expanded layouts. The sample editor was dismissed without saving and the preview was closed. No real calendar data or reminders were changed. Meeting links stayed disabled in preview and were not opened. Window resizing failed in the UI tool, so the narrow-width fallback and system Reduce Motion setting were source-reviewed rather than device-verified. Screenshots establish layout, not frame-by-frame animation timing.


## Follow-up fixes

Provider notes may contain HTML rather than plain text. CalendarNotes uses exact-pinned SwiftSoup 2.9.6 to parse string fragments into inert text, preserving line breaks, list items, decoded entities, and useful link destinations. It never renders HTML or loads remote resources. Plain-text notes are retained unchanged. Zoom meeting detection now accepts zoom.com and its subdomains as well as zoom.us, while retaining HTTPS and domain-boundary checks. A location that is exactly the meeting URL is omitted from the details because Join meeting already represents it.

Expandable day/week lists now use eager vertical stacks to keep row heights deterministic during disclosure. The clipped detail region explicitly limits hit testing, and closing content becomes non-interactive. Close/follow-up callbacks check the selected event before acting, so an outgoing card cannot dismiss a newly selected one.

Validation: 143 tests passed, including six new HTML and link regressions. The sample preview verified repeated expansion/collapse, Escape, switching events, clearing a selected event through search, clean rendered HTML notes, the Zoom action, and scrolling with an expanded panel. Preview and regular builds passed. No real meeting link was opened and no calendar event was modified. These checks cover the identified problems; they do not establish that every possible animation issue is eliminated.
