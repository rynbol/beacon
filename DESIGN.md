# Beacon — System Design (v2)

Personal Unforgetful-style reminder engine. iOS 26 + macOS 26, Swift/SwiftUI, one developer, not for the App Store.
v1: 2026-08-17. **v2: 2026-08-17, revised after an adversarial design review** (4 blockers, 14 majors — see §12).
Plan artifact: https://claude.ai/code/artifact/d0a7d61c-7f1a-46a1-b538-7b7d4e07aaec

---

## 0. What changed in v2 (changelog)

| Change | Why (review finding) |
|---|---|
| Planner quantizes past-due fires to a 15-min grid; `now` enters only via day number + grid index | B1: `max(due, now)` made the plan depend on the rebuild instant → starvation, false determinism, phantom "ignored fires" |
| Rebuild never applies a plan from an unproven fetch; empty-plan failsafe | B2: `fetchReminders` has no error channel — a revoked permission or cold-start race would wipe all 32 beacons |
| Floor redesigned: ONE unconditional digest beacon + per-task beacons as a quality layer | B3: a 32-beacon floor is smaller than an ordinary Reminders database (groceries + someday lists) |
| All alerts `.timeSensitive`; Focus allow-list is an onboarding verification step | B4: `.active` is withheld by Focus; the floor tier must break through or the promise is fiction |
| Zero-OS-calls diff optimization deleted — every rebuild re-adds all requests | M1: notification content is immutable; a renamed task or edited ladder never reached the OS |
| Daily rotation cut | M2: rotation contradicts the zero-execution beacon; UTC day-number churned the set mid-morning |
| Spacing = one global sweep `max(t, prev+90s)`, not 5-min buckets | M3: bucket offsets overflow their own window at 5+ collisions |
| Recurrence math delegated to Apple: complete→save→refetch→loop (capped); writer ships log-only first | M4 + ReminderKit finding: the daemon already rolls forward from now; a custom evaluator corrupts "last weekday" rules |
| CloudKit sidecar, silent push, identity fingerprints — all cut; sidecar is device-local SwiftData | M7/M10/M11 + cut list: only the iPhone alerts, so nothing needs cross-device snooze state |
| Location tier deferred to v2 roadmap | M5 + cut list: highest effort, lowest reliability; every location task needed a time fallback anyway |
| 9-category matrix → one category; interval named in the body text | Cut list: an editable ladder forces re-registration on every edit |
| Widgets, Controls, snapshot.json, App Group deferred to v2 roadmap | Cut list: capture via app icon + automations covers v1 |
| Budget 50 slots, not 60; eviction-policy probe added to M2 | M8: remove-then-add races the cap and the eviction policy is undocumented |
| Rebuild on `NSSystemTimeZoneDidChange`; re-add makes it effective | M9: repeating-trigger time-zone behavior is contested in the field |
| Alerting flag is device-local, default OFF on new installs | M12: a global "iPhone alerts" role cannot express an iPad |
| Watchdog self-alert + annual re-sign reminder inside Reminders | M13: a dev-profile install expires within ~1 year; the app then freezes while its notifications look alive |
| External completions of recurring tasks detected and rolled forward on rebuild | M14: Siri and the Reminders app complete recurring tasks the normal way — banning it only bound Beacon |

## 1. Problem

Apple Reminders fails its user in three ways (Marco Arment's framing, adopted here):
1. A task with no time never notifies — it is easily lost. (Narrower than claimed: the stock
   "Today Notification" setting covers dated-but-untimed tasks; truly undated ones stay silent.)
2. A dismissed notification never returns.
3. The snooze options are bad.

Beacon is a notification engine over the Reminders database that makes a task hard
to lose: notifications repeat until the task is completed or deleted, snooze intervals
scale with use, and nothing is ever "overdue."

**The honest alternative, tested first (M0):** iOS 26.2 "Urgent" + a 3×-daily Shortcuts
automation that assigns due times to undated reminders covers a large slice of this for
zero code. Two weeks on that baseline prices the build honestly. The verified gaps it
cannot cover: no auto re-arm after dismissal, single-device alarm, no scaling snooze,
no shame-free framing.

## 2. Goals / Non-goals

**Goals (v1)**
- No task can exist that will never notify — enforced by a floor that holds at ANY task count.
- Notifications repeat until complete/delete, surviving reboot, force-quit, and weeks of app inactivity.
- Snooze ladder scales per task and is user-editable.
- Typed natural-language date input on both platforms.
- Never "overdue": past-due tasks render "Now"; no red state anywhere.
- Simultaneous alerts space out (global sweep, min 90 s apart).
- Recurring tasks reschedule from *now* after a miss — via Apple's own daemon mechanism.
- Full Reminders interop: Siri, Remind Me Faster, the Reminders app all remain capture surfaces.

**Non-goals (v1)** — folders/tags/views/collaboration (product thesis); Apple Watch; App Store;
accounts/servers; AlarmKit; **and deferred to v2:** location reminders, widgets/Controls,
CloudKit-synced snooze state, daily notification-order rotation.

## 3. Hard platform constraints (verified)

| # | Constraint | Design response |
|---|---|---|
| C1 | 64 pending local notifications per app; **eviction policy undocumented** (soonest-kept vs newest-kept unknown); macOS cap unverified | Budget **50**; M2 probe measures both platforms and the eviction order |
| C2 | Delivered-but-ignored notification does NOT wake the app; only a response does (incl. swipe with `.customDismissAction`) | Floor needs zero execution; every response rebuilds |
| C3 | Repeating `UNCalendarNotificationTrigger` fires forever with no app runs (Apple-documented); interval triggers anchor to add-time | Beacons are calendar triggers |
| C4 | Extensions are denied EventKit since iOS 16.1 | Intents live in the app target (widgets deferred anyway) |
| C5 | `eventStoreChanged` has no payload; live processes only | Debounce 500 ms + full refetch; Mac is an always-on login item |
| C6 | `BGAppRefreshTask` is a hint; absent on native macOS | Nothing correctness-critical on it; macOS uses `SMAppService` + `NSBackgroundActivityScheduler` |
| C7 | Notification content is immutable after `add()`; same-identifier re-add replaces atomically (Apple-documented) | Every rebuild re-adds the full plan; no diff optimization |
| C8 | EventKit hides subtasks/URL/tags/Smart Lists. Writes: due requires start (iOS), Gregorian only or ObjC exception, h/m/s or all-day, invalid dates silently normalize (Feb 31 → Mar 3) | One writer; `isValidDate` gate; precondition on Gregorian |
| C9 | No API suppresses another app's notifications | Onboarding: turn Reminders alerts off manually; never strip EKAlarms |
| C10 | Completing a recurring reminder via EventKit triggers the DAEMON's roll-forward: original reset to incomplete + due advanced past now + a NEW clone holds the completion (binary-verified iOS 18.2; per-account-type gating; undocumented) | Use it as the recurrence engine; never key "did my write stick" on `isCompleted`; on-device test on OS 26 before trusting |
| C11 | Silent pushes: ~2–3/hour soft cap, never guaranteed, dead after force-quit or Background App Refresh off | Cut from v1; Shortcuts automations are the wake net |
| C12 | A dev-profile install stops LAUNCHING at profile expiry (≤ ~1 year; TestFlight 90 days); whether pending notifications still fire is unverified | Annual re-sign reminder stored in Reminders; 7-day watchdog self-alert |
| C13 | Paid Apple Developer account required (free = 7-day builds) | Prerequisite, M0 |

## 4. High-level architecture (v2 — simplified)

```
    Siri ("remind me...")        Reminders app · Remind Me Faster · Fantastical
          │                                      │
          ▼                                      ▼
   ┌────────────────────────────────────────────────────┐
   │       Apple Reminders database  (EventKit)         │   SOURCE OF TRUTH
   │       task sync via iCloud — Apple's problem       │
   └───────────┬──────────────────────────┬─────────────┘
               │ EventKit read/write      │ EventKit read (write-capable)
               ▼                          ▼
   ┌───────────────────────┐   ┌───────────────────────┐
   │     Beacon iOS        │   │     Beacon macOS      │
   │  THE ALERTING DEVICE  │   │  viewer + capture     │
   │  ReminderStore        │   │  MenuBarExtra field   │
   │  Scheduler (pure fn)  │   │  login item, no quit  │
   │  Sidecar (LOCAL only) │   │  15-min rescan tick   │
   └──────────┬────────────┘   └───────────────────────┘
              ▼
   UNUserNotificationCenter  ≤50 slots
   floor: 1 digest beacon (unconditional, forever)
   quality: per-task beacons + same-day ladder
```

The alerting flag is device-local and defaults to OFF on a new install. In v1 exactly
one device (the iPhone) turns it on. No cross-device scheduler state exists, so there
is nothing to sync and nothing to conflict.

## 5. Core loop

```
wake ∈ { notification response (tap/snooze/swipe·C2), app foregrounded,
         eventStoreChanged (C5), Mac 15-min tick, Shortcuts automations
         07:30/12:30/19:30, BGAppRefreshTask (best-effort),
         NSSystemTimeZoneDidChange }

Rebuild(now):                              // serialized on @SchedulerActor
  0  GUARD: authorizationStatus == .fullAccess
           AND calendars(for:.reminder) is non-empty
           AND fetch returned non-nil            // else: keep last plan,
                                                 // fire "Beacon cannot read
                                                 // your reminders" failsafe
  1  tasks = ReminderStore.fetchActive()
  2  state = Sidecar.load()                      // local SwiftData
  3  plan  = Scheduler.plan(now, tasks, state, settings)   // PURE, grid-quantized
  4  GUARD: if plan is empty and last persisted plan was not, abort + failsafe
  5  re-add EVERY planned request (same id ⇒ atomic replace, C7);
     remove ids no longer planned; persist the applied plan
```

### 5.1 Effective-fire grid (the B1 fix)

A past-due or undated task never fires "at `now`". Its effective fire snaps to the next
15-minute boundary of the local day, or to `snoozeAnchor + ladder[n]` after a snooze.
`now` enters the planner only through the local day number and the grid index, so two
rebuilds seconds apart produce byte-identical plans, and a golden test asserts exactly
that (same inputs at 10:00:04 and 10:00:11 → same output).

### 5.2 Slot budget (50 of 64, C1)

| Tier | Slots | Trigger | Purpose |
|---|---|---|---|
| **Digest beacon — THE FLOOR** | 1 | repeating `UNCalendarNotificationTrigger` at a fixed hour, static text ("Beacon: tasks are waiting") | Unconditional at ANY task count; fires daily forever with zero execution; cannot go stale |
| Per-task beacons | ≤ 30 | repeating calendar trigger, one per task, nearest-due first | Named daily nag per task |
| Same-day ladder | ≈ 19 | one-shot calendar triggers, max 3/task | Dense "it keeps bugging me today" texture |

Goal 1 rests on the digest beacon alone. Per-task beacons and the ladder are quality
layers that can drop, churn, or misfire without breaking the promise.

### 5.3 Snooze ladder (editable) + one category

```swift
ladder = [15m, 30m, 1h, 2h, 4h, 8h, 24h]          // settings-backed, editable
interval(n) = ladder[min(n, ladder.count-1)]
```
- One `UNNotificationCategory` with Complete / Snooze / Snooze-longer, all non-foreground,
  `.customDismissAction` on. The chosen interval is named in the notification BODY
  (content is re-added every rebuild, so it is always current).
- Ignored-fire detection is conservative (M6): count an ignored fire only when the due
  date is unchanged since the planned fire; never write a due date earlier than the stored
  one; advance at most one rung per rebuild.
- Snooze on a NON-recurring task writes the new due date into the `EKReminder` (syncs free).
  Snooze on a RECURRING task changes notification timing only — a due-date write re-anchors
  the series (C10 finding), which the user did not ask for.

### 5.4 Spacing (global sweep) + quiet hours

Sort candidates by `(fire, stableHash(taskKey))`; walk and push each fire to
`max(t, previous + 90s)`; cap total drift at 30 min and drop the overflow (the floor
covers it). Quiet hours 22:00–08:00 shift fires to 08:00 next day — except a fire the
user explicitly requested within the last 10 minutes ("remind me in 15 minutes" at 23:00
means 23:15, not tomorrow).

### 5.5 Recurring tasks — Apple's daemon does the math

To complete: set `isCompleted = true`, save, refetch, repeat until the due date passes
`now` (hard cap 60 iterations). The daemon advances the series and stores each completion
in a clone (C10). This handles every rule Apple's UI can produce — "last weekday",
`setPositions`, day-31 clamping — with zero custom recurrence code.
- The writer ships in **log-only mode** until the M3 on-device round-trip test passes.
- Verification never keys on `isCompleted` (the daemon resets it to false by design).
- External completions (Siri, Reminders app): if a rebuild finds a recurring task with a
  past due date and a fresh completion clone, run the same loop (M14).
- Time zone: write floating local components, never GMT (the daemon's own DST-drift
  fault log confirms the hazard).

### 5.6 Interruption level — the B4 decision, written down

All Beacon notifications are `.timeSensitive` (requires the capability, no Apple approval).
Onboarding verifies two things and re-checks weekly: Time Sensitive delivery is not
revoked for Beacon, and Beacon is allow-listed in every Focus the user runs. The daily
digest at a fixed morning hour is the accepted cost of a floor that actually surfaces.

## 6. Data — device-local sidecar (v2)

**Hard state:** Apple Reminders. **Soft state:** a LOCAL SwiftData store — no CloudKit,
no App Group (widgets deferred), no fingerprints, no dedupe, no environment traps.

```swift
@Model final class TaskState {
  var key: String = ""            // calendarItemIdentifier (device-local is fine now)
  var snoozeCount: Int = 0
  var snoozeAnchor: Date?         // grid anchor after an explicit snooze
  var lastPlannedFire: Date?
  var completedAt: Date?          // 1-hour Recently Completed
  var mutatedAt: Date = .now
}
```
Unknown key ⇒ new row with count 0. A full Reminders resync can regenerate identifiers;
the cost is reset snooze counts, never a lost task (the floor is stateless). Rows for
completed tasks are garbage-collected after 24 h.

**The one EventKit writer:** always start AND due, Gregorian (precondition), h/m/s set,
`isValidDate(in:)` gate before every save, floating local time zone.

## 7. Capture (v1)

| Surface | Path |
|---|---|
| Siri | Free via Reminders — no app name, zero code |
| Typed NL dates | `NSDataDetector` in shared `Capture.parse()` — both platforms |
| In-app | Capture sheet, auto-focused field, pull-to-add; keyboard mic covers dictation |
| Mac | `MenuBarExtra` capture field, same parser |
| App Intents | `AddTask` / `CompleteTask` / `SnoozeTask` / `Rescan` in the app target |
| Shortcuts automations | 3×/day `RescanIntent` — the wake net for Siri-created tasks |

Widgets, Lock Screen, Control Center: v2 roadmap.

**Motion policy** (adopted 2026-08-18 from Emil Kowalski's "You Don't Need Animations"):
- No animation on high-frequency paths: complete, snooze, capture-sheet open. Beacon runs
  many times per day; instant response beats delight, and this matches the ADHD thesis.
- Any animation stays under 300 ms and respects Reduce Motion.
- Keyboard-initiated actions (Mac capture field) never animate.
- One rare delight moment only: the checkmark transition into Recently Completed.

## 8. App structure (v2 — two targets gone)

```
Beacon.xcodeproj
├── Beacon                multiplatform app target (iPhone/iPad/Mac native)
│                         owns the notification delegate before launch completes;
│                         macOS: MenuBarExtra + SMAppService login item, never quits
└── Packages/BeaconKit    ReminderStore · Scheduler (pure, unit-tested) · Sidecar
                          · Capture · Formatting
```

## 9. Failure modes (v2)

| Failure | Standing answer |
|---|---|
| Reminders access revoked / cold-start empty fetch | Guard 0 + empty-plan guard keep the last plan and fire a failsafe alert — the pending set is never wiped by a bad read |
| Siri-created task, no Beacon process runs | Digest beacon still fires daily; Shortcuts automations rescan 3×/day; Mac tick rescans 15-min when awake |
| >31 active tasks | Nearest 30 get named beacons; the digest covers the rest — Goal 1 holds at any count |
| Sidecar lost | Snooze counts reset; floor unaffected |
| Profile expiry (C12) | Annual re-sign task in Reminders + watchdog: if no successful rebuild in 7 days, a pre-scheduled "Beacon needs attention" alert fires |
| Eviction near the cap (M8) | Budget 50; near-cap adds poll `pendingNotificationRequests()` after removals |
| Time-zone travel (M9) | `NSSystemTimeZoneDidChange` triggers a full re-add of every beacon |
| iPad installed later (M12) | Alerting flag device-local, default off — silent viewer until enabled |
| Habituation (−30%/repeat, Ancker 2017) | Escalating ladder to 24 h, quiet hours; retune after the soak — longer, never louder |

## 10. Milestones (v2)

| M | Deliverable | Verification |
|---|---|---|
| 0 | Paid account confirmed. **Baseline experiment:** Shortcuts automation assigns due times to undated reminders 3×/day + "Urgent" on key tasks; run it in parallel with the build | Two weeks of data on how much of the itch $0 scratches |
| 1 | Read-only mirror, both platforms (guarded fetch from day one) | Siri-created reminder appears in both apps in seconds |
| 2 | **Hardware proofs**: 30 repeating beacons + reboot + force-quit + 3 idle days; 200-request probe on iOS AND macOS recording the real cap and WHICH requests get evicted; time-zone flip probe on a pending beacon | All beacons fire; cap + eviction order + tz behavior are measured, not assumed |
| 3 | Local sidecar + writes + editable ladder; recurrence writer in log-only mode | Complete in Beacon → completed in Reminders; recurring round-trip observed and logged on OS 26 |
| 4 | `Scheduler.plan` pure + golden tests: grid quantization, sweep spacing, quiet hours, budget, and the two-`now` determinism test | Same inputs at 10:00:04 / 10:00:11 → identical plans |
| 5 | Delivery: full re-add each rebuild, one category, `.timeSensitive` + Focus onboarding check, digest + per-task beacons, empty-plan failsafe | Kill app → snooze from banner → relaunch shows the new rung; revoke Reminders access → failsafe alert, beacons intact |
| 6 | Shame-free semantics + recurring roll-forward flipped live (after M3 logs verify) + **1-week soak** | Daily task skipped 5 days completes into exactly 1 future instance, zero backlog |
| 7 | Mac app (viewer + capture + rescan tick) + Shortcuts automations + watchdog + annual re-sign reminder | Siri-create with the iPhone app unlaunched → next automation schedules it; watchdog alert observed after a forced 7-day stall |
| 8 | **2-week soak** + ladder/spacing/quiet-hours tuning against a written list | Tuning list resolved; v2 roadmap re-prioritized from lived data |

## 10a. Findings from the build

| Finding | Consequence |
|---|---|
| **Ad-hoc signatures break privacy grants.** `codesign -s -` derives the signature from the binary, so it changes on every build and macOS treats each build as a different app — silently revoking Reminders and Notifications every rebuild. | A stable self-signed certificate is a prerequisite, not a nicety. `Scripts/make-signing-identity.sh` creates it once. Note OpenSSL 3 needs `-legacy` for the PKCS#12 export, or the keychain import fails as a bogus "wrong password". |
| **Asking for notification permission cannot be left to a settings screen.** The first build only requested on an explicit button press, so the app scheduled nothing, said nothing, and looked broken. | Request on first launch; re-read the status on every rebuild; surface "cannot alert you" in the main window, not in Settings. |
| **`NSDataDetector` does not read "in 2 hours" or "in 30 minutes"** — the two most common reminder phrasings — though it does read "in 3 days". | A small relative-duration parser runs before it. |
| **`fetchReminders` hands back `[EKReminder]?` across a concurrency boundary.** The objects are not `Sendable`. | Convert to `TaskSnapshot` inside the callback. |
| **A muted task must look muted.** Silence the user chose and silence caused by a bug are indistinguishable otherwise. | Muted rows carry a bell-slash glyph. |
| **Do not run an audio engine for dictation.** An in-process `AVAudioEngine` failed three ways at once: a tap closure formed in a `@MainActor` type trapped on the realtime audio thread (`dispatch_assert_queue_fail`); the engine renegotiated the format of a device already running at 16 kHz and degraded playback for the whole machine; and it delivered zero buffers, returning `-10868 FormatNotSupported`. | Hand dictation to macOS via the `startDictation:` responder action. The audio never enters the process, so no device can be seized, no audio thread can trap, and no microphone permission is needed. The v1 design said this from the start, and overriding it cost real user harm. |

## 11. Open questions (settle on hardware)

1. Eviction policy at the cap — soonest-kept or newest-kept (M2).
2. Repeating-trigger behavior across a time-zone change (M2; field reports contradict Apple staff).
3. The daemon roll-forward on OS 26 with an iCloud list — and per account type (M3; binary evidence is iOS 18.2).
4. Do pending notifications fire after profile expiry (C12; unverified everywhere).
5. Does iOS 26.2 "Urgent" re-arm after dismissal (M0 baseline answers it by use).

## 12. v2 roadmap (deferred, in priority order)

1. Location reminders with post-arrival delay (needs `CLMonitor` reliability data + `armedAt` time-expiry design).
2. Widgets + Control Center capture (App Group snapshot pattern, C4).
3. Daily notification-order rotation (only if habituation shows up in the soak).
4. CloudKit sidecar + Mac alerting parity (only if single-device alerts prove insufficient).
5. AlarmKit "critical" flag per task (only if a soak shows missed must-do tasks).

## 13. Review provenance

Adversarial review 2026-08-17: 4 BLOCKER, 14 MAJOR, 7 MINOR findings; 7-item cut list;
steelman of the no-build alternative. Verified helper reports: silent-push limits,
SwiftData/CloudKit dedupe rules, CloudKit environments, ReminderKit recurrence daemon
(decompiled 18.2), provisioning/TestFlight expiry, iOS 26.3–26.5 Reminders changes
(no auto-repeat added by Apple). Full texts in the session task outputs.
