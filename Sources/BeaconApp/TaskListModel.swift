import Foundation
import Observation
import BeaconKit

/// Holds what the window shows, and owns the two rules that matter on the data
/// path: a fetch that could not be trusted never becomes an empty list, and a
/// plan is only ever applied whole.
@MainActor
@Observable
final class TaskListModel {
    static let shared = TaskListModel()

    // Presentation
    private(set) var groups: [TaskGroup] = []
    private(set) var access: ReminderAccess = .notDetermined
    private(set) var refusal: FetchRefusal?
    private(set) var writeError: String?
    private(set) var lastRefresh: Date?
    private(set) var plan: Plan?

    // Notifications
    private(set) var authorization: NotificationScheduler.Authorization = .notAsked
    private(set) var pendingCount = 0
    private(set) var scheduleError: String?
    /// The master switch. Off means Beacon keeps the list but stops alerting.
    private(set) var alertsEnabled = true

    var notificationsAuthorized: Bool { authorization == .granted }
    /// True when Beacon is capable of alerting and allowed to.
    var isAlerting: Bool { alertsEnabled && notificationsAuthorized }

    // Preferences
    private(set) var accent: Accent = .ocean
    private(set) var settings = Settings.default
    private(set) var collapsed: Set<Int> = []
    private(set) var grouping: Grouping = .time
    private(set) var listGroups: [ListGroup] = []
    private(set) var mutedKeys: Set<String> = []
    private(set) var collapsedLists: Set<String> = []

    var lists: [(id: String, title: String)] = []
    var selectedListID: String?

    private let store = ReminderStore()
    private let sidecar = Sidecar()
    private let notifier = NotificationScheduler()
    private let defaults = (ProcessInfo.processInfo.arguments.contains("--preview") || Bundle.main.bundleIdentifier == "dev.dylan.beacon.v2.preview")
        ? UserDefaults(suiteName: "dev.dylan.beacon.v2.design-preview")! : .standard
    private var watcher: Task<Void, Never>?

    var taskCount: Int { groups.reduce(0) { $0 + $1.tasks.count } }

    // MARK: - Lifecycle

    let isPreview = (ProcessInfo.processInfo.arguments.contains("--preview") || Bundle.main.bundleIdentifier == "dev.dylan.beacon.v2.preview")
    private var startup: Task<Void, Never>?
    private var refreshing = false
    private var refreshAgain = false
    private var refreshWaiters: [CheckedContinuation<Void, Never>] = []

    func start() async {
        if let startup { await startup.value; return }
        let task = Task { await initialize() }
        startup = task
        await task.value
    }

    private func initialize() async {
        if isPreview { loadPreview(); return }
        loadPreferences()
        notifier.registerCategories()

        // Ask on first launch. Waiting for the user to find a settings screen
        // meant the app scheduled nothing and said nothing about why.
        authorization = await notifier.authorization
        if authorization == .notAsked, alertsEnabled {
            _ = await notifier.requestAuthorization()
            authorization = await notifier.authorization
        }

        access = await store.requestAccess()
        lists = store.writableLists
        if selectedListID == nil { selectedListID = store.defaultListID }

        await refresh()
        watchForExternalChanges()
    }

    func refresh() async {
        guard !isPreview else { return }
        if refreshing {
            refreshAgain = true
            await withCheckedContinuation { refreshWaiters.append($0) }
            return
        }
        refreshing = true
        repeat {
            refreshAgain = false
            await refreshOnce()
        } while refreshAgain
        refreshing = false
        let waiters = refreshWaiters
        refreshWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private func refreshOnce() async {
        access = store.access
        // Re-read every time: the user can grant or revoke this in System
        // Settings while the app is running, and a stale answer means either
        // silence or pointless work.
        authorization = await notifier.authorization
        let outcome = await store.fetchActive()

        switch outcome {
        case let .ok(active):
            refusal = nil
            lists = store.writableLists
            let now = Date()
            let completed = await store.fetchCompletedToday(now: now)
            groups = Sections.group(active + completed, now: now, calendar: .current)
            listGroups = Sections.groupByList(active + completed, now: now, calendar: .current)

            await sidecar.prune(keepingKeys: Set(active.map(\.key)))
            let state = await sidecar.state
            mutedKeys = Set(state.filter(\.value.isMuted).keys)
            sidecarCounts = state.mapValues(\.snoozeCount)
            let newPlan = Scheduler.plan(
                now: now, tasks: active, state: state,
                settings: settings, calendar: .current
            )
            plan = newPlan
            lastRefresh = now

            if isAlerting {
                await notifier.apply(newPlan)
                pendingCount = await notifier.pendingCount()
                scheduleError = notifier.lastError
            } else {
                // Nothing may stay armed once alerting is off, or the app keeps
                // firing after the user told it to stop.
                notifier.removeAll()
                pendingCount = 0
                scheduleError = nil
            }

        case let .refused(reason):
            // Keep whatever is on screen, and leave the pending notifications
            // alone. EventKit reports a denial, an account that has not mounted
            // and a genuinely empty database identically, so acting on this
            // would erase a real list and cancel every alert with it.
            refusal = reason
        }
    }

    // MARK: - Writing

    func create(
        title: String, due: Date?, notes: String,
        listID: String?, recurrence: Recurrence?, urgency: Urgency = .none
    ) async {
        await write {
            let key = try store.create(
                title: title, due: due,
                notes: notes.isEmpty ? nil : notes,
                listID: listID ?? selectedListID,
                recurrence: recurrence, urgency: urgency
            )
            if due != nil { await sidecar.recordExplicitIntent(key: key, now: .now) }
        }
    }

    func update(
        _ task: TaskSnapshot, title: String, due: Date?, notes: String,
        listID: String?, recurrence: Recurrence?, urgency: Urgency? = nil
    ) async {
        await write {
            try store.update(
                key: task.key, title: title, due: due,
                notes: notes, listID: listID, recurrence: recurrence,
                preserveRecurrence: task.isRecurring && task.recurrence == nil,
                urgency: urgency
            )
            if due != task.due, due != nil {
                await sidecar.recordExplicitIntent(key: task.key, now: .now)
            }
        }
    }

    func delete(_ task: TaskSnapshot) async {
        await write {
            try store.delete(key: task.key)
            await sidecar.clear(key: task.key)
        }
    }

    func toggleCompleted(_ task: TaskSnapshot) async {
        await write {
            try store.setCompleted(!task.isCompleted, key: task.key)
            if !task.isCompleted { await sidecar.clear(key: task.key) }
        }
    }

    /// A notification completion is idempotent, unlike the UI's toggle.
    func complete(_ task: TaskSnapshot) async {
        guard !task.isCompleted else { return }
        await write {
            try store.setCompleted(true, key: task.key)
            await sidecar.clear(key: task.key)
        }
    }

    /// Defers a task and moves it one rung down the ladder.
    func snooze(_ task: TaskSnapshot, by interval: TimeInterval) async {
        await write {
            let target = Date().addingTimeInterval(interval)
            if task.isRecurring {
                // A due-date write on a repeating reminder re-anchors every
                // future occurrence, so the deferral is held here instead.
                await sidecar.recordSnooze(key: task.key, anchor: Date(), now: .now, until: target)
            } else {
                try store.setDue(target, key: task.key)
                await sidecar.recordSnooze(key: task.key, anchor: nil, now: .now)
            }
        }
    }

    /// The snooze menu for a row: the task's own next rungs, so what the menu
    /// offers and what the scheduler does can never disagree.
    func snoozeOptions(for task: TaskSnapshot) -> [(label: String, interval: TimeInterval)] {
        let rung = sidecarCounts[task.key] ?? 0
        var seen = Set<TimeInterval>()
        return (0..<3).compactMap { step in
            let interval = settings.interval(forSnoozeCount: rung + step)
            guard seen.insert(interval).inserted else { return nil }
            return (IntervalText.short(interval), interval)
        }
    }

    private var sidecarCounts: [String: Int] = [:]

    private func write(_ body: () async throws -> Void) async {
        guard !isPreview else {
            writeError = "This is a design preview. Open Beacon normally to save reminders."
            return
        }
        do {
            try await body()
            writeError = nil
            await refresh()
        } catch {
            writeError = describe(error)
        }
    }

    func dismissWriteError() { writeError = nil }

    /// Finds a task the notification layer named.
    func task(withKey key: String) -> TaskSnapshot? {
        groups.lazy.flatMap(\.tasks).first { $0.key == key }
    }

    /// Snoozes by the task's own current rung, optionally skipping ahead.
    func snoozeOneRung(_ task: TaskSnapshot, extra: Int) async {
        let rung = sidecarCounts[task.key] ?? 0
        await snooze(task, by: settings.interval(forSnoozeCount: rung + extra))
    }

    // MARK: - Notifications

    func enableNotifications() async {
        guard !isPreview else { return }
        if authorization == .notAsked {
            _ = await notifier.requestAuthorization()
        }
        authorization = await notifier.authorization
        await refresh()
    }

    /// The master switch for alerts.
    func setAlertsEnabled(_ enabled: Bool) async {
        guard !isPreview else { return }
        alertsEnabled = enabled
        defaults.set(enabled, forKey: "alertsEnabled")
        if enabled, authorization == .notAsked {
            _ = await notifier.requestAuthorization()
            authorization = await notifier.authorization
        }
        if !enabled {
            notifier.removeAll()
            pendingCount = 0
            scheduleError = nil
        }
        await refresh()
    }

    // MARK: - Muting

    func isMuted(_ task: TaskSnapshot) -> Bool { mutedKeys.contains(task.key) }

    func toggleMuted(_ task: TaskSnapshot) async {
        guard !isPreview else { return }
        let muted = !mutedKeys.contains(task.key)
        await sidecar.setMuted(muted, key: task.key)
        await refresh()
    }

    // MARK: - Grouping

    func setGrouping(_ value: Grouping) {
        grouping = value
        defaults.set(value.rawValue, forKey: "grouping")
    }

    // MARK: - Preferences

    func setAccent(_ value: Accent) {
        accent = value
        defaults.set(value.rawValue, forKey: "accent")
    }

    func adjustLadder(at index: Int, by direction: Int) {
        guard settings.ladder.indices.contains(index) else { return }
        let steps: [TimeInterval] = [
            5 * 60, 10 * 60, 15 * 60, 30 * 60, 3_600, 2 * 3_600, 4 * 3_600,
            8 * 3_600, 12 * 3_600, 24 * 3_600, 48 * 3_600, 72 * 3_600,
        ]
        let current = settings.ladder[index]
        let position = steps.firstIndex { $0 >= current } ?? 0
        let next = min(max(position + direction, 0), steps.count - 1)
        settings.ladder[index] = steps[next]
        saveLadder()
        Task { await refresh() }
    }

    func setQuietHours(start: Int, end: Int) {
        settings.quietStartHour = start
        settings.quietEndHour = end
        defaults.set(start, forKey: "quietStart")
        defaults.set(end, forKey: "quietEnd")
        Task { await refresh() }
    }

    private func saveLadder() {
        defaults.set(settings.ladder, forKey: "ladder")
    }

    private func loadPreferences() {
        if let raw = defaults.string(forKey: "accent"), let value = Accent(rawValue: raw) {
            accent = value
        }
        if let ladder = defaults.array(forKey: "ladder") as? [TimeInterval], !ladder.isEmpty {
            settings.ladder = ladder
        }
        if defaults.object(forKey: "quietStart") != nil {
            settings.quietStartHour = defaults.integer(forKey: "quietStart")
            settings.quietEndHour = defaults.integer(forKey: "quietEnd")
        }
        collapsed = Set(defaults.array(forKey: "collapsed") as? [Int] ?? [])
        if let raw = defaults.string(forKey: "grouping"), let value = Grouping(rawValue: raw) {
            grouping = value
        }
        if defaults.object(forKey: "alertsEnabled") != nil {
            alertsEnabled = defaults.bool(forKey: "alertsEnabled")
        }
        collapsedLists = Set(defaults.array(forKey: "collapsedLists") as? [String] ?? [])
        selectedListID = defaults.string(forKey: "defaultList")
    }

    // MARK: - Collapsing

    /// Today can never be collapsed. Hiding what is due now is exactly the
    /// failure this app exists to prevent.
    func canCollapse(_ section: TaskSection) -> Bool { section != .today }

    func isCollapsed(_ section: TaskSection) -> Bool {
        collapsed.contains(section.rawValue)
    }

    func toggleCollapsed(_ section: TaskSection) {
        guard canCollapse(section) else { return }
        if collapsed.contains(section.rawValue) {
            collapsed.remove(section.rawValue)
        } else {
            collapsed.insert(section.rawValue)
        }
        defaults.set(Array(collapsed), forKey: "collapsed")
    }

    /// List sections collapse by name, since a list has no fixed index.
    func isListCollapsed(_ name: String) -> Bool { collapsedLists.contains(name) }

    func toggleListCollapsed(_ name: String) {
        if collapsedLists.contains(name) {
            collapsedLists.remove(name)
        } else {
            collapsedLists.insert(name)
        }
        defaults.set(Array(collapsedLists), forKey: "collapsedLists")
    }

    // MARK: - Change watching

    private func watchForExternalChanges() {
        guard watcher == nil else { return }
        watcher = Task { [weak self] in
            let changes = NotificationCenter.default.notifications(named: .EKEventStoreChanged)
            for await _ in changes {
                // The notification carries no payload, so nothing can be applied
                // incrementally: reading the whole database again is the only
                // correct response. Debounced, because iCloud delivers these in
                // bursts while it syncs.
                try? await Task.sleep(for: .milliseconds(500))
                await self?.refresh()
            }
        }
    }

    func stop() {
        watcher?.cancel()
        watcher = nil
    }

    private func loadPreview() {
        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let tasks = [
            TaskSnapshot(key: "preview-1", title: "Send the photos to Mom", listName: "Personal", due: now.addingTimeInterval(-3600), hasTimeOfDay: true, priority: 1),
            TaskSnapshot(key: "preview-2", title: "Book a table for Friday", listName: "Personal", notes: "Somewhere with a patio.", priority: 9),
            TaskSnapshot(key: "preview-3", title: "Take a proper screen break", listName: "Everyday", due: now.addingTimeInterval(3600), hasTimeOfDay: true, isRecurring: true, priority: 5),
            TaskSnapshot(key: "preview-4", title: "Water the plants", listName: "Home", due: tomorrow, hasTimeOfDay: true, isRecurring: true),
            TaskSnapshot(key: "preview-5", title: "Pick up the library books", listName: "Personal", due: tomorrow.addingTimeInterval(7200), hasTimeOfDay: true),
            TaskSnapshot(key: "preview-6", title: "Plan a weekend by the coast", listName: "Personal", due: Settings.somedayDate(from: now, calendar: .current)),
            TaskSnapshot(key: "preview-7", title: "Send the project update", listName: "Work", isCompleted: true, completionDate: now)
        ]
        groups = Sections.group(tasks, now: now, calendar: .current)
        access = .granted
        alertsEnabled = false
        lastRefresh = now
    }

    private func describe(_ error: Error) -> String {
        guard let error = error as? ReminderStore.WriteError else {
            return error.localizedDescription
        }
        switch error {
        case .notAuthorized: return "Beacon does not have access to your reminders."
        case .noList: return "No writable reminder list is available."
        case .unknownTask: return "That task is no longer in Reminders."
        case .invalidDate: return "That date does not exist."
        case .recurrenceNeedsDueDate: return "A repeating task needs a time."
        case let .eventKit(message): return message
        }
    }
}

extension FetchRefusal {
    var headline: String {
        switch self {
        case .notAuthorized: return "Beacon cannot read your reminders"
        case .noCalendars: return "No reminder lists are available"
        case .fetchFailed: return "Beacon could not read your reminders"
        }
    }

    var detail: String {
        switch self {
        case .notAuthorized:
            return "Grant access under System Settings > Privacy & Security > Reminders."
        case .noCalendars:
            return "Your account may still be loading. This usually clears on its own."
        case .fetchFailed:
            return "The last list Beacon read is still shown. Try again in a moment."
        }
    }
}
