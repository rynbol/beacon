import Foundation
import XCTest
@testable import BeaconKit

final class SiriCaptureTests: XCTestCase {
    func testUndatedSiriReminderStaysUndatedInSomedayAndSilent() {
        let task = TaskSnapshot(key: "siri", title: "Buy milk", due: nil)
        let now = Fixture.at(2026, 8, 26, 10, 0)
        XCTAssertEqual(Sections.bucket(task, now: now, calendar: Fixture.calendar), .someday)
        XCTAssertEqual(Sections.relativeText(for: task, now: now, calendar: Fixture.calendar), "Someday")
        XCTAssertTrue(Scheduler.plan(now: now, tasks: [task], state: [:], settings: .default, calendar: Fixture.calendar).notifications.isEmpty)
        XCTAssertNil(task.due, "Someday must not invent a due date in Apple Reminders")
    }

    func testExplicitTodayAndTomorrowFromSiriKeepTheirSections() {
        let now = Fixture.at(2026, 8, 26, 10, 0)
        let today = TaskSnapshot(key: "today", title: "Buy milk", due: Fixture.at(2026, 8, 26, 0, 0))
        let tomorrow = TaskSnapshot(key: "tomorrow", title: "Buy milk", due: Fixture.at(2026, 8, 27, 0, 0))
        XCTAssertEqual(Sections.bucket(today, now: now, calendar: Fixture.calendar), .today)
        XCTAssertEqual(Sections.bucket(tomorrow, now: now, calendar: Fixture.calendar), .tomorrow)
        XCTAssertFalse(Scheduler.plan(now: now, tasks: [today], state: [:], settings: .default, calendar: Fixture.calendar).oneShotFires.isEmpty)
    }

    func testTypedCaptureDefaultsToNoDateButRecognizesExplicitDays() {
        XCTAssertNil(Capture.parse("Buy milk").due)
        let now = Date()
        let today = Capture.parse("Buy milk today", now: now)
        let tomorrow = Capture.parse("Buy milk tomorrow", now: now)
        XCTAssertNotNil(today.due)
        XCTAssertNotNil(tomorrow.due)
        if let due = today.due { XCTAssertTrue(Calendar.current.isDate(due, inSameDayAs: now)) }
        if let due = tomorrow.due {
            XCTAssertTrue(Calendar.current.isDate(due, inSameDayAs: Calendar.current.date(byAdding: .day, value: 1, to: now)!))
        }
    }
}
