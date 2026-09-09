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
        static var isHarnessRun: Bool { isRequested || isCleanupOnly || isNotificationPreview }

        static var isNotificationPreview: Bool { flag("--notification-preview") }

        /// One silent, disposable notification. No reminder reads/writes or
        /// replacement scheduling; removes only its own UUID after inspection.
        @MainActor
        static func runNotificationPreview() async -> Int32 {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                try? "Notification preview unavailable: no existing authorization.".write(toFile: reportPath, atomically: true, encoding: .utf8)
                return 1
            }
            let identifier = "beacon-preview-" + UUID().uuidString
            defer {
                center.removePendingNotificationRequests(withIdentifiers: [identifier])
                center.removeDeliveredNotifications(withIdentifiers: [identifier])
            }
            NotificationScheduler().registerCategories()
            let task = TaskSnapshot(key: identifier, title: "Beacon notification preview", priority: 1)
            let content = UNMutableNotificationContent()
            content.title = NotificationCopy.title(for: task)
            content.categoryIdentifier = Scheduler.taskCategory
            content.threadIdentifier = identifier
            do {
                try await center.add(UNNotificationRequest(identifier: identifier, content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)))
                try await Task.sleep(for: .seconds(6))
                let delivered = await center.deliveredNotifications().contains { $0.request.identifier == identifier }
                try "Preview delivered: \(delivered). It will be removed after inspection.".write(toFile: reportPath, atomically: true, encoding: .utf8)
                try await Task.sleep(for: .seconds(35))
                try "Preview delivered: \(delivered). Temporary notification removed.".write(toFile: reportPath, atomically: true, encoding: .utf8)
                return delivered ? 0 : 1
            } catch {
                try? "Notification preview failed: \(error.localizedDescription)".write(toFile: reportPath, atomically: true, encoding: .utf8)
                return 1
            }
        }

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
            var passed = 0
            var failures: [String] = []
            func check(_ value: Bool, _ label: String) {
                if value { passed += 1; log("  ok    " + label) }
                else { failures.append(label); log("  FAIL  " + label) }
            }
            let store = ReminderStore()
            let marker = markerPrefix + UUID().uuidString
            var created: [String] = []
            // Cleanup is restricted to identifiers returned by this run's creates.
            // The ordinary app's preferences and notification queue are untouched.
            defer { for key in created { try? store.delete(key: key) } }
            log("Beacon integration check — " + marker)
            guard await store.requestAccess() == .granted else {
                log("FAIL: Reminders permission is required."); return 1
            }
            check(true, "Reminders access")
            func fetch(_ key: String) async throws -> TaskSnapshot {
                guard case let .ok(tasks) = await store.fetchActive(), let task = tasks.first(where: { $0.key == key }) else {
                    throw NSError(domain: "BeaconE2E", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test reminder missing from fresh fetch"])
                }
                return task
            }
            let now = Date()
            let due = now.addingTimeInterval(3 * 3600)
            do {
                let key = try store.create(title: marker + " timed", due: due, notes: "Sample notes", urgency: .high)
                created.append(key)
                let initial = try await fetch(key)
                check(initial.title == marker + " timed" && initial.notes == "Sample notes", "create title and notes round-trip")
                check(initial.hasTimeOfDay && abs((initial.due ?? .distantPast).timeIntervalSince(due)) < 1, "timed date round-trip")
                check(initial.urgency == .high, "urgency round-trip")

                try store.update(key: key, title: marker + " edited", due: due, notes: "Edited notes", listID: nil, recurrence: nil)
                let edited = try await fetch(key)
                check(edited.title == marker + " edited" && edited.notes == "Edited notes", "editing persists")
                check(edited.priority == initial.priority, "editing preserves unchanged priority")
                try store.update(key: key, title: edited.title, due: due, notes: edited.notes, listID: nil, recurrence: nil, urgency: .low)
                let low = try await fetch(key)
                check(low.urgency == .low, "changing urgency persists")

                let undatedKey = try store.create(title: marker + " someday", due: nil)
                created.append(undatedKey)
                let undated = try await fetch(undatedKey)
                check(undated.due == nil && undated.urgency == .none, "new Someday has no date and no urgency")
                check(Sections.bucket(undated, now: now, calendar: .current) == .someday, "undated reminder groups into Someday")
                let silent = Scheduler.plan(now: now, tasks: [undated], state: [:], settings: .default, calendar: .current)
                check(silent.notifications.isEmpty, "Someday creates neither task alerts nor a digest")

                let rule = Recurrence(frequency: .weekly, interval: 2, daysOfWeek: [3])
                let repeatKey = try store.create(title: marker + " repeating", due: due, recurrence: rule)
                created.append(repeatKey)
                let repeating = try await fetch(repeatKey)
                check(repeating.recurrence == rule && repeating.isRecurring, "repeat rule round-trip")
                try store.update(key: repeatKey, title: repeating.title, due: due, notes: "", listID: nil, recurrence: nil)
                let withoutRepeat = try await fetch(repeatKey)
                check(!withoutRepeat.isRecurring, "removing repeat persists")

                let target = now.addingTimeInterval(45 * 60)
                try store.setDue(target, key: key)
                let snoozed = try await fetch(key)
                check(abs((snoozed.due ?? .distantPast).timeIntervalSince(target)) < 1, "snooze date persists")
                try store.setCompleted(true, key: key)
                let completed = await store.fetchCompletedToday(now: Date())
                check(completed.contains { $0.key == key }, "completion appears in today's completed section")
                if case let .ok(active) = await store.fetchActive() {
                    check(!active.contains { $0.key == key }, "completion leaves active reminders")
                } else { check(false, "active fetch after completion") }
                try store.setCompleted(false, key: key)
                let restored = try await fetch(key)
                check(!restored.isCompleted, "undo completion restores reminder")

                try store.setDue(nil, key: key)
                let cleared = try await fetch(key)
                check(cleared.due == nil, "clearing a date returns to Someday")

                let samples = [initial, undated, repeating]
                let plan = Scheduler.plan(now: now, tasks: samples, state: [:], settings: .default, calendar: .current)
                check(plan.notifications.count <= Settings.default.slotBudget, "planner respects system budget")
                check(Set(plan.notifications.map(\.identifier)).count == plan.notifications.count, "notification identifiers are unique")
                check(!plan.notifications.contains { $0.taskKey == undatedKey }, "mixed plan excludes Someday alerts")
                let requests = plan.notifications.compactMap { NotificationScheduler.request(for: $0) }
                check(requests.count == plan.notifications.count && !requests.isEmpty, "scheduled reminders produce native notification requests")
                check(requests.allSatisfy { !$0.content.categoryIdentifier.isEmpty }, "notification action categories are present")
                check(Sections.groupByList(samples, now: now, calendar: .current).reduce(0) { $0 + $1.tasks.count } == samples.count, "list grouping retains every reminder")

                // Read the real Calendar adapter without requesting a new grant or writing events.
                let range = UpcomingEventFilter.range(now: now)
                switch try await CalendarStore().read(ranges: [range], refreshSources: true) {
                case let .loaded(calendars, events):
                    check(Set(events.map(\.id)).count == events.count, "Calendar read deduplicates occurrences")
                    check(events.allSatisfy { event in calendars.contains { $0.id == event.calendarID } }, "events reference available calendars")
                    let hidden = Set(calendars.map(\.id))
                    check(UpcomingEventFilter().events(events, now: now, hiddenCalendarIDs: hidden).isEmpty, "hiding calendars excludes their upcoming events")
                case .permissionNeeded, .denied:
                    log("  SKIP  Calendar integration — permission not granted")
                }
            } catch { check(false, error.localizedDescription) }
            log("Cleanup")
            for key in created {
                do { try store.delete(key: key) }
                catch { check(false, "cleanup failed for test reminder " + key) }
            }
            if case let .ok(remaining) = await store.fetchActive() {
                check(!remaining.contains { created.contains($0.key) }, "all test reminders removed")
            } else { check(false, "cleanup verification fetch") }
            log("\(passed) checks passed, \(failures.count) failed")
            log("Notification delivery, Siri audio, and remote provider sync require separate device verification.")
            return failures.isEmpty ? 0 : 1
        }
}
