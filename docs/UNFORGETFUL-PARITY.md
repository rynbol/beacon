# Unforgetful recreation: current target and gaps

The goal is a personal Mac implementation of Unforgetful's useful experience, without requiring its subscription. This supersedes the previous assumption that Beacon should become a different productivity workspace. Keep Beacon's own name and code.

## Verified reference

Sources checked September 6, 2026:

1. https://www.unforgetful.app/ — Reminders integration, persistent notifications, history-based snooze, no overdue treatment, simple list.
2. https://marco.org/2026/08/14/unforgetful — one list with no separate views; spaced notifications; missed recurring tasks advance beyond the backlog; delayed location reminders.
3. https://apps.apple.com/us/app/unforgetful-never-lose-a-task/id6785630295?platform=mac — Mac release notes and public feature descriptions.
4. https://apps.apple.com/us/app/unforgetful-never-lose-a-task/id6785630295 — newer release notes mention four configurable snooze presets, repeat from completion, parsing toggle, and Complete moved below Snooze in notifications. Storefront caches disagree about the latest Mac version, so these are documented features, not verified behavior of an installed Mac version.

No access to the subscription interface was used. Exact layout measurements, undocumented scheduling algorithms, and paywalled settings are not verified.

## Parity status

| Reference behavior | Beacon status |
|---|---|
| Apple Reminders as source of truth; Siri capture compatibility | Implemented; existing reminders read successfully |
| One list, relative-date sections, no overdue styling | Engine/presentation available; prior redesign added separate views, awaiting user's interface preference |
| Typed capture and dictation | Implemented; native dictation availability depends on macOS |
| Snooze durations grow with history | Implemented; exact recurring snooze deadline fixed |
| Notifications continue after dismissing | Preplanned alerts remain; dismissal no longer changes the task's due date |
| Notification buttons work after cold launch | Shared model is initialized before responding; callback now awaits the write. Requires real notification verification |
| Complete appears below Snooze | Implemented |
| Completion action never undoes a completed task | Implemented; notification completion is explicit rather than toggle |
| Repeated notices after long app inactivity | Daily fallback plus bounded one-shot plan; not full verified parity |
| Notifications spaced apart | One-shot alerts spaced; cross-tier and daily rotation parity still incomplete |
| Configurable snooze presets | Editable ladder exists; four distinct capture presets and weekend-aware options not implemented |
| Recurrence advances from completion / skips backlog | Basic EventKit recurrence; full advanced-rule/completion-relative parity incomplete |
| Location reminder with arrival delay | Not implemented |
| Widgets, Watch, iPhone | Outside current Mac-first implementation |

## Acceptance checks

Core acceptance is functional, not a screenshot: Siri-created reminder appears, undated reminders receive alerts, dismissal does not lose or reschedule a task, Snooze uses the displayed interval, repeated Complete cannot undo completion, and notification actions work when the app must launch. Live checks must use explicitly isolated test reminders. Unit tests are evidence for the planner, not delivery evidence.

UI access policy: only during a specific edit or test. Do not keep watching, recapturing, or activating the user's running app.
