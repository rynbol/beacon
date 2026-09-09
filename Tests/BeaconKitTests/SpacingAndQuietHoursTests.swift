import Foundation
import XCTest
@testable import BeaconKit

final class SpacingTests: XCTestCase {

    private let settings = Settings.default
    private let calendar = Fixture.calendar

    func testSixSimultaneousTasksNeverCollide() {
        // The case that broke v1's bucket arithmetic: with a 5-minute bucket and
        // a 90-second step, the sixth task overflowed its own bucket and landed
        // on top of the next one.
        let due = Fixture.at(2026, 8, 26, 14, 0)
        let plan = Scheduler.plan(
            now: Fixture.at(2026, 8, 26, 10, 0),
            tasks: (0..<6).map { Fixture.task("t\($0)", due: due) },
            state: [:], settings: settings, calendar: calendar
        )

        let fires = plan.oneShotFires
        for (earlier, later) in zip(fires, fires.dropFirst()) {
            XCTAssertGreaterThanOrEqual(later.timeIntervalSince(earlier), settings.spacingSeconds)
        }
    }

    func testDensePileIsSeparatedAndReportsWhatItDropped() {
        let due = Fixture.at(2026, 8, 26, 14, 0)
        let plan = Scheduler.plan(
            now: Fixture.at(2026, 8, 26, 10, 0),
            tasks: (0..<40).map { Fixture.task("t\($0)", due: due) },
            state: [:], settings: settings, calendar: calendar
        )

        let fires = plan.oneShotFires
        for (earlier, later) in zip(fires, fires.dropFirst()) {
            XCTAssertGreaterThanOrEqual(later.timeIntervalSince(earlier), settings.spacingSeconds)
        }
        // Whatever the drift cap refused is named, so a bounded plan never
        // reads as full coverage.
        for key in plan.spacingDropped {
            XCTAssertFalse(plan.notifications.contains { $0.taskKey == key && $0.kind == .ladder })
        }
    }

    func testNothingDriftsFurtherThanTheCap() {
        let due = Fixture.at(2026, 8, 26, 14, 0)
        let rungs = (0..<25).map {
            Scheduler.LadderRung(
                taskKey: "t\($0)", title: "t", step: 0, fire: due,
                hash: UInt64($0)
            )
        }
        let (kept, dropped) = Scheduler.applySpacing(to: rungs, settings: settings)
        for rung in kept {
            XCTAssertLessThanOrEqual(rung.fire.timeIntervalSince(due), settings.maxDriftSeconds)
        }
        XCTAssertEqual(kept.count + dropped.count, rungs.count)
    }
}

final class QuietHoursTests: XCTestCase {

    private let settings = Settings.default
    private let calendar = Fixture.calendar

    func testLateEveningAlertsMoveToTheNextMorning() {
        let fire = FireGrid.applyQuietHours(
            to: Fixture.at(2026, 8, 26, 23, 30),
            calendar: calendar, startHour: 22, endHour: 8
        )
        XCTAssertEqual(fire, Fixture.at(2026, 8, 27, 8, 0))
    }

    func testSmallHoursAlertsMoveToTheMorningAlreadyUnderway() {
        let fire = FireGrid.applyQuietHours(
            to: Fixture.at(2026, 8, 26, 3, 0),
            calendar: calendar, startHour: 22, endHour: 8
        )
        XCTAssertEqual(fire, Fixture.at(2026, 8, 26, 8, 0))
    }

    func testDaytimeAlertsAreLeftAlone() {
        for hour in [8, 12, 17, 21] {
            let original = Fixture.at(2026, 8, 26, hour, 30)
            XCTAssertEqual(
                FireGrid.applyQuietHours(to: original, calendar: calendar, startHour: 22, endHour: 8),
                original,
                "hour \(hour) was moved but is not quiet"
            )
        }
    }

    func testExplicitRequestOutranksQuietHours() {
        // "Remind me in 15 minutes" typed at 23:00 has to mean 23:15. Deferring
        // it to the morning would silently overrule the user.
        let now = Fixture.at(2026, 8, 26, 23, 0)
        let plan = Scheduler.plan(
            now: now,
            tasks: [Fixture.task("a", due: Fixture.at(2026, 8, 26, 23, 15))],
            state: ["a": TaskState(explicitIntentAt: now)],
            settings: settings, calendar: calendar
        )
        XCTAssertEqual(plan.oneShotFires.first, Fixture.at(2026, 8, 26, 23, 15))
    }

    func testWithoutExplicitIntentALateAlertStillDefers() {
        let plan = Scheduler.plan(
            now: Fixture.at(2026, 8, 26, 23, 0),
            tasks: [Fixture.task("a", due: Fixture.at(2026, 8, 26, 23, 15))],
            state: [:], settings: settings, calendar: calendar
        )
        XCTAssertEqual(plan.oneShotFires.first, Fixture.at(2026, 8, 27, 8, 0))
    }
}
