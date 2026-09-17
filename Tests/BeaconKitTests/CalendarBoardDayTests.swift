import XCTest
@testable import BeaconKit

final class CalendarBoardDayTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return value
    }
    private func date(_ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour))!
    }
    private func event(_ id: String, _ start: Date, _ end: Date, allDay: Bool = false) -> CalendarEventSnapshot {
        CalendarEventSnapshot(identifier: id, calendarID: "work", title: id, start: start, end: end, isAllDay: allDay)
    }
    func testEmptyColumnsAndFullUpcomingCoverageAcrossDST() {
        let days = CalendarBoardDay.days(events: [], range: UpcomingEventFilter.range(now: date(7, 12), calendar: calendar), calendar: calendar)
        XCTAssertEqual(days.map { calendar.component(.day, from: $0.date) }, Array(7...14))
        XCTAssertTrue(days.allSatisfy { $0.events.isEmpty })
        XCTAssertEqual(days[2].date.timeIntervalSince(days[1].date), 23 * 3600)
    }
    func testAllDayFirstThenChronologicalWithStableTies() {
        let values = [event("late", date(7, 17), date(7, 18)),
                      event("b", date(7, 13), date(7, 14)),
                      event("a", date(7, 13), date(7, 14)),
                      event("holiday", date(7), date(8), allDay: true)]
        let days = CalendarBoardDay.days(events: values, range: DateInterval(start: date(7, 12), end: date(8)), calendar: calendar)
        XCTAssertEqual(days[0].events.map(\.identifier), ["holiday", "a", "b", "late"])
    }
    func testOvernightAndExclusiveMidnightEndAndPastEvents() {
        let values = [event("overnight", date(7, 23), date(8, 2)),
                      event("holiday", date(7), date(9), allDay: true),
                      event("ended", date(7, 9), date(7, 12)),
                      event("instant", date(9), date(9))]
        let days = CalendarBoardDay.days(events: values, range: DateInterval(start: date(7, 12), end: date(10)), calendar: calendar)
        XCTAssertEqual(days[0].events.map(\.identifier), ["holiday", "overnight"])
        XCTAssertEqual(days[1].events.map(\.identifier), ["holiday", "overnight"])
        XCTAssertEqual(days[2].events.map(\.identifier), ["instant"])
    }
}
