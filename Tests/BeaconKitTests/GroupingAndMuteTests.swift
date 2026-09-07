import Foundation
import XCTest
@testable import BeaconKit

final class ListGroupingTests: XCTestCase {

    private let calendar = Fixture.calendar
    private var now: Date { Fixture.at(2026, 8, 26, 14, 0) }

    private func task(_ key: String, list: String, due: Date? = nil, completed: Bool = false) -> TaskSnapshot {
        TaskSnapshot(
            key: key, title: "Task \(key)", listName: list,
            due: due, hasTimeOfDay: due != nil, isCompleted: completed
        )
    }

    func testTasksAreGatheredByListName() {
        let groups = Sections.groupByList([
            task("a", list: "Work"),
            task("b", list: "Home"),
            task("c", list: "Work"),
        ], now: now, calendar: calendar)

        XCTAssertEqual(groups.map(\.name), ["Home", "Work"])
        XCTAssertEqual(groups[1].tasks.map(\.key), ["a", "c"])
    }

    func testListsAreOrderedAlphabetically() {
        let groups = Sections.groupByList([
            task("a", list: "Zebra"), task("b", list: "apple"), task("c", list: "Mango"),
        ], now: now, calendar: calendar)
        XCTAssertEqual(groups.map(\.name), ["apple", "Mango", "Zebra"])
    }

    func testATaskWithNoListNameStillGetsAHeading() {
        let groups = Sections.groupByList([task("a", list: "")], now: now, calendar: calendar)
        XCTAssertEqual(groups.map(\.name), ["Reminders"])
    }

    func testCompletedTasksStayInTheirOwnTrailingGroup() {
        // Finishing something must not bury it back among the unfinished.
        let groups = Sections.groupByList([
            task("a", list: "Work"),
            task("b", list: "Work", completed: true),
        ], now: now, calendar: calendar)

        XCTAssertEqual(groups.map(\.name), ["Work", "Recently Completed"])
        XCTAssertEqual(groups[0].tasks.map(\.key), ["a"])
        XCTAssertEqual(groups[1].tasks.map(\.key), ["b"])
    }

    func testUndatedTasksSortAboveDatedOnesInsideAList() {
        let groups = Sections.groupByList([
            task("dated", list: "Work", due: Fixture.at(2026, 8, 27, 9, 0)),
            task("undated", list: "Work"),
        ], now: now, calendar: calendar)
        XCTAssertEqual(groups[0].tasks.map(\.key), ["undated", "dated"])
    }

    func testAnEmptyDatabaseProducesNoGroups() {
        XCTAssertTrue(Sections.groupByList([], now: now, calendar: calendar).isEmpty)
    }
}

final class MuteTests: XCTestCase {

    private let calendar = Fixture.calendar
    private var now: Date { Fixture.at(2026, 8, 26, 14, 0) }

    func testAMutedTaskGetsNoAlertsAtAll() {
        let tasks = [Fixture.task("loud", due: nil), Fixture.task("quiet", due: nil)]
        let plan = Scheduler.plan(
            now: now, tasks: tasks,
            state: ["quiet": TaskState(isMuted: true)],
            settings: .default, calendar: calendar
        )
        XCTAssertFalse(plan.notifications.contains { $0.taskKey == "quiet" })
        XCTAssertTrue(plan.notifications.contains { $0.taskKey == "loud" })
    }

    func testMutingEveryTaskLeavesNothingScheduled() {
        // Including the floor: a digest announcing tasks that will never alert
        // would be noise on its own.
        let plan = Scheduler.plan(
            now: now, tasks: [Fixture.task("a", due: nil)],
            state: ["a": TaskState(isMuted: true)],
            settings: .default, calendar: calendar
        )
        XCTAssertTrue(plan.notifications.isEmpty)
    }

    func testMutingDoesNotDisturbOtherTasksSchedules() {
        let tasks = (0..<4).map { Fixture.task("t\($0)", due: nil) }
        let before = Scheduler.plan(
            now: now, tasks: tasks, state: [:], settings: .default, calendar: calendar
        )
        let after = Scheduler.plan(
            now: now, tasks: tasks,
            state: ["t3": TaskState(isMuted: true)],
            settings: .default, calendar: calendar
        )
        XCTAssertEqual(before.notifications.count - after.notifications.count,
                       before.notifications.filter { $0.taskKey == "t3" }.count)
    }
}
