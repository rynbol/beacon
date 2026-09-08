import XCTest
@testable import BeaconKit

final class CalendarFormattingTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return value
    }
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
    private func event(start: Date, end: Date, allDay: Bool = false) -> CalendarEventSnapshot {
        CalendarEventSnapshot(identifier: "test", calendarID: "work", title: "Test", start: start, end: end, isAllDay: allDay)
    }
    func testAllDayDSTTransitionDoesNotDisplayAnExtraDate() {
        let day = event(start: date(2026, 3, 8), end: date(2026, 3, 9), allDay: true)
        XCTAssertEqual(CalendarEventFormatting.timeRange(day, calendar: calendar, locale: Locale(identifier: "en_US")), "All day")
    }
    func testMultiDayAllDayRangeExcludesFinalMidnight() {
        let trip = event(start: date(2026, 9, 7), end: date(2026, 9, 10), allDay: true)
        let text = CalendarEventFormatting.timeRange(trip, calendar: calendar, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(text.contains("7"))
        XCTAssertTrue(text.contains("9"))
        XCTAssertFalse(text.contains("10"))
        XCTAssertTrue(text.hasPrefix("All day"))
    }
    func testOvernightRangeNamesBothDatesAndYearsWhenNeeded() {
        let overnight = event(start: date(2026, 12, 31, 23, 30), end: date(2027, 1, 1, 0, 30))
        let text = CalendarEventFormatting.timeRange(overnight, calendar: calendar, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(text.contains("Dec"))
        XCTAssertTrue(text.contains("Jan"))
        XCTAssertTrue(text.contains("2026"))
        XCTAssertTrue(text.contains("2027"))
    }
    func testTimeRangeRespectsTwentyFourHourLocale() {
        let meeting = event(start: date(2026, 9, 7, 14), end: date(2026, 9, 7, 15))
        let text = CalendarEventFormatting.timeRange(meeting, calendar: calendar, locale: Locale(identifier: "en_GB"))
        XCTAssertTrue(text.contains("14:00"))
        XCTAssertTrue(text.contains("15:00"))
        XCTAssertFalse(text.contains("PM"))
    }
}
