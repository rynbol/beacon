import Foundation
import XCTest
@testable import BeaconKit

/// The floor is the product promise. v1 spent it on 32 per-task beacons, which
/// an ordinary Reminders database exhausts — a single grocery list could push
/// dozens of tasks into permanent silence. v2 spends one slot on a digest that
/// holds at any task count, and treats named beacons as a quality layer.
final class FloorAndBudgetTests: XCTestCase {

    private let settings = Settings.default
    private let calendar = Fixture.calendar
    private var now: Date { Fixture.at(2026, 8, 26, 10, 0) }

    func testGoalOneHoldsAtEveryTaskCount() {
        for count in [1, 5, 30, 31, 70, 200] {
            let plan = Scheduler.plan(
                now: now, tasks: Fixture.tasks(count),
                state: [:], settings: settings, calendar: calendar
            )
            XCTAssertEqual(plan.ofKind(.digest).count, 1, "no floor at \(count) tasks")
            XCTAssertLessThanOrEqual(plan.notifications.count, settings.slotBudget)
        }
    }

    func testTheSeventyTaskDatabaseThatBrokeV1() {
        let plan = Scheduler.plan(
            now: now, tasks: Fixture.tasks(70),
            state: [:], settings: settings, calendar: calendar
        )
        XCTAssertEqual(plan.ofKind(.digest).count, 1)
        XCTAssertEqual(plan.ofKind(.taskBeacon).count, settings.maxTaskBeacons)
        XCTAssertLessThanOrEqual(plan.notifications.count, settings.slotBudget)
        // Tasks past the beacon tier are recorded, not silently forgotten.
        XCTAssertEqual(plan.beaconOverflow.count, 40)
    }

    func testEmptyDatabaseSchedulesNothing() {
        XCTAssertTrue(Scheduler.plan(
            now: now, tasks: [], state: [:], settings: settings, calendar: calendar
        ).notifications.isEmpty)
        XCTAssertTrue(Scheduler.plan(
            now: now, tasks: [Fixture.task("a", completed: true)],
            state: [:], settings: settings, calendar: calendar
        ).notifications.isEmpty)
    }

    func testIdentifiersAreUnique() {
        let plan = Scheduler.plan(
            now: now, tasks: Fixture.tasks(40),
            state: [:], settings: settings, calendar: calendar
        )
        XCTAssertEqual(plan.identifiers.count, plan.notifications.count)
    }

    func testBeaconsRepeatDailyAndAreSpreadTwoMinutesApart() {
        let plan = Scheduler.plan(
            now: now, tasks: Fixture.tasks(4),
            state: [:], settings: settings, calendar: calendar
        )
        var minutes: [Int] = []
        for beacon in plan.ofKind(.taskBeacon) {
            guard case let .repeatingDaily(hour, minute) = beacon.trigger else {
                XCTFail("a beacon must repeat daily, or it is not a floor")
                continue
            }
            minutes.append(hour * 60 + minute)
        }
        XCTAssertEqual(minutes.sorted(), [9 * 60 + 2, 9 * 60 + 4, 9 * 60 + 6, 9 * 60 + 8])
    }

    func testBeaconTierRollsOverTheHourRatherThanColliding() {
        let plan = Scheduler.plan(
            now: now, tasks: Fixture.tasks(30),
            state: [:], settings: settings, calendar: calendar
        )
        var slots: Set<Int> = []
        for beacon in plan.ofKind(.taskBeacon) {
            if case let .repeatingDaily(hour, minute) = beacon.trigger {
                slots.insert(hour * 60 + minute)
            }
        }
        XCTAssertEqual(slots.count, 30, "every beacon needs its own minute")
        XCTAssertEqual(slots.max(), 10 * 60)
    }

    func testOnlyDueTasksGetDailyBeacons() {
        let tasks = [
            Fixture.task("far", due: Fixture.at(2026, 9, 30, 12, 0)),
            Fixture.task("soon", due: now.addingTimeInterval(-60)),
        ]
        let plan = Scheduler.plan(
            now: now, tasks: tasks, state: [:], settings: settings, calendar: calendar
        )
        XCTAssertEqual(plan.ofKind(.taskBeacon).map(\.taskKey), ["soon"])
    }
}
