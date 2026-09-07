import Foundation
import XCTest
@testable import BeaconKit

final class FireGridTests: XCTestCase {

    private let calendar = Fixture.calendar

    func testNextBoundaryIsAlwaysStrictlyInTheFuture() {
        for minute in 0..<60 {
            for second in [0, 1, 30, 59] {
                let now = Fixture.at(2026, 8, 26, 10, minute, second)
                let next = FireGrid.nextBoundary(after: now, calendar: calendar, gridSeconds: 900)
                XCTAssertGreaterThan(next, now)
                XCTAssertLessThanOrEqual(next.timeIntervalSince(now), 900)
            }
        }
    }

    func testBoundariesLandOnQuarterHours() {
        XCTAssertEqual(
            FireGrid.nextBoundary(after: Fixture.at(2026, 8, 26, 10, 0, 4),
                                  calendar: calendar, gridSeconds: 900),
            Fixture.at(2026, 8, 26, 10, 15)
        )
        XCTAssertEqual(
            FireGrid.nextBoundary(after: Fixture.at(2026, 8, 26, 10, 14, 59),
                                  calendar: calendar, gridSeconds: 900),
            Fixture.at(2026, 8, 26, 10, 15)
        )
        // Exactly on a boundary moves to the next one: a request scheduled for
        // this instant is already in the past by the time it is added.
        XCTAssertEqual(
            FireGrid.nextBoundary(after: Fixture.at(2026, 8, 26, 10, 15, 0),
                                  calendar: calendar, gridSeconds: 900),
            Fixture.at(2026, 8, 26, 10, 30)
        )
    }

    func testLastWindowOfTheDayRollsIntoTomorrow() {
        XCTAssertEqual(
            FireGrid.nextBoundary(after: Fixture.at(2026, 8, 26, 23, 50),
                                  calendar: calendar, gridSeconds: 900),
            Fixture.at(2026, 8, 27, 0, 0)
        )
    }

    func testSurvivesBackwardDaylightSavingShift() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        var components = DateComponents()
        components.year = 2026; components.month = 11; components.day = 1
        components.hour = 1; components.minute = 30
        let now = calendar.date(from: components)!

        let next = FireGrid.nextBoundary(after: now, calendar: calendar, gridSeconds: 900)
        XCTAssertGreaterThan(next, now)
    }

    func testQuietWindowMembershipHandlesTheMidnightCrossing() {
        XCTAssertTrue(FireGrid.isQuiet(hour: 23, startHour: 22, endHour: 8))
        XCTAssertTrue(FireGrid.isQuiet(hour: 0, startHour: 22, endHour: 8))
        XCTAssertTrue(FireGrid.isQuiet(hour: 7, startHour: 22, endHour: 8))
        XCTAssertFalse(FireGrid.isQuiet(hour: 8, startHour: 22, endHour: 8))
        XCTAssertFalse(FireGrid.isQuiet(hour: 21, startHour: 22, endHour: 8))
        // A window that does not cross midnight still works.
        XCTAssertTrue(FireGrid.isQuiet(hour: 13, startHour: 12, endHour: 14))
        XCTAssertFalse(FireGrid.isQuiet(hour: 15, startHour: 12, endHour: 14))
    }
}
