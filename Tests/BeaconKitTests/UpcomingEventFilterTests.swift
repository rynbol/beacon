import XCTest
@testable import BeaconKit

final class UpcomingEventFilterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private func event(_ title: String, start: Date? = nil, end: Date? = nil) -> CalendarEventSnapshot {
        CalendarEventSnapshot(identifier: title, calendarID: "work", title: title,
                              start: start ?? now, end: end ?? now.addingTimeInterval(3600))
    }
    func testCaseInsensitiveIncludesAndExcludesWithExclusionPriority() {
        let filter = UpcomingEventFilter(include: ["Interview", "REVIEW"], exclude: ["cancelled"])
        XCTAssertTrue(filter.matches(event("ENGINEERING INTERVIEW")))
        XCTAssertTrue(filter.matches(event("Design review")))
        XCTAssertFalse(filter.matches(event("Interview CANCELLED")))
        XCTAssertFalse(filter.matches(event("Lunch")))
        XCTAssertTrue(UpcomingEventFilter().matches(event("Lunch")))
        XCTAssertFalse(UpcomingEventFilter(exclude: ["lunch"]).matches(event("LUNCH")))
    }
    func testLabelsTrimAndDeduplicateWithoutCaseSensitivity() {
        XCTAssertEqual(UpcomingEventFilter.labels([" Interview ", "interview", "", "  ", "Review"]), ["Interview", "Review"])
    }
    func testRollingSevenDayWindowAndHiddenCalendars() {
        let end = UpcomingEventFilter.range(now: now).end
        let samples = [event("Past", start: now.addingTimeInterval(-3600), end: now),
                       event("Now"), event("Last", start: end.addingTimeInterval(-1), end: end),
                       event("Outside", start: end, end: end.addingTimeInterval(3600))]
        XCTAssertEqual(UpcomingEventFilter().events(samples, now: now).map(\.title), ["Now", "Last"])
        XCTAssertTrue(UpcomingEventFilter().events(samples, now: now, hiddenCalendarIDs: ["work"]).isEmpty)
    }
    func testRollingWindowUsesCalendarDaysAcrossDST() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 12))!
        let end = UpcomingEventFilter.range(now: start, calendar: calendar).end
        XCTAssertEqual(calendar.component(.hour, from: end), 12)
        XCTAssertEqual(calendar.component(.day, from: end), 14)
        XCTAssertEqual(end.timeIntervalSince(start), 7 * 86400 - 3600)
    }
}
