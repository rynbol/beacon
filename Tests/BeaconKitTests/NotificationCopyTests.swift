import XCTest
import UserNotifications
@testable import BeaconKit

final class NotificationCopyTests: XCTestCase {
    func testUrgencyAndListContextForEveryLevel() {
        for urgency in Urgency.allCases {
            let task = TaskSnapshot(key: "a", title: "Prepare", listName: "Work", priority: urgency.priority)
            XCTAssertEqual(NotificationCopy.subtitle(for: task),
                urgency == .none ? "Work" : "\(urgency.title) urgency · Work")
        }
    }

    func testEmptyAndLongListNamesStayCompact() {
        XCTAssertEqual(NotificationCopy.subtitle(for: TaskSnapshot(key: "a", title: "a")), "")
        XCTAssertEqual(NotificationCopy.subtitle(for: TaskSnapshot(key: "a", title: "a", listName: " \n ", priority: 1)), "High urgency")
        XCTAssertEqual(NotificationCopy.subtitle(for: TaskSnapshot(key: "a", title: "a", listName: " Work\n  Projects ")), "Work Projects")
        let subtitle = NotificationCopy.subtitle(for: TaskSnapshot(key: "a", title: "a", listName: String(repeating: "🌱", count: 70)))
        XCTAssertEqual(subtitle.count, 48)
        XCTAssertTrue(subtitle.hasSuffix("…"))
    }

    func testUrgencyChangesCopyWithoutChangingDeliveryTimes() {
        let now = Fixture.at(2026, 8, 26, 10, 0)
        var reference: [PlannedTrigger]?
        for urgency in Urgency.allCases {
            let task = TaskSnapshot(key: "a", title: "Prepare", listName: "Work", due: now.addingTimeInterval(-3600), priority: urgency.priority)
            let plan = Scheduler.plan(now: now, tasks: [task], state: [:], settings: .default, calendar: Fixture.calendar)
            let triggers = plan.notifications.map(\.trigger)
            if let reference { XCTAssertEqual(triggers, reference) } else { reference = triggers }
            let named = plan.notifications.filter { $0.taskKey != nil }
            XCTAssertFalse(named.isEmpty)
            XCTAssertTrue(named.allSatisfy { $0.title == task.title && $0.subtitle == NotificationCopy.subtitle(for: task) })
            XCTAssertTrue(named.allSatisfy { $0.body.hasSuffix("Snooze for 15 minutes.") })
        }
    }

    func testCopyDoesNotExposeNotesOrInventDateContext() {
        let task = TaskSnapshot(key: "a", title: "Prepare", listName: "Work", notes: "Private meeting notes", priority: 1)
        XCTAssertFalse(NotificationCopy.subtitle(for: task).contains(task.notes))
        XCTAssertEqual(NotificationCopy.body(urgency: .high, snooze: 3600, followUp: false), "Give this one a moment. Snooze for 1 hour.")
        XCTAssertEqual(NotificationCopy.body(urgency: .low, snooze: 900, followUp: false), "When you have a moment. Snooze for 15 minutes.")
        XCTAssertEqual(NotificationCopy.body(urgency: .high, snooze: 900, followUp: true), "Still on your list. Snooze for 15 minutes.")
    }

    @MainActor
    func testNativeRequestCarriesContextAndActionRouting() async throws {
        let planned = PlannedNotification(identifier: "copy-test", taskKey: "task-a", kind: .ladder,
            trigger: .oneShot(Date().addingTimeInterval(3600)), title: "Prepare",
            subtitle: "High urgency · Work", body: "Give this one a moment. Snooze for 15 minutes.",
            categoryIdentifier: Scheduler.taskCategory, threadIdentifier: "task-a")
        let request = try XCTUnwrap(NotificationScheduler.request(for: planned))
        XCTAssertEqual(request.content.title, planned.title)
        XCTAssertEqual(request.content.subtitle, planned.subtitle)
        XCTAssertEqual(request.content.body, planned.body)
        XCTAssertEqual(request.content.categoryIdentifier, Scheduler.taskCategory)
        XCTAssertEqual(request.content.threadIdentifier, "task-a")
        XCTAssertEqual(request.content.userInfo["taskKey"] as? String, "task-a")
        XCTAssertNotNil(request.content.sound)
        XCTAssertEqual(request.content.interruptionLevel, .timeSensitive)
    }
}
