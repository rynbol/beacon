import Foundation

/// An immutable view of one Apple Reminders item.
///
/// `ReminderStore` is the only place that converts `EKReminder` into this type.
/// Nothing downstream of it sees EventKit, which is what keeps `Scheduler` pure
/// and testable without entitlements, a device, or a populated Reminders database.
public struct TaskSnapshot: Sendable, Equatable, Identifiable {
    /// `EKCalendarItem.calendarItemIdentifier`. Device-local, which is fine:
    /// the sidecar that keys off it is device-local too (DESIGN.md §6).
    public let key: String
    public let title: String
    public let listName: String

    /// `nil` is an undated Someday reminder. It stays visible without alerts
    /// until the user chooses a date, including when captured through Siri.
    public let due: Date?

    /// `false` when the reminder is all-day, i.e. EventKit gave us date
    /// components with no hour/minute/second.
    public let hasTimeOfDay: Bool

    /// Recurring tasks never get a due-date write on snooze: that would
    /// re-anchor the whole series (DESIGN.md §5.3).
    public let isRecurring: Bool

    public let isCompleted: Bool
    public let completionDate: Date?

    public let priority: Int
    public var urgency: Urgency { Urgency(priority: priority) }

    public let notes: String
    public let listID: String

    /// The repeat rule, when Beacon's editor can express it. A reminder can
    /// carry a rule this app has no controls for, so `isRecurring` is the
    /// truth about whether it repeats, and this is the truth about whether the
    /// editor may touch it.
    public let recurrence: Recurrence?

    public var id: String { key }

    public init(
        key: String,
        title: String,
        listName: String = "",
        listID: String = "",
        due: Date? = nil,
        hasTimeOfDay: Bool = false,
        isRecurring: Bool = false,
        isCompleted: Bool = false,
        completionDate: Date? = nil,
        notes: String = "",
        recurrence: Recurrence? = nil,
        priority: Int = 0
    ) {
        self.priority = priority
        self.key = key
        self.title = title
        self.listName = listName
        self.listID = listID
        self.due = due
        self.hasTimeOfDay = hasTimeOfDay
        self.isRecurring = isRecurring
        self.isCompleted = isCompleted
        self.completionDate = completionDate
        self.notes = notes
        self.recurrence = recurrence
    }

    /// Deferred indefinitely: still on the list, deliberately not nagged about.
    ///
    /// Encoded as a due date far in the future rather than as a flag, because
    /// EventKit has no field Beacon could own — and a real date keeps the
    /// reminder meaningful in Apple Reminders, which is the whole point of
    /// keeping the tasks there.
    public func isSomeday(now: Date, horizon: TimeInterval) -> Bool {
        guard let due else { return true }
        return due.timeIntervalSince(now) > horizon
    }
}
