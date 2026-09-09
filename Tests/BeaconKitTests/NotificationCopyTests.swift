import XCTest
import UserNotifications
@testable import BeaconKit

final class NotificationCopyTests: XCTestCase {
    func testOneFlagFollowsTheTitleForEachUrgency() {
        let suffixes: [Urgency: String] = [.none: "", .low: " ⚐", .medium: " ⚑", .high: " 🚩"]
        for urgency in Urgency.allCases {
            let task = TaskSnapshot(key: "a", title: "Prepare", listName: "Work", priority: urgency.priority)
            XCTAssertEqual(NotificationCopy.title(for: task), "Prepare" + suffixes[urgency]!)
        }
    }

    func testTitlePreservesUnicodeAndDoesNotAddListOrNotes() {
        let task = TaskSnapshot(key: "a", title: "Call José 🌱", listName: "Work", notes: "Private notes", priority: 1)
        XCTAssertEqual(NotificationCopy.title(for: task), "Call José 🌱 🚩")
    }

    func testUrgencyChangesTitleWithoutChangingDeliveryTimes() {
        let now = Fixture.at(2026, 8, 26, 10, 0)
        var reference: [PlannedTrigger]?
        for urgency in Urgency.allCases {
            let task = TaskSnapshot(key: "a", title: "Prepare", listName: "Work", due: now.addingTimeInterval(-3600), priority: urgency.priority)
            let plan = Scheduler.plan(now: now, tasks: [task], state: [:], settings: .default, calendar: Fixture.calendar)
            let triggers = plan.notifications.map(\.trigger)
            if let reference { XCTAssertEqual(triggers, reference) } else { reference = triggers }
            let named = plan.notifications.filter { $0.taskKey != nil }
            XCTAssertFalse(named.isEmpty)
            XCTAssertTrue(named.allSatisfy { $0.title == NotificationCopy.title(for: task) && $0.subtitle.isEmpty })
            XCTAssertTrue(named.allSatisfy { $0.body.isEmpty })
        }
    }

    @MainActor
    func testNativeRequestCarriesFlagWithoutExtraSubtitle() async throws {
        let task = TaskSnapshot(key: "task-a", title: "Prepare", priority: 1)
        let planned = PlannedNotification(identifier: "copy-test", taskKey: task.key, kind: .ladder,
            trigger: .oneShot(Date().addingTimeInterval(3600)), title: NotificationCopy.title(for: task),
            body: "",
            categoryIdentifier: Scheduler.taskCategory, threadIdentifier: task.key)
        let request = try XCTUnwrap(NotificationScheduler.request(for: planned))
        XCTAssertEqual(request.content.title, "Prepare 🚩")
        XCTAssertTrue(request.content.subtitle.isEmpty)
        XCTAssertTrue(request.content.body.isEmpty)
        XCTAssertEqual(request.content.categoryIdentifier, Scheduler.taskCategory)
        XCTAssertEqual(request.content.threadIdentifier, task.key)
        XCTAssertEqual(request.content.userInfo["taskKey"] as? String, task.key)
        XCTAssertNotNil(request.content.sound)
        XCTAssertEqual(request.content.interruptionLevel, .timeSensitive)
    }
    @MainActor
    func testSnoozeActionOpensChooserAndDoneRetainsItsRouting() async throws {
        let category = try XCTUnwrap(NotificationScheduler.categories().first { $0.identifier == Scheduler.taskCategory })
        XCTAssertEqual(category.actions.map(\.title), ["Snooze…", "Done"])
        XCTAssertEqual(category.actions[0].identifier, NotificationScheduler.Action.chooseSnooze.rawValue)
        XCTAssertTrue(category.actions[0].options.contains(.foreground))
        XCTAssertEqual(category.actions[1].identifier, NotificationScheduler.Action.complete.rawValue)
        XCTAssertFalse(category.actions[1].options.contains(.foreground))
    }

}
