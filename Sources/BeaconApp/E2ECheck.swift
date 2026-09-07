import Foundation
import BeaconKit
import UserNotifications

/// End-to-end check against the live Reminders database.
///
/// It runs inside the app rather than as its own tool, so it uses the same
/// bundle, the same reminders grant and the same code path the app itself uses.
/// A separate binary would need its own permission grant and would prove less.
///
/// Run it with:  open -W build/Beacon.app --args --e2e --report <path>
enum E2ECheck {

        /// Every reminder this check creates starts with this.
        ///
        /// One fixed prefix, so leftovers from an interrupted run can always be
        /// found and removed later.
        static let markerPrefix = "beacon-e2e-"

        /// Read from the launch arguments, not the environment.
        ///
        /// `open` does not hand its own environment to the app it launches, so
        /// an env-var switch silently does nothing and the app just starts
        /// normally. Arguments after `--args` do arrive.
        static var isRequested: Bool { flag("--e2e") }

        /// Sweep-only mode: remove leftovers and exit, running no checks.
        static var isCleanupOnly: Bool { flag("--cleanup") }

        /// True for any headless run, so the normal app start-up is skipped.
        static var isHarnessRun: Bool { isRequested || isCleanupOnly }

        private static func flag(_ name: String) -> Bool {
            CommandLine.arguments.contains(name)
        }

        /// `--report <path>`, falling back to a temporary file.
        private static var reportPath: String {
            let arguments = CommandLine.arguments
            if let index = arguments.firstIndex(of: "--report"), index + 1 < arguments.count {
                return arguments[index + 1]
            }
            return NSTemporaryDirectory() + "beacon-e2e.txt"
        }

        /// Deletes every reminder this check has ever created.
        ///
        /// Run at the start of a check as well as at the end. The end-of-run
        /// cleanup cannot be relied on: a check killed part-way — which happened
        /// repeatedly during development — leaves its reminders in the user's
        /// real database. Sweeping first means the next run clears them.
        @MainActor
        static func sweep(_ store: ReminderStore) async -> Int {
            var keys: [String] = []

            if case let .ok(active) = await store.fetchActive() {
                keys += active.filter { $0.title.hasPrefix(markerPrefix) }.map(\.key)
            }
            let completed = await store.fetchRecentlyCompleted(within: 86_400 * 30, now: Date())
            keys += completed.filter { $0.title.hasPrefix(markerPrefix) }.map(\.key)

            var removed = 0
            for key in Set(keys) {
                guard (try? store.delete(key: key)) != nil else { continue }
                removed += 1
            }
            return removed
        }

        @MainActor
        static func runCleanupOnly() async -> Int32 {
            let store = ReminderStore()
            guard await store.requestAccess() == .granted else {
                log("Cannot read your reminders, so nothing was removed.")
                log("Allow Reminders access, then run this again.")
                return 1
            }
            let removed = await sweep(store)
            log("Removed \(removed) leftover reminder\(removed == 1 ? "" : "s") named \(markerPrefix)…")
            if removed == 0 { log("Nothing to clean up.") }
            return 0
        }

        private static let reportURL = URL(fileURLWithPath: reportPath)

        nonisolated(unsafe) private static var transcript = ""

        /// Records a line even before any mode is chosen, so a launch that
        /// takes the wrong branch is visible rather than silent.
        static func trace(_ line: String) { log(line) }

        private static func log(_ line: String = "") {
            transcript += line + "\n"
            try? transcript.write(to: reportURL, atomically: true, encoding: .utf8)
        }

        @MainActor
        static func run() async -> Int32 {

        var failures: [String] = []
        var passed = 0

        func check(_ ok: Bool, _ label: String) {
            if ok { passed += 1; log("  ok    \(label)") }
            else { failures.append(label); log("  FAIL  \(label)") }
        }

        let store = ReminderStore()
        let marker = markerPrefix + String(Int(Date().timeIntervalSince1970))

        log("Beacon end-to-end check\n")
        log("Access")
        let access = await store.requestAccess()
        check(access == .granted, "reminders access granted")
        guard access == .granted else {
            log("\nGrant Reminders access and run again.")
            return 1
        }

        // Guarded read
        log("\nRead path")
        let outcome = await store.fetchActive()
        guard case let .ok(initial) = outcome else {
            check(false, "fetch returned a usable list")
            return 1
        }
        check(true, "fetch returned a usable list (\(initial.count) active tasks)")
        check(!store.writableLists.isEmpty, "a writable list exists")

        // Clear anything an earlier interrupted run left behind, before adding
        // more.
        let swept = await sweep(store)
        if swept > 0 { log("  note  removed \(swept) leftover reminder(s) from an earlier run") }

        var created: [String] = []
        func cleanup() {
            for key in created { try? store.delete(key: key) }
        }

        // Create with a due date
        log("\nCreate")
        let due = Calendar.current.date(byAdding: .hour, value: 3, to: Date())!
        do {
            let key = try store.create(title: "\(marker) timed", due: due, notes: "written by the e2e check")
            created.append(key)
            guard case let .ok(after) = await store.fetchActive(),
                  let found = after.first(where: { $0.key == key }) else {
                check(false, "created task appears in a fresh fetch"); cleanup(); return 1
            }
            check(true, "created task appears in a fresh fetch")
            check(found.title == "\(marker) timed", "title round-tripped")
            check(found.notes == "written by the e2e check", "notes round-tripped")
            check(found.hasTimeOfDay, "due carries a time of day, not all-day")
            let drift = abs((found.due ?? .distantPast).timeIntervalSince(due))
            check(drift < 1, "due date round-tripped within a second (drift \(String(format: "%.2f", drift))s)")
        } catch {
            check(false, "create threw: \(error)"); cleanup(); return 1
        }

        // Create undated
        do {
            let key = try store.create(title: "\(marker) undated", due: nil)
            created.append(key)
            guard case let .ok(after) = await store.fetchActive(),
                  let found = after.first(where: { $0.key == key }) else {
                check(false, "undated task appears"); cleanup(); return 1
            }
            check(found.due == nil, "undated task really has no due date")

            // The promise: an undated task still gets scheduled.
            let plan = Scheduler.plan(
                now: Date(), tasks: [found], state: [:],
                settings: .default, calendar: .current
            )
            check(plan.notifications.contains { $0.taskKey == key },
                  "undated task is still scheduled — no task can be silent")
            check(plan.notifications.contains { $0.kind == .digest },
                  "the daily digest floor is present")
        } catch {
            check(false, "undated create threw: \(error)")
        }

        // Update
        log("\nUpdate")
        if let key = created.first {
            do {
                let moved = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
                try store.update(
                    key: key, title: "\(marker) renamed", due: moved,
                    notes: "edited", listID: nil, recurrence: nil
                )
                guard case let .ok(after) = await store.fetchActive(),
                      let found = after.first(where: { $0.key == key }) else {
                    check(false, "updated task still readable"); cleanup(); return 1
                }
                check(found.title == "\(marker) renamed", "renamed title round-tripped")
                check(found.notes == "edited", "edited notes round-tripped")
                check(abs((found.due ?? .distantPast).timeIntervalSince(moved)) < 1, "moved due date round-tripped")
            } catch {
                check(false, "update threw: \(error)")
            }
        }

        // Recurrence
        log("\nRecurrence")
        do {
            let rule = Recurrence(frequency: .weekly, interval: 2, daysOfWeek: [3])
            let key = try store.create(
                title: "\(marker) repeating",
                due: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
                recurrence: rule
            )
            created.append(key)
            guard case let .ok(after) = await store.fetchActive(),
                  let found = after.first(where: { $0.key == key }) else {
                check(false, "repeating task appears"); cleanup(); return 1
            }
            check(found.isRecurring, "EventKit reports the task as repeating")
            check(found.recurrence == rule,
                  "recurrence round-tripped exactly (got \(String(describing: found.recurrence)))")

            // A repeating task must never take a due-date write on snooze.
            let before = found.due
            guard case let .ok(again) = await store.fetchActive(),
                  let unchanged = again.first(where: { $0.key == key }) else {
                check(false, "re-read repeating task"); cleanup(); return 1
            }
            check(unchanged.due == before, "repeating task's due date is left alone")
        } catch {
            check(false, "recurrence create threw: \(error)")
        }

        // Complete, then the recently-completed window
        log("\nComplete")
        if let key = created.first {
            do {
                try store.setCompleted(true, key: key)
                guard case let .ok(after) = await store.fetchActive() else {
                    check(false, "fetch after completing"); cleanup(); return 1
                }
                check(!after.contains { $0.key == key }, "completed task leaves the active list")

                let recent = await store.fetchRecentlyCompleted(within: 3600, now: Date())
                check(recent.contains { $0.key == key },
                      "completed task appears under Recently Completed")

                try store.setCompleted(false, key: key)
                guard case let .ok(restored) = await store.fetchActive() else {
                    check(false, "fetch after un-completing"); cleanup(); return 1
                }
                check(restored.contains { $0.key == key }, "un-completing puts it back")
            } catch {
                check(false, "complete threw: \(error)")
            }
        }

        // Snooze writes a due date
        log("\nSnooze")
        if let key = created.first {
            do {
                let target = Date().addingTimeInterval(45 * 60)
                try store.setDue(target, key: key)
                guard case let .ok(after) = await store.fetchActive(),
                      let found = after.first(where: { $0.key == key }) else {
                    check(false, "snoozed task readable"); cleanup(); return 1
                }
                check(abs((found.due ?? .distantPast).timeIntervalSince(target)) < 1,
                      "snooze wrote the new due date through to Reminders")
            } catch {
                check(false, "snooze threw: \(error)")
            }
        }

        // Sidecar
        log("\nSidecar")
        let sidecar = Sidecar(filename: "e2e-sidecar.json")
        await sidecar.recordSnooze(key: "k", anchor: nil, now: Date())
        await sidecar.recordSnooze(key: "k", anchor: nil, now: Date())
        check(await sidecar.snoozeCount(for: "k") == 2, "sidecar counts snoozes")
        await sidecar.prune(keepingKeys: [])
        check(await sidecar.snoozeCount(for: "k") == 0, "pruning drops rows for gone tasks")

        // Planner against the real database
        log("\nPlanner on live data")
        if case let .ok(live) = await store.fetchActive() {
            let plan = Scheduler.plan(
                now: Date(), tasks: live, state: [:], settings: .default, calendar: .current
            )
            check(plan.notifications.count <= Settings.default.slotBudget,
                  "plan fits the slot budget (\(plan.notifications.count)/\(Settings.default.slotBudget))")
            check(live.isEmpty || plan.notifications.contains { $0.kind == .digest },
                  "floor present on the real database")
            check(Set(plan.notifications.map(\.identifier)).count == plan.notifications.count,
                  "no duplicate identifiers on real data")

            let second = Scheduler.plan(
                now: Date(), tasks: live, state: [:], settings: .default, calendar: .current
            )
            check(plan.notifications.map(\.identifier) == second.notifications.map(\.identifier),
                  "two plans moments apart agree on real data")
        }

        // Notifications
        log("\nNotifications")
        let notifier = NotificationScheduler()
        notifier.registerCategories()

        let authorized = await notifier.isAuthorized
        log("  note  authorization: \(await notifier.authorizationDescription)")

        // Request construction is checkable without any permission at all.
        if case let .ok(live) = await store.fetchActive(), !live.isEmpty {
            let plan = Scheduler.plan(
                now: Date(), tasks: live, state: [:], settings: .default, calendar: .current
            )
            let built = plan.notifications.compactMap { NotificationScheduler.request(for: $0) }
            check(built.count == plan.notifications.count,
                  "every planned alert produced a request (\(built.count)/\(plan.notifications.count))")

            let repeating = built.filter {
                ($0.trigger as? UNCalendarNotificationTrigger)?.repeats == true
            }
            check(repeating.count >= 1, "at least one repeating trigger exists (the floor)")

            check(built.allSatisfy { $0.content.interruptionLevel == UNNotificationInterruptionLevel.timeSensitive },
                  "every alert is time-sensitive, so Focus cannot swallow it")
            check(built.allSatisfy { !$0.content.categoryIdentifier.isEmpty },
                  "every alert carries a category, so its buttons appear")
            check(built.filter { $0.content.categoryIdentifier == Scheduler.taskCategory }
                    .allSatisfy { $0.content.userInfo["taskKey"] != nil },
                  "every task alert names its task, so its buttons can act")

            // The next fire must be in the future, or the alert is dead on arrival.
            let dead = built.compactMap { request -> String? in
                guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                      !trigger.repeats else { return nil }
                guard let next = trigger.nextTriggerDate() else { return request.identifier }
                return next > Date() ? nil : request.identifier
            }
            check(dead.isEmpty, "no one-shot alert is scheduled in the past (\(dead.count) dead)")

            if authorized {
                await notifier.apply(plan)
                let pending = await notifier.pendingCount()
                check(pending == plan.notifications.count,
                      "the system holds exactly the planned alerts (\(pending)/\(plan.notifications.count))")

                // Applying twice must not double anything: the plan is total.
                await notifier.apply(plan)
                let again = await notifier.pendingCount()
                check(again == pending, "applying the same plan twice changes nothing")

                let categories = await notifier.registeredCategoryIdentifiers()
                check(categories.contains(Scheduler.taskCategory),
                      "the task category is registered with the system")
            } else {
                log("  SKIP  delivery checks — notifications are not authorized")
            }
        }

        // Grouping and muting
        log("\nGrouping and muting")
        if case let .ok(live) = await store.fetchActive() {
            let byList = Sections.groupByList(live, now: Date(), calendar: .current)
            check(byList.reduce(0) { $0 + $1.tasks.count } == live.count,
                  "grouping by list keeps every task (\(byList.count) lists)")
            check(Set(byList.map(\.name)).count == byList.count,
                  "each list appears exactly once")

            if let sample = live.first {
                let muted = Sidecar(filename: "e2e-mute.json")
                await muted.setMuted(true, key: sample.key)
                let plan = Scheduler.plan(
                    now: Date(), tasks: live, state: await muted.state,
                    settings: .default, calendar: .current
                )
                check(!plan.notifications.contains { $0.taskKey == sample.key },
                      "a muted task is scheduled no alerts")
                check(live.contains { $0.key == sample.key },
                      "a muted task still appears in the list")
                await muted.setMuted(false, key: sample.key)
                let restored = Scheduler.plan(
                    now: Date(), tasks: live, state: await muted.state,
                    settings: .default, calendar: .current
                )
                check(restored.notifications.contains { $0.taskKey == sample.key },
                      "un-muting restores its alerts")
                await muted.prune(keepingKeys: [])
            }
        }

        // Someday
        log("\nSomeday")
        do {
            let far = Settings.somedayDate(from: Date(), calendar: .current)
            let key = try store.create(title: "\(marker) someday", due: far)
            created.append(key)
            guard case let .ok(after) = await store.fetchActive(),
                  let found = after.first(where: { $0.key == key }) else {
                check(false, "someday task appears"); cleanup(); return 1
            }
            check(found.isSomeday(now: Date(), horizon: Settings.default.somedayHorizon),
                  "a Someday task reads as Someday after a round trip through Reminders")
            check(Sections.bucket(found, now: Date(), calendar: .current) == .someday,
                  "it lands in the Someday section")
            check(Sections.relativeText(for: found, now: Date(), calendar: .current) == "Someday",
                  "the row says Someday rather than a date ten years out")

            let plan = Scheduler.plan(
                now: Date(), tasks: after, state: [:], settings: .default, calendar: .current
            )
            check(!plan.notifications.contains { $0.taskKey == key },
                  "a Someday task takes no alerts")
            check(plan.notifications.contains { $0.kind == .digest },
                  "the floor still stands alongside it")

            // Promoting it back must restore ordinary scheduling.
            let soon = Date().addingTimeInterval(2 * 3600)
            try store.setDue(soon, key: key)
            guard case let .ok(promoted) = await store.fetchActive(),
                  let back = promoted.first(where: { $0.key == key }) else {
                check(false, "promoted task readable"); cleanup(); return 1
            }
            check(!back.isSomeday(now: Date(), horizon: Settings.default.somedayHorizon),
                  "giving it a real time takes it out of Someday")
            let after2 = Scheduler.plan(
                now: Date(), tasks: promoted, state: [:], settings: .default, calendar: .current
            )
            check(after2.notifications.contains { $0.taskKey == key },
                  "and its alerts come back")
        } catch {
            check(false, "someday round trip threw: \(error)")
        }

        // Cleanup
        log("\nCleanup")
        cleanup()
        let stragglers = await sweep(store)
        check(stragglers == 0, "nothing was left behind (\(stragglers) stragglers swept)")
        if case let .ok(final) = await store.fetchActive() {
            check(!final.contains { $0.title.contains(marker) }, "every task the check created is gone")
        }

        log("\n\(passed) checks passed, \(failures.count) failed")
        if !failures.isEmpty {
            log("\nFailed:")
            failures.forEach { log("  \($0)") }
            return 1
        }
        return 0
        }
}
