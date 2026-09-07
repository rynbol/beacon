import Foundation
import XCTest
@testable import BeaconKit

final class LadderTests: XCTestCase {

    private let settings = Settings.default
    private let calendar = Fixture.calendar
    private var now: Date { Fixture.at(2026, 8, 26, 10, 0) }

    func testIntervalsClimbWithTheSnoozeCountAndThenHold() {
        XCTAssertEqual(settings.interval(forSnoozeCount: 0), 15 * 60)
        XCTAssertEqual(settings.interval(forSnoozeCount: 3), 2 * 3600)
        XCTAssertEqual(settings.interval(forSnoozeCount: 6), 24 * 3600)
        // Past the last rung it holds rather than running off the end.
        XCTAssertEqual(settings.interval(forSnoozeCount: 99), 24 * 3600)
        XCTAssertEqual(settings.interval(forSnoozeCount: -5), 15 * 60)
    }

    func testAnEditedLadderChangesBehaviourWithNoSchedulerChange() {
        var custom = Settings.default
        custom.ladder = [5 * 60, 45 * 60]

        let plan = Scheduler.plan(
            now: now, tasks: [Fixture.task("a", due: nil)],
            state: [:], settings: custom, calendar: calendar
        )
        let fires = plan.oneShotFires
        XCTAssertGreaterThanOrEqual(fires.count, 2)
        XCTAssertEqual(fires[1].timeIntervalSince(fires[0]), 5 * 60)
    }

    func testASnoozedTaskStartsFromItsOwnRung() {
        let plan = Scheduler.plan(
            now: now, tasks: [Fixture.task("a", due: nil)],
            state: ["a": TaskState(snoozeCount: 3)],
            settings: settings, calendar: calendar
        )
        let fires = plan.oneShotFires
        // Rung 3 is two hours, so the second alert is two hours after the first.
        XCTAssertEqual(fires[1].timeIntervalSince(fires[0]), 2 * 3600)
    }

    func testRungsPerTaskAreCapped() {
        let plan = Scheduler.plan(
            now: now, tasks: [Fixture.task("a", due: nil)],
            state: [:], settings: settings, calendar: calendar
        )
        XCTAssertLessThanOrEqual(plan.ofKind(.ladder).count, settings.maxLadderPerTask)
    }

    func testEveryTaskIsHeardOnceBeforeAnyTaskIsHeardTwice() {
        // Strict time order would let one noisy task eat the whole window.
        var tight = Settings.default
        tight.slotBudget = 1 + 3 + 3   // digest + beacons + exactly three rungs

        let plan = Scheduler.plan(
            now: now, tasks: Fixture.tasks(3),
            state: [:], settings: tight, calendar: calendar
        )
        let heard = Set(plan.ofKind(.ladder).compactMap(\.taskKey))
        XCTAssertEqual(heard.count, 3)
    }

    func testBodyNamesTheIntervalTheSnoozeButtonWillApply() {
        let plan = Scheduler.plan(
            now: now, tasks: [Fixture.task("a", due: nil)],
            state: ["a": TaskState(snoozeCount: 2)],
            settings: settings, calendar: calendar
        )
        XCTAssertEqual(plan.ofKind(.ladder).first?.body, "Snooze adds 1 hour.")
    }

    func testIntervalNamesReadAsPlainLanguage() {
        XCTAssertEqual(IntervalText.short(60), "1 minute")
        XCTAssertEqual(IntervalText.short(15 * 60), "15 minutes")
        XCTAssertEqual(IntervalText.short(3600), "1 hour")
        XCTAssertEqual(IntervalText.short(4 * 3600), "4 hours")
        XCTAssertEqual(IntervalText.short(86_400), "1 day")
        XCTAssertEqual(IntervalText.short(3 * 86_400), "3 days")
    }

    func testARecurringSnoozeDefersWithoutTouchingTheDueDate() {
        // Writing a due date on a recurring reminder re-anchors the entire
        // series, which the user never asked for (DESIGN.md §5.3).
        let anchor = Fixture.at(2026, 8, 26, 10, 0)
        let plan = Scheduler.plan(
            now: now,
            tasks: [Fixture.task("a", due: Fixture.at(2026, 8, 20, 9, 0), recurring: true)],
            state: ["a": TaskState(snoozeCount: 0, snoozeAnchor: anchor)],
            settings: settings, calendar: calendar
        )
        XCTAssertEqual(plan.oneShotFires.first, anchor.addingTimeInterval(15 * 60))
    }

    func testAStaleAnchorFallsBackToTheGridInsteadOfFiringInThePast() {
        let plan = Scheduler.plan(
            now: now,
            tasks: [Fixture.task("a", due: nil, recurring: true)],
            state: ["a": TaskState(snoozeCount: 0, snoozeAnchor: Fixture.at(2026, 8, 20, 9, 0))],
            settings: settings, calendar: calendar
        )
        XCTAssertEqual(plan.oneShotFires.first, Fixture.at(2026, 8, 26, 10, 15))
    }
}
