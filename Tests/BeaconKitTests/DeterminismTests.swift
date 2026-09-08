import Foundation
import XCTest
@testable import BeaconKit

/// The property the whole two-device design rests on.
///
/// v1 computed a past-due alert as `max(due, now)`, which made the plan a
/// function of the rebuild instant: every rebuild nudged the alert further out,
/// and the iPhone and the Mac — rebuilding seconds apart — produced different
/// plans while claiming to be deterministic. These tests pin the fix.
final class DeterminismTests: XCTestCase {

    private let settings = Settings.default
    private let calendar = Fixture.calendar

    func testTwoRebuildsSecondsApartProduceIdenticalPlans() {
        let tasks = [
            Fixture.task("a", due: Fixture.at(2026, 8, 20, 9, 0)),   // past due
            Fixture.task("b", due: nil),                              // undated
            Fixture.task("c", due: Fixture.at(2026, 8, 26, 18, 30)),  // future
        ]

        let early = Scheduler.plan(
            now: Fixture.at(2026, 8, 26, 10, 0, 4),
            tasks: tasks, state: [:], settings: settings, calendar: calendar
        )
        let late = Scheduler.plan(
            now: Fixture.at(2026, 8, 26, 10, 0, 11),
            tasks: tasks, state: [:], settings: settings, calendar: calendar
        )

        XCTAssertEqual(early, late)
        XCTAssertEqual(early.identifiers, late.identifiers)
    }

    func testPlanIsStableAcrossTheWholeGridWindow() {
        let tasks = Fixture.tasks(5)
        let start = Fixture.at(2026, 8, 26, 10, 0, 0)
        let reference = Scheduler.plan(
            now: start, tasks: tasks, state: [:], settings: settings, calendar: calendar
        )

        for second in stride(from: 1, to: 900, by: 37) {
            let later = Scheduler.plan(
                now: start.addingTimeInterval(TimeInterval(second)),
                tasks: tasks, state: [:], settings: settings, calendar: calendar
            )
            XCTAssertEqual(later, reference, "plan drifted \(second)s into the window")
        }
    }

    func testRepeatedRebuildsNeverPushAPastDueAlertAway() {
        let tasks = [Fixture.task("a", due: Fixture.at(2026, 8, 25, 9, 0))]
        let start = Fixture.at(2026, 8, 26, 10, 0, 0)

        var fires: Set<Date> = []
        for second in stride(from: 0, to: 880, by: 20) {
            let plan = Scheduler.plan(
                now: start.addingTimeInterval(TimeInterval(second)),
                tasks: tasks, state: [:], settings: settings, calendar: calendar
            )
            fires.formUnion(plan.oneShotFires.prefix(1))
        }

        // Forty-four rebuilds inside one window: the first alert must not have
        // moved even once.
        XCTAssertEqual(fires.count, 1)
        XCTAssertEqual(fires.first, Fixture.at(2026, 8, 26, 10, 15))
    }

    func testUndatedTasksStayInSomedayWithoutAlerts() {
        let plan = Scheduler.plan(
            now: Fixture.at(2026, 8, 26, 10, 0),
            tasks: [Fixture.task("a", due: nil)],
            state: [:], settings: settings, calendar: calendar
        )
        XCTAssertTrue(plan.notifications.isEmpty)
    }

    func testStableHashDoesNotVaryBetweenRuns() {
        XCTAssertEqual(StableHash.u64("beacon"), StableHash.u64("beacon"))
        XCTAssertNotEqual(StableHash.u64("a"), StableHash.u64("b"))
        // Pinned so a refactor cannot silently change tie-breaking.
        XCTAssertEqual(StableHash.u64(""), 0xcbf2_9ce4_8422_2325)
    }
}
