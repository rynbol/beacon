import XCTest
@testable import BeaconKit

final class CompletedDayTests: XCTestCase {
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return result
    }
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
    func testLocalMidnightBoundsNotRolling24Hours() {
        let now = date(2026, 9, 8, 15)
        let midnight = date(2026, 9, 8)
        XCTAssertEqual(CompletedDay.range(now: now, calendar: calendar).start, midnight)
        XCTAssertTrue(CompletedDay.contains(midnight, now: now, calendar: calendar))
        XCTAssertTrue(CompletedDay.contains(now, now: now, calendar: calendar))
        XCTAssertFalse(CompletedDay.contains(midnight.addingTimeInterval(-1), now: now, calendar: calendar))
        XCTAssertFalse(CompletedDay.contains(now.addingTimeInterval(1), now: now, calendar: calendar))
        XCTAssertFalse(CompletedDay.contains(nil, now: now, calendar: calendar))
    }
    func testNewDayDropsPreviousDay() {
        let midnight = date(2027, 1, 1)
        XCTAssertEqual(CompletedDay.range(now: midnight, calendar: calendar).duration, 0)
        XCTAssertFalse(CompletedDay.contains(midnight.addingTimeInterval(-1), now: midnight, calendar: calendar))
        XCTAssertTrue(CompletedDay.contains(midnight, now: midnight, calendar: calendar))
    }
    func testDaylightSavingUsesLocalMidnight() {
        for (month, day, hours) in [(3, 8, 11), (11, 1, 13)] {
            let now = date(2026, month, day, 12)
            let range = CompletedDay.range(now: now, calendar: calendar)
            XCTAssertEqual(range.start, date(2026, month, day))
            XCTAssertEqual(range.duration, Double(hours * 3600))
        }
    }
}
