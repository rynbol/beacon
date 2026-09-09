import Foundation
import EventKit

/// Why a fetch produced no usable task list.
///
/// This distinction is the whole point of the type. `fetchReminders` hands back
/// an optional array with no error channel, so a revoked permission, an
/// unmounted iCloud account and a genuinely empty database all arrive looking
/// identical — as "no tasks". Acting on that would cancel every pending
/// notification and silence the app permanently.
public enum FetchRefusal: String, Sendable, Equatable {
    case notAuthorized
    case noCalendars
    case fetchFailed
}

/// The result of one read. A caller cannot reach the tasks without first
/// handling the refusal, so an unproven fetch cannot be mistaken for an empty
/// database.
public enum FetchOutcome: Sendable, Equatable {
    case ok([TaskSnapshot])
    case refused(FetchRefusal)
}

public enum ReminderAccess: Sendable, Equatable {
    case granted
    case denied
    case notDetermined
}

/// The reminder read/write boundary for EventKit.
///
/// Everything downstream sees `TaskSnapshot` values, which is what keeps the
/// scheduler pure and lets the entire scheduling rulebook be tested without a
/// device, an account, or a populated Reminders database.
@MainActor
public final class ReminderStore {

    private let store = EKEventStore()

    public init() {}

    public var access: ReminderAccess {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    @discardableResult
    public func requestAccess() async -> ReminderAccess {
        guard access == .notDetermined else { return access }
        _ = try? await store.requestFullAccessToReminders()
        return access
    }

    /// Reads every incomplete reminder across every list.
    ///
    /// List membership is a label, never a filter: a task the user cannot see
    /// is a task the user will forget.
    public func fetchActive() async -> FetchOutcome {
        guard access == .granted else { return .refused(.notAuthorized) }

        let calendars = store.calendars(for: .reminder)
        guard !calendars.isEmpty else { return .refused(.noCalendars) }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: calendars
        )
        guard let snapshots = await fetch(matching: predicate) else {
            return .refused(.fetchFailed)
        }
        return .ok(snapshots)
    }

    /// Completed since local midnight, rather than within a rolling duration.
    public func fetchCompletedToday(now: Date, calendar: Calendar = .current) async -> [TaskSnapshot] {
        let range = CompletedDay.range(now: now, calendar: calendar)
        return await fetchRecentlyCompleted(within: range.duration, now: now)
            .filter { CompletedDay.contains($0.completionDate, now: now, calendar: calendar) }
    }

    /// Reminders completed inside the trailing window, for the section that
    /// lets a finished task be visible for a while.
    public func fetchRecentlyCompleted(within window: TimeInterval, now: Date) async -> [TaskSnapshot] {
        guard access == .granted else { return [] }
        let calendars = store.calendars(for: .reminder)
        guard !calendars.isEmpty else { return [] }

        let predicate = store.predicateForCompletedReminders(
            withCompletionDateStarting: now.addingTimeInterval(-window),
            ending: now,
            calendars: calendars
        )
        return await fetch(matching: predicate) ?? []
    }

    /// Converts inside the callback rather than handing `EKReminder` objects
    /// across the boundary: they are neither `Sendable` nor safe to touch off
    /// the queue EventKit delivered them on.
    private func fetch(matching predicate: NSPredicate) async -> [TaskSnapshot]? {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders?.map(Self.snapshot))
            }
        }
    }

    // MARK: - Writing

    public enum WriteError: Error, Sendable {
        case notAuthorized
        case noList
        case unknownTask
        case invalidDate
        case recurrenceNeedsDueDate
        case eventKit(String)
    }

    /// Lists the user can write to, for the picker.
    public var writableLists: [(id: String, title: String)] {
        store.calendars(for: .reminder)
            .filter(\.allowsContentModifications)
            .map { ($0.calendarIdentifier, $0.title) }
    }

    public var defaultListID: String? {
        store.defaultCalendarForNewReminders()?.calendarIdentifier
    }

    /// Creates a reminder and returns its identifier.
    @discardableResult
    public func create(
        title: String, due: Date?, notes: String? = nil,
        listID: String? = nil, recurrence: Recurrence? = nil, urgency: Urgency = .none
    ) throws -> String {
        guard access == .granted else { throw WriteError.notAuthorized }

        let calendar = listID.flatMap { store.calendar(withIdentifier: $0) }
            ?? store.defaultCalendarForNewReminders()
        guard let calendar, calendar.allowsContentModifications else { throw WriteError.noList }

        let reminder = EKReminder(eventStore: store)
        reminder.calendar = calendar
        reminder.priority = urgency.priority
        reminder.title = title
        if let notes, !notes.isEmpty { reminder.notes = notes }
        if let due { try Self.applyDue(due, to: reminder) }
        if let recurrence {
            // EventKit refuses a repeating reminder that has no due date.
            guard due != nil else { throw WriteError.recurrenceNeedsDueDate }
            reminder.recurrenceRules = [Self.rule(from: recurrence)]
        }

        do {
            try store.save(reminder, commit: true)
        } catch {
            throw WriteError.eventKit(error.localizedDescription)
        }
        return reminder.calendarItemIdentifier
    }

    /// Applies every field of the editor in one save.
    ///
    /// Saving field by field would leave a half-written reminder behind if any
    /// step threw, and would sync each change separately.
    public func update(
        key: String,
        title: String,
        due: Date?,
        notes: String,
        listID: String?,
        recurrence: Recurrence?,
        preserveRecurrence: Bool = false,
        urgency: Urgency? = nil
    ) throws {
        guard access == .granted else { throw WriteError.notAuthorized }
        guard let reminder = store.calendarItem(withIdentifier: key) as? EKReminder else {
            throw WriteError.unknownTask
        }

        reminder.title = title
        reminder.notes = notes.isEmpty ? nil : notes
        if let urgency { reminder.priority = urgency.priority }

        if let listID,
           let calendar = store.calendar(withIdentifier: listID),
           calendar.allowsContentModifications,
           calendar.calendarIdentifier != reminder.calendar?.calendarIdentifier {
            reminder.calendar = calendar
        }

        if let due {
            if Self.resolveDue(reminder.dueDateComponents) != due {
                try Self.applyDue(due, to: reminder)
            }
        } else if recurrence == nil && !preserveRecurrence {
            reminder.dueDateComponents = nil
            reminder.startDateComponents = nil
        } else {
            throw WriteError.recurrenceNeedsDueDate
        }

        if preserveRecurrence {
            // A title/notes edit must not erase an unsupported Apple rule.
        } else if let recurrence {
            reminder.recurrenceRules = [Self.rule(from: recurrence)]
        } else if reminder.hasRecurrenceRules {
            for rule in reminder.recurrenceRules ?? [] { reminder.removeRecurrenceRule(rule) }
        }

        do {
            try store.save(reminder, commit: true)
        } catch {
            throw WriteError.eventKit(error.localizedDescription)
        }
    }

    public func delete(key: String) throws {
        guard access == .granted else { throw WriteError.notAuthorized }
        guard let reminder = store.calendarItem(withIdentifier: key) as? EKReminder else {
            throw WriteError.unknownTask
        }
        do {
            try store.remove(reminder, commit: true)
        } catch {
            throw WriteError.eventKit(error.localizedDescription)
        }
    }

    public func setCompleted(_ completed: Bool, key: String) throws {
        guard access == .granted else { throw WriteError.notAuthorized }
        guard let reminder = store.calendarItem(withIdentifier: key) as? EKReminder else {
            throw WriteError.unknownTask
        }
        // A recurring reminder is deliberately not looped forward here. Marking
        // one complete makes the Reminders daemon advance the series itself and
        // file the completion under a new item, so the original comes back
        // incomplete with a later due date. Driving that loop is its own
        // milestone, gated behind an on-device check.
        reminder.isCompleted = completed
        do {
            try store.save(reminder, commit: true)
        } catch {
            throw WriteError.eventKit(error.localizedDescription)
        }
    }

    /// The one place a due date is ever written.
    public func setDue(_ date: Date?, key: String) throws {
        guard access == .granted else { throw WriteError.notAuthorized }
        guard let reminder = store.calendarItem(withIdentifier: key) as? EKReminder else {
            throw WriteError.unknownTask
        }
        if let date {
            try Self.applyDue(date, to: reminder)
        } else {
            reminder.dueDateComponents = nil
            reminder.startDateComponents = nil
        }
        do {
            try store.save(reminder, commit: true)
        } catch {
            throw WriteError.eventKit(error.localizedDescription)
        }
    }

    private nonisolated static func applyDue(_ date: Date, to reminder: EKReminder) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let components = DueComponents.make(from: date, calendar: calendar) else {
            throw WriteError.invalidDate
        }
        // Both dates, always: iOS rejects a due date with no start date, and
        // writing only one produces a reminder that is invalid on the phone.
        reminder.startDateComponents = components
        reminder.dueDateComponents = components
    }

    // MARK: - Conversion

    nonisolated static func snapshot(_ reminder: EKReminder) -> TaskSnapshot {
        TaskSnapshot(
            key: reminder.calendarItemIdentifier,
            title: reminder.title ?? "Untitled",
            listName: reminder.calendar?.title ?? "",
            listID: reminder.calendar?.calendarIdentifier ?? "",
            due: resolveDue(reminder.dueDateComponents),
            hasTimeOfDay: reminder.dueDateComponents?.hour != nil,
            isRecurring: reminder.hasRecurrenceRules,
            isCompleted: reminder.isCompleted,
            completionDate: reminder.completionDate,
            notes: reminder.notes ?? "",
            recurrence: reminder.recurrenceRules?.first.flatMap(recurrence),
            priority: reminder.priority
        )
    }

    /// Reads an EventKit rule, or returns nil when it uses a shape the editor
    /// has no controls for. Showing a rule the editor cannot round-trip would
    /// let a save quietly rewrite it into something simpler.
    nonisolated static func recurrence(from rule: EKRecurrenceRule) -> Recurrence? {
        let frequency: Recurrence.Frequency
        switch rule.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        @unknown default: return nil
        }

        // Positional rules such as "the last weekday of the month" have no
        // representation here.
        guard rule.setPositions?.isEmpty ?? true,
              rule.daysOfTheMonth?.isEmpty ?? true,
              rule.monthsOfTheYear?.isEmpty ?? true,
              rule.weeksOfTheYear?.isEmpty ?? true,
              rule.daysOfTheYear?.isEmpty ?? true
        else { return nil }

        var days: Set<Int> = []
        for day in rule.daysOfTheWeek ?? [] {
            guard day.weekNumber == 0 else { return nil }
            days.insert(day.dayOfTheWeek.rawValue)
        }

        let end: Recurrence.End
        if let recurrenceEnd = rule.recurrenceEnd {
            if let date = recurrenceEnd.endDate {
                end = .on(date)
            } else if recurrenceEnd.occurrenceCount > 0 {
                end = .after(recurrenceEnd.occurrenceCount)
            } else {
                end = .never
            }
        } else {
            end = .never
        }

        return Recurrence(
            frequency: frequency, interval: rule.interval, daysOfWeek: days, end: end
        )
    }

    /// Builds an EventKit rule. `EKRecurrenceRule` is immutable, so a change
    /// always means a fresh rule rather than an edit.
    nonisolated static func rule(from recurrence: Recurrence) -> EKRecurrenceRule {
        let frequency: EKRecurrenceFrequency
        switch recurrence.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        }

        let days: [EKRecurrenceDayOfWeek]? = recurrence.daysOfWeek.isEmpty
            ? nil
            : recurrence.daysOfWeek.sorted().compactMap { value in
                EKWeekday(rawValue: value).map { EKRecurrenceDayOfWeek($0) }
            }

        let end: EKRecurrenceEnd?
        switch recurrence.end {
        case .never: end = nil
        case let .on(date): end = EKRecurrenceEnd(end: date)
        case let .after(count): end = EKRecurrenceEnd(occurrenceCount: count)
        }

        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: max(1, recurrence.interval),
            daysOfTheWeek: days,
            daysOfTheMonth: nil, monthsOfTheYear: nil,
            weeksOfTheYear: nil, daysOfTheYear: nil,
            setPositions: nil, end: end
        )
    }

    /// Resolves EventKit's date components into an instant.
    ///
    /// Components with no time zone are floating: they mean the same wall-clock
    /// time wherever the user happens to be, so they resolve against the local
    /// zone rather than being pinned to one.
    nonisolated static func resolveDue(_ components: DateComponents?) -> Date? {
        guard let components else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        if let timeZone = components.timeZone { calendar.timeZone = timeZone }
        return calendar.date(from: components)
    }
}
