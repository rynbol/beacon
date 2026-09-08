import Foundation
import XCTest
@testable import BeaconKit

/// "Someday" is the one place the app deliberately stops nagging.
///
/// That makes it the one place where "no task can be silent" and the user's own
/// wishes disagree, so the rules are pinned here: a Someday task stays visible,
/// stays in Apple Reminders as a real dated task, and takes no scheduler slot.
final class SomedayTests: XCTestCase {

    private let calendar = Fixture.calendar
    private var now: Date { Fixture.at(2026, 8, 26, 14, 0) }
    private var horizon: TimeInterval { Settings.default.somedayHorizon }

    private func someday(_ key: String) -> TaskSnapshot {
        Fixture.task(key, due: Settings.somedayDate(from: now, calendar: calendar))
    }

    // MARK: - The date itself

    func testTheSomedayDateIsFarEnoughOutToCountAsSomeday() {
        let task = someday("a")
        XCTAssertTrue(task.isSomeday(now: now, horizon: horizon))
    }

    func testTheSomedayDateIsARealDateReminderCanHold() {
        // Encoded as a date rather than a flag, because EventKit has no field
        // Beacon could own — and the reminder has to stay meaningful in Apple
        // Reminders on its own.
        let date = Settings.somedayDate(from: now, calendar: calendar)
        XCTAssertEqual(calendar.component(.year, from: date), 2036)
        XCTAssertEqual(calendar.component(.hour, from: date), 9)
        XCTAssertNotNil(DueComponents.make(from: date, calendar: calendar))
    }

    func testOrdinaryFutureTasksAreNotSomeday() {
        for due in [
            Fixture.at(2026, 8, 27, 9, 0),
            Fixture.at(2026, 12, 1, 9, 0),
            Fixture.at(2027, 6, 1, 9, 0),
        ] {
            XCTAssertFalse(
                Fixture.task("a", due: due).isSomeday(now: now, horizon: horizon),
                "\(due) should not read as Someday"
            )
        }
    }

    func testUndatedIsSomedayButPastDueIsNot() {
        XCTAssertTrue(Fixture.task("a", due: nil).isSomeday(now: now, horizon: horizon))
        XCTAssertFalse(
            Fixture.task("a", due: Fixture.at(2020, 1, 1, 9, 0)).isSomeday(now: now, horizon: horizon)
        )
    }

    // MARK: - Presentation

    func testSomedayTasksGetTheirOwnSection() {
        XCTAssertEqual(Sections.bucket(someday("a"), now: now, calendar: calendar), .someday)
    }

    func testSomedaySitsBelowEveryDatedSectionAndAboveCompleted() {
        let groups = Sections.group([
            someday("far"),
            Fixture.task("today", due: now),
            Fixture.task("done", completed: true),
            Fixture.task("later", due: Fixture.at(2026, 12, 1, 9, 0)),
        ], now: now, calendar: calendar)

        XCTAssertEqual(groups.map(\.section), [.today, .later, .someday, .recentlyCompleted])
    }

    func testTheRowReadsSomedayRatherThanADistantDate() {
        // A date ten years out is noise. What the user chose was "not now".
        XCTAssertEqual(
            Sections.relativeText(for: someday("a"), now: now, calendar: calendar),
            "Someday"
        )
    }

    func testGroupingByListAlsoSeparatesSomeday() {
        let groups = Sections.groupByList([
            TaskSnapshot(key: "a", title: "a", listName: "Work", due: now),
            TaskSnapshot(
                key: "b", title: "b", listName: "Work",
                due: Settings.somedayDate(from: now, calendar: calendar), hasTimeOfDay: true
            ),
        ], now: now, calendar: calendar)

        XCTAssertEqual(groups.map(\.name), ["Work", "Someday"])
    }

    // MARK: - Scheduling

    func testASomedayTaskTakesNoAlertsAtAll() {
        let plan = Scheduler.plan(
            now: now, tasks: [someday("a"), Fixture.task("b", due: now)],
            state: [:], settings: .default, calendar: calendar
        )
        XCTAssertFalse(plan.notifications.contains { $0.taskKey == "a" })
        XCTAssertTrue(plan.notifications.contains { $0.taskKey == "b" })
    }

    func testASomedayTaskTakesNoBeaconEvenWhenSlotsAreFree() {
        // With one task and fifty slots the beacon tier would happily take it,
        // and would then nag every morning about work the user deferred.
        let plan = Scheduler.plan(
            now: now, tasks: [someday("a")],
            state: [:], settings: .default, calendar: calendar
        )
        XCTAssertEqual(plan.ofKind(.taskBeacon).count, 0)
        XCTAssertEqual(plan.ofKind(.ladder).count, 0)
    }

    func testSomedayOnlyDoesNotScheduleADigest() {
        // The digest is the one thing that still speaks for them, so the list
        // itself is never forgotten.
        let plan = Scheduler.plan(
            now: now, tasks: [someday("a"), someday("b")],
            state: [:], settings: .default, calendar: calendar
        )
        XCTAssertTrue(plan.notifications.isEmpty)
        XCTAssertTrue(plan.beaconOverflow.isEmpty)
    }

    func testDeferringATaskFreesTheSlotItWasUsing() {
        let tasks = (0..<3).map { Fixture.task("t\($0)", due: now) }
        let before = Scheduler.plan(
            now: now, tasks: tasks, state: [:], settings: .default, calendar: calendar
        )
        var deferred = tasks
        deferred[2] = Fixture.task("t2", due: Settings.somedayDate(from: now, calendar: calendar))
        let after = Scheduler.plan(
            now: now, tasks: deferred, state: [:], settings: .default, calendar: calendar
        )
        XCTAssertLessThan(after.notifications.count, before.notifications.count)
        XCTAssertFalse(after.notifications.contains { $0.taskKey == "t2" })
    }
}
