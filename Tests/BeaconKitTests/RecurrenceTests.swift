import Foundation
import XCTest
@testable import BeaconKit

final class RecurrenceTests: XCTestCase {

    private let calendar = Fixture.calendar

    // MARK: - Sentences

    func testSentenceReadsAsPlainEnglish() {
        let cases: [(Recurrence, String)] = [
            (Recurrence(frequency: .daily, interval: 1), "Repeats every day."),
            (Recurrence(frequency: .daily, interval: 3), "Repeats every 3 days."),
            (Recurrence(frequency: .weekly, interval: 2, daysOfWeek: [3]),
             "Repeats every 2 weeks on Tuesday."),
            (Recurrence(frequency: .weekly, interval: 1, daysOfWeek: [2, 4]),
             "Repeats every week on Monday and Wednesday."),
            (Recurrence(frequency: .weekly, interval: 1, daysOfWeek: [2, 4, 6]),
             "Repeats every week on Monday, Wednesday, and Friday."),
            (Recurrence(frequency: .monthly, interval: 1), "Repeats every month."),
        ]
        for (rule, expected) in cases {
            XCTAssertEqual(rule.sentence(calendar: calendar), expected)
        }
    }

    func testSentenceStatesWhenTheRepeatStops() {
        XCTAssertEqual(
            Recurrence(frequency: .daily, interval: 1, end: .after(5)).sentence(calendar: calendar),
            "Repeats every day, 5 times."
        )
        XCTAssertEqual(
            Recurrence(frequency: .daily, interval: 1, end: .on(Fixture.at(2026, 12, 25, 9, 0)))
                .sentence(calendar: calendar),
            "Repeats every day, until 25 December 2026."
        )
    }

    // MARK: - Projection

    func testDailyProjection() {
        let dates = Recurrence(frequency: .daily, interval: 1)
            .nextOccurrences(after: Fixture.at(2026, 8, 26, 9, 0), count: 3, calendar: calendar)
        XCTAssertEqual(dates, [
            Fixture.at(2026, 8, 27, 9, 0),
            Fixture.at(2026, 8, 28, 9, 0),
            Fixture.at(2026, 8, 29, 9, 0),
        ])
    }

    func testEveryTwoWeeksOnTuesdayMatchesTheAppItCopies() {
        // The exact rule the reference app puts in its own screenshot, so the
        // preview can be compared against a known-good result.
        let rule = Recurrence(frequency: .weekly, interval: 2, daysOfWeek: [3])
        let dates = rule.nextOccurrences(
            after: Fixture.at(2026, 8, 11, 10, 0), count: 3, calendar: calendar
        )
        XCTAssertEqual(dates, [
            Fixture.at(2026, 8, 25, 10, 0),
            Fixture.at(2026, 9, 8, 10, 0),
            Fixture.at(2026, 9, 22, 10, 0),
        ])
    }

    func testWeeklyWithSeveralDaysHitsEachOne() {
        let rule = Recurrence(frequency: .weekly, interval: 1, daysOfWeek: [2, 4, 6])
        let dates = rule.nextOccurrences(
            after: Fixture.at(2026, 8, 26, 9, 0), count: 4, calendar: calendar
        )
        // 26 Aug 2026 is a Wednesday, so Friday comes next.
        XCTAssertEqual(dates, [
            Fixture.at(2026, 8, 28, 9, 0),
            Fixture.at(2026, 8, 31, 9, 0),
            Fixture.at(2026, 9, 2, 9, 0),
            Fixture.at(2026, 9, 4, 9, 0),
        ])
    }

    func testMonthlyKeepsTheDayOfMonth() {
        let dates = Recurrence(frequency: .monthly, interval: 1)
            .nextOccurrences(after: Fixture.at(2026, 1, 15, 9, 0), count: 3, calendar: calendar)
        XCTAssertEqual(dates.map { calendar.component(.day, from: $0) }, [15, 15, 15])
    }

    func testProjectionStopsAtAnEndDate() {
        let rule = Recurrence(frequency: .daily, interval: 1, end: .on(Fixture.at(2026, 8, 28, 9, 0)))
        let dates = rule.nextOccurrences(
            after: Fixture.at(2026, 8, 26, 9, 0), count: 10, calendar: calendar
        )
        XCTAssertEqual(dates.count, 2)
    }

    func testProjectionStopsAtAnOccurrenceCount() {
        let rule = Recurrence(frequency: .daily, interval: 1, end: .after(4))
        XCTAssertEqual(
            rule.nextOccurrences(after: Fixture.at(2026, 8, 26, 9, 0), count: 10, calendar: calendar).count,
            4
        )
    }

    func testAnIntervalIsNeverZeroOrNegative() {
        // A zero interval would make the projection loop forever.
        XCTAssertEqual(Recurrence(frequency: .daily, interval: 0).interval, 1)
        XCTAssertEqual(Recurrence(frequency: .daily, interval: -3).interval, 1)
    }

    func testAWeeklyRuleWithNoDaySelectedStillAdvances() {
        let dates = Recurrence(frequency: .weekly, interval: 1, daysOfWeek: [])
            .nextOccurrences(after: Fixture.at(2026, 8, 26, 9, 0), count: 2, calendar: calendar)
        XCTAssertEqual(dates, [Fixture.at(2026, 9, 2, 9, 0), Fixture.at(2026, 9, 9, 9, 0)])
    }
}
