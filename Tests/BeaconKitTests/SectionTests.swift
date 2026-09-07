import Foundation
import XCTest
@testable import BeaconKit

final class SectionTests: XCTestCase {

    private let calendar = Fixture.calendar
    private var now: Date { Fixture.at(2026, 8, 26, 14, 0) }

    func testPastDueAndUndatedTasksLandInToday() {
        // There is no overdue bucket anywhere in the app, on purpose.
        for due in [nil, Fixture.at(2026, 1, 1, 9, 0), Fixture.at(2026, 8, 26, 9, 0)] {
            XCTAssertEqual(
                Sections.bucket(Fixture.task("a", due: due), now: now, calendar: calendar),
                .today
            )
        }
    }

    func testFutureTasksBucketByDistance() {
        let cases: [(Date, TaskSection)] = [
            (Fixture.at(2026, 8, 26, 23, 0), .today),
            (Fixture.at(2026, 8, 27, 9, 0), .tomorrow),
            (Fixture.at(2026, 8, 30, 9, 0), .next7),
            (Fixture.at(2026, 9, 2, 9, 0), .next7),
            (Fixture.at(2026, 9, 10, 9, 0), .next30),
            (Fixture.at(2026, 12, 1, 9, 0), .later),
        ]
        for (due, expected) in cases {
            XCTAssertEqual(
                Sections.bucket(Fixture.task("a", due: due), now: now, calendar: calendar),
                expected, "wrong bucket for \(due)"
            )
        }
    }

    func testCompletedTasksGoToTheirOwnSection() {
        XCTAssertEqual(
            Sections.bucket(Fixture.task("a", completed: true), now: now, calendar: calendar),
            .recentlyCompleted
        )
    }

    func testGroupingKeepsSectionOrderAndSortsWithinASection() {
        let tasks = [
            Fixture.task("late", due: Fixture.at(2026, 12, 1, 9, 0)),
            Fixture.task("undated", due: nil),
            Fixture.task("soon", due: Fixture.at(2026, 8, 26, 18, 0)),
            Fixture.task("tomorrow", due: Fixture.at(2026, 8, 27, 9, 0)),
        ]
        let groups = Sections.group(tasks, now: now, calendar: calendar)

        XCTAssertEqual(groups.map(\.section), [.today, .tomorrow, .later])
        // Undated means due now, so it sorts above a dated task in the same section.
        XCTAssertEqual(groups[0].tasks.map(\.key), ["undated", "soon"])
    }

    func testEmptySectionsAreOmitted() {
        let groups = Sections.group(
            [Fixture.task("a", due: nil)], now: now, calendar: calendar
        )
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].section, .today)
    }

    func testPastDueReadsAsNowNotAsADate() {
        XCTAssertEqual(
            Sections.relativeText(
                for: Fixture.task("a", due: Fixture.at(2026, 1, 1, 9, 0)),
                now: now, calendar: calendar
            ),
            "Now"
        )
        XCTAssertEqual(
            Sections.relativeText(for: Fixture.task("a", due: nil), now: now, calendar: calendar),
            "Now"
        )
    }

    func testAllDayFutureTasksReadAsDayNames() {
        let task = TaskSnapshot(
            key: "a", title: "t", due: Fixture.at(2026, 8, 27, 0, 0), hasTimeOfDay: false
        )
        XCTAssertEqual(Sections.relativeText(for: task, now: now, calendar: calendar), "Tomorrow")
    }

    func testCompletedTasksReadAsDone() {
        XCTAssertEqual(
            Sections.relativeText(for: Fixture.task("a", completed: true), now: now, calendar: calendar),
            "Done"
        )
    }
}
