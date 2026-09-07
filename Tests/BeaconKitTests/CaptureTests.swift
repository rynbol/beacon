import Foundation
import XCTest
@testable import BeaconKit

final class CaptureTests: XCTestCase {

    func testPlainTextKeepsItsTitleAndGetsNoDate() {
        let parsed = Capture.parse("call the dentist")
        XCTAssertEqual(parsed.title, "call the dentist")
        XCTAssertNil(parsed.due)
    }

    func testADatePhraseIsStrippedFromTheTitle() {
        // The point of parsing: the date must leave the title, or every task is
        // named after its own deadline.
        for text in ["pay rent tomorrow", "pay rent on tomorrow"] {
            let parsed = Capture.parse(text)
            XCTAssertEqual(parsed.title, "pay rent", "failed on: \(text)")
            XCTAssertNotNil(parsed.due, "failed on: \(text)")
        }
    }

    func testRelativeDurationsResolveExactly() {
        // The system detector reads none of these, yet they are how a reminder
        // is normally phrased, so Beacon reads them itself.
        let now = Fixture.at(2026, 8, 26, 14, 0)
        let cases: [(String, String, TimeInterval)] = [
            ("buy coffee in 2 hours", "buy coffee", 2 * 3600),
            ("standup in 30 minutes", "standup", 30 * 60),
            ("stretch in 20 mins", "stretch", 20 * 60),
            ("ship it in 3 days", "ship it", 3 * 86_400),
            ("review in 1 week", "review", 604_800),
        ]
        for (text, title, offset) in cases {
            let parsed = Capture.parse(text, now: now)
            XCTAssertEqual(parsed.title, title, "wrong title for: \(text)")
            XCTAssertEqual(parsed.due, now.addingTimeInterval(offset), "wrong date for: \(text)")
        }
    }

    func testAbsolutePhrasesStillGoThroughTheSystemDetector() {
        let now = Fixture.at(2026, 8, 26, 14, 0)
        for (text, title) in [
            ("pay rent tomorrow", "pay rent"),
            ("review next tuesday", "review"),
            ("dentist on 12 September", "dentist"),
            ("gym tomorrow at 7am", "gym"),
        ] {
            let parsed = Capture.parse(text, now: now)
            XCTAssertEqual(parsed.title, title, "wrong title for: \(text)")
            XCTAssertNotNil(parsed.due, "no date for: \(text)")
        }
    }

    func testDanglingConnectorsAreRemoved() {
        XCTAssertEqual(Capture.parse("submit the report by friday").title, "submit the report")
        XCTAssertEqual(Capture.parse("call Ana at 3pm").title, "call Ana")
    }

    func testTextThatIsOnlyADateKeepsItsText() {
        // "tomorrow" alone would otherwise produce a task with no name at all.
        let parsed = Capture.parse("tomorrow")
        XCTAssertEqual(parsed.title, "tomorrow")
        XCTAssertNil(parsed.due)
    }

    func testWhitespaceOnlyInputIsHandled() {
        XCTAssertEqual(Capture.parse("   ").title, "")
        XCTAssertNil(Capture.parse("   ").due)
    }

    func testSurroundingWhitespaceIsTrimmed() {
        XCTAssertEqual(Capture.parse("  water the plants  ").title, "water the plants")
    }
}

final class DueComponentsTests: XCTestCase {

    private let calendar = Fixture.calendar

    func testComponentsCarryATimeOfDaySoTheTaskIsNotAllDay() {
        // Omitting hour, minute and second silently makes the reminder all-day.
        let components = DueComponents.make(from: Fixture.at(2026, 8, 26, 14, 30), calendar: calendar)
        XCTAssertEqual(components?.hour, 14)
        XCTAssertEqual(components?.minute, 30)
        XCTAssertEqual(components?.second, 0)
        XCTAssertTrue(DueComponents.hasTimeOfDay(components))
    }

    func testComponentsCarryTheGregorianCalendarAndAZone() {
        let components = DueComponents.make(from: Fixture.at(2026, 8, 26, 14, 30), calendar: calendar)
        XCTAssertEqual(components?.calendar?.identifier, .gregorian)
        XCTAssertNotNil(components?.timeZone)
    }

    func testComponentsRoundTripBackToTheSameInstant() {
        for date in [
            Fixture.at(2026, 1, 31, 9, 0),
            Fixture.at(2026, 2, 28, 23, 59),
            Fixture.at(2026, 12, 31, 0, 0),
        ] {
            let components = DueComponents.make(from: date, calendar: calendar)
            XCTAssertEqual(calendar.date(from: components!), date)
        }
    }

    func testMonthEndDatesSurviveIntact() {
        // EventKit normalises an impossible date instead of refusing it, so
        // 31 February would save as 3 March. Building from a real instant means
        // an impossible date can never be constructed in the first place.
        let components = DueComponents.make(from: Fixture.at(2026, 1, 31, 9, 0), calendar: calendar)
        XCTAssertEqual(components?.month, 1)
        XCTAssertEqual(components?.day, 31)
        XCTAssertTrue(components!.isValidDate(in: calendar))
    }
}
