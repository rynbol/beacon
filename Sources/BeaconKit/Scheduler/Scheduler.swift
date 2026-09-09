import Foundation

/// Turns the current world into the exact set of notifications that should be
/// pending. Pure: no clock, no I/O, no globals, no `Calendar.current`.
///
/// The whole design rests on one property of this function — given the same
/// arguments it returns the same plan, on any device, at any moment inside a
/// grid window. That is what lets the iPhone and the Mac each schedule
/// independently and still behave like one system, with no protocol between
/// them.
public enum Scheduler {

    public static let taskCategory = "BEACON_TASK"
    public static let digestCategory = "BEACON_DIGEST"
    public static let digestIdentifier = "digest"
    public static let digestThread = "digest"

    public static func plan(
        now: Date,
        tasks: [TaskSnapshot],
        state: [String: TaskState],
        settings: Settings,
        calendar: Calendar
    ) -> Plan {
        // A muted task keeps its place in the list and loses only its alerts.
        let listed = tasks.filter { !$0.isCompleted && !(state[$0.key]?.isMuted ?? false) }
        // Someday tasks are deferred on purpose, so they take no beacon and no
        // ladder rung. Giving them one would nag daily about work the user has
        // already said is not for now — and would spend slots the near tasks
        // need. They are still counted, so the digest speaks for them.
        let active = listed.filter { !$0.isSomeday(now: now, horizon: settings.somedayHorizon) }
        guard !active.isEmpty else { return Plan(notifications: []) }

        var notifications: [PlannedNotification] = []
        var budget = settings.slotBudget

        // 1. The floor. One request, static text, unconditional at any task
        //    count. Everything below this line is a quality layer that may
        //    churn or drop without breaking the promise.
        notifications.append(digest(settings: settings))
        budget -= 1

        // 2. Base fire per task, grid-quantized so `now` cannot leak in.
        let bases = active.map { task -> Candidate in
            Candidate(
                task: task,
                hash: StableHash.u64(task.key),
                fire: baseFire(
                    for: task,
                    state: state[task.key] ?? TaskState(),
                    now: now,
                    settings: settings,
                    calendar: calendar
                )
            )
        }

        // 3. Named daily beacons for the nearest-due tasks, spread two minutes
        //    apart from the digest hour onward. The spread is a function of
        //    rank alone, so it needs no daily rebuild to stay separated.
        let byUrgency = bases.sorted { lhs, rhs in
            if lhs.fire != rhs.fire { return lhs.fire < rhs.fire }
            return lhs.hash < rhs.hash
        }
        // Daily triggers have no start date. Only arm them once a task is
        // actually due, otherwise tomorrow's task would alert this morning.
        let beaconEligible = byUrgency.filter { candidate in
            let taskState = state[candidate.task.key] ?? TaskState()
            let deferred = taskState.snoozedUntil ?? taskState.snoozeAnchor.map {
                $0.addingTimeInterval(settings.interval(forSnoozeCount: taskState.snoozeCount))
            }
            return (candidate.task.due ?? now) <= now && (deferred ?? now) <= now
        }
        let beaconCount = min(settings.maxTaskBeacons, min(beaconEligible.count, max(0, budget)))
        for (index, candidate) in beaconEligible.prefix(beaconCount).enumerated() {
            let offset = 2 + index * 2
            notifications.append(
                PlannedNotification(
                    identifier: "beacon#\(candidate.task.key)",
                    taskKey: candidate.task.key,
                    kind: .taskBeacon,
                    trigger: .repeatingDaily(
                        hour: (settings.digestHour + offset / 60) % 24,
                        minute: offset % 60
                    ),
                    title: candidate.task.title,
                    subtitle: NotificationCopy.subtitle(for: candidate.task),
                    body: NotificationCopy.body(urgency: candidate.task.urgency,
                        snooze: settings.interval(forSnoozeCount: state[candidate.task.key]?.snoozeCount ?? 0),
                        followUp: true),
                    categoryIdentifier: taskCategory,
                    threadIdentifier: candidate.task.key
                )
            )
        }
        budget -= beaconCount
        let overflow = beaconEligible.dropFirst(beaconCount).map(\.task.key)

        // 4. Same-day ladder, allocated round-robin by rung so one noisy task
        //    cannot eat the window before every other task has been heard once.
        let candidates = ladderCandidates(
            bases: bases,
            state: state,
            now: now,
            settings: settings,
            calendar: calendar
        )
        let selected = Array(candidates.prefix(max(0, budget)))

        // Spacing runs on the selected set in time order, after quiet hours,
        // so the morning pile gets separated rather than re-stacked.
        let (spaced, dropped) = applySpacing(to: selected, settings: settings)
        for rung in spaced {
            notifications.append(
                PlannedNotification(
                    identifier: "ladder#\(rung.taskKey)#\(Int(rung.fire.timeIntervalSince1970))",
                    taskKey: rung.taskKey,
                    kind: .ladder,
                    trigger: .oneShot(rung.fire),
                    title: rung.title,
                    subtitle: rung.subtitle,
                    body: NotificationCopy.body(urgency: rung.urgency, snooze: rung.snoozeOffer,
                                                followUp: rung.step > 0),
                    categoryIdentifier: taskCategory,
                    threadIdentifier: rung.taskKey
                )
            )
        }

        return Plan(
            notifications: notifications,
            spacingDropped: dropped,
            beaconOverflow: Array(overflow)
        )
    }

    // MARK: - Fire times

    /// When a task next deserves attention.
    ///
    /// A future due date is honoured exactly, because the user chose it. Anything
    /// past-due or undated snaps forward to the grid instead of to the current
    /// instant — a task is never late, it is due now or later (DESIGN.md §2).
    static func baseFire(
        for task: TaskSnapshot,
        state: TaskState,
        now: Date,
        settings: Settings,
        calendar: Calendar
    ) -> Date {
        var raw: Date

        if let until = state.snoozedUntil {
            raw = until > now ? until : FireGrid.nextBoundary(after: now, calendar: calendar, gridSeconds: settings.gridSeconds)
        } else if let anchor = state.snoozeAnchor {
            // A recurring task cannot take a due-date write, so its deferral
            // lives in the sidecar.
            let deferred = anchor.addingTimeInterval(settings.interval(forSnoozeCount: state.snoozeCount))
            raw = deferred > now
                ? deferred
                : FireGrid.nextBoundary(after: now, calendar: calendar, gridSeconds: settings.gridSeconds)
        } else if let due = task.due, due > now {
            raw = due
        } else {
            raw = FireGrid.nextBoundary(after: now, calendar: calendar, gridSeconds: settings.gridSeconds)
        }

        let explicit = state.explicitIntentAt.map { now.timeIntervalSince($0) < settings.explicitIntentWindow } ?? false
        guard !explicit else { return raw }

        return FireGrid.applyQuietHours(
            to: raw,
            calendar: calendar,
            startHour: settings.quietStartHour,
            endHour: settings.quietEndHour
        )
    }

    /// Ladder rungs for every task, already ordered by allocation priority:
    /// every task's first alert outranks any task's second.
    static func ladderCandidates(
        bases: [Candidate],
        state: [String: TaskState],
        now: Date,
        settings: Settings,
        calendar: Calendar
    ) -> [LadderRung] {
        var rungs: [LadderRung] = []

        for candidate in bases {
            let snoozeCount = (state[candidate.task.key] ?? TaskState()).snoozeCount
            var fire = candidate.fire

            for step in 0..<max(0, settings.maxLadderPerTask) {
                if step > 0 {
                    let gap = settings.interval(forSnoozeCount: snoozeCount + step - 1)
                    fire = FireGrid.applyQuietHours(
                        to: fire.addingTimeInterval(gap),
                        calendar: calendar,
                        startHour: settings.quietStartHour,
                        endHour: settings.quietEndHour
                    )
                }
                guard fire.timeIntervalSince(now) <= settings.ladderHorizon else { break }

                rungs.append(
                    LadderRung(
                        taskKey: candidate.task.key,
                        title: candidate.task.title,
                        subtitle: NotificationCopy.subtitle(for: candidate.task),
                        urgency: candidate.task.urgency,
                        step: step,
                        fire: fire,
                        hash: candidate.hash,
                        snoozeOffer: settings.interval(forSnoozeCount: snoozeCount)
                    )
                )
            }
        }

        return rungs.sorted { lhs, rhs in
            if lhs.step != rhs.step { return lhs.step < rhs.step }
            if lhs.fire != rhs.fire { return lhs.fire < rhs.fire }
            return lhs.hash < rhs.hash
        }
    }

    /// One global sweep in time order: each alert is pushed to at least
    /// `spacingSeconds` after the previous one.
    ///
    /// A per-bucket offset cannot do this — with five or more collisions the
    /// offsets overflow their own bucket and collide with the next one. Walking
    /// the whole list is both simpler and actually correct.
    static func applySpacing(
        to rungs: [LadderRung],
        settings: Settings
    ) -> (kept: [LadderRung], dropped: [String]) {
        let ordered = rungs.sorted { lhs, rhs in
            if lhs.fire != rhs.fire { return lhs.fire < rhs.fire }
            return lhs.hash < rhs.hash
        }

        var kept: [LadderRung] = []
        var dropped: [String] = []
        var previous: Date?

        for var rung in ordered {
            let original = rung.fire
            if let last = previous {
                let earliest = last.addingTimeInterval(settings.spacingSeconds)
                if rung.fire < earliest { rung.fire = earliest }
            }
            guard rung.fire.timeIntervalSince(original) <= settings.maxDriftSeconds else {
                dropped.append(rung.taskKey)
                continue
            }
            previous = rung.fire
            kept.append(rung)
        }

        return (kept, dropped)
    }

    static func digest(settings: Settings) -> PlannedNotification {
        PlannedNotification(
            identifier: digestIdentifier,
            taskKey: nil,
            kind: .digest,
            // Static text on purpose: notification content is frozen once
            // scheduled, so a count here would go stale the moment it fired
            // during a stretch where the app never runs (DESIGN.md §3 C7).
            trigger: .repeatingDaily(hour: settings.digestHour, minute: 0),
            title: "A moment for your day",
            body: "See what needs your attention in Beacon.",
            categoryIdentifier: digestCategory,
            threadIdentifier: digestThread
        )
    }

    // MARK: - Internal working types

    struct Candidate {
        let task: TaskSnapshot
        let hash: UInt64
        let fire: Date
    }

    struct LadderRung {
        let taskKey: String
        let title: String
        let subtitle: String
        let urgency: Urgency
        let step: Int
        var fire: Date
        let hash: UInt64
        let snoozeOffer: TimeInterval
    }
}
