import Foundation
@testable import BeaconKit

/// Fixed calendar and clock for every test: a plan must never depend on the
/// machine it is computed on.
enum Fixture {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    /// A local wall-clock instant in the fixture time zone.
    static func at(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int, _ minute: Int, _ second: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return calendar.date(from: components)!
    }

    static func task(
        _ key: String,
        title: String? = nil,
        due: Date? = nil,
        recurring: Bool = false,
        completed: Bool = false
    ) -> TaskSnapshot {
        TaskSnapshot(
            key: key,
            title: title ?? "Task \(key)",
            listName: "Inbox",
            due: due,
            hasTimeOfDay: due != nil,
            isRecurring: recurring,
            isCompleted: completed
        )
    }

    static func tasks(_ count: Int, due: Date? = nil) -> [TaskSnapshot] {
        (0..<count).map { task("t\($0)", due: due) }
    }
}

extension Plan {
    func ofKind(_ kind: PlannedNotification.Kind) -> [PlannedNotification] {
        notifications.filter { $0.kind == kind }
    }

    var oneShotFires: [Date] {
        notifications.compactMap {
            if case let .oneShot(date) = $0.trigger { return date }
            return nil
        }.sorted()
    }
}
