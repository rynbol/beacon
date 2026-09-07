import Foundation
import XCTest
@testable import BeaconKit

final class RebuildRegressionTests: XCTestCase {
    private let now = Fixture.at(2026, 8, 26, 10, 0)

    func testFutureTaskDoesNotGetPrematureDailyAlerts() {
        let due = now.addingTimeInterval(24 * 3600)
        let plan = Scheduler.plan(now: now, tasks: [Fixture.task("future", due: due)],
                                  state: [:], settings: .default, calendar: Fixture.calendar)
        XCTAssertTrue(plan.ofKind(.taskBeacon).isEmpty)
        XCTAssertEqual(plan.oneShotFires.first, due)
        XCTAssertTrue(plan.oneShotFires.allSatisfy { $0 >= due })
    }

    func testRecurringSnoozeHonorsSelectedDurationEvenIfLadderChanges() {
        let until = now.addingTimeInterval(4 * 3600)
        let plan = Scheduler.plan(now: now,
            tasks: [Fixture.task("repeat", due: now.addingTimeInterval(-3600), recurring: true)],
            state: ["repeat": TaskState(snoozeCount: 1, snoozeAnchor: now, snoozedUntil: until, explicitIntentAt: now)],
            settings: .default, calendar: Fixture.calendar)
        XCTAssertEqual(plan.oneShotFires.first, until)
        XCTAssertTrue(plan.ofKind(.taskBeacon).isEmpty)
    }

    func testNotificationSnoozeTextMatchesActionForEveryRung() {
        let plan = Scheduler.plan(now: now, tasks: [Fixture.task("a")],
            state: ["a": TaskState(snoozeCount: 2)], settings: .default, calendar: Fixture.calendar)
        XCTAssertEqual(Set(plan.ofKind(.ladder).map(\.body)), ["Snooze adds 1 hour."])
    }
}
