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
    func testEveryInterviewCasingMatchesInBothDirections() {
        let letters = Array("interview")
        for mask in 0..<(1 << letters.count) {
            let variant = letters.enumerated().map { index, letter in
                mask & (1 << index) == 0 ? String(letter) : String(letter).uppercased()
            }.joined()
            XCTAssertTrue(UpcomingEventFilter(include: ["Interview"]).matches(event("Technical \(variant) round")), variant)
            XCTAssertTrue(UpcomingEventFilter(include: [variant]).matches(event("Technical Interview round")), variant)
            XCTAssertFalse(UpcomingEventFilter(exclude: [variant]).matches(event("Technical INTERVIEW round")), variant)
        }
    }

    func testUnicodeCaseAndDiacriticFolding() {
        for (keyword, title) in [("cafe", "CAFÉ meeting"), ("RÉSUMÉ", "Resume review"),
                                 ("straße", "STRASSE planning"), ("interview", "İNTERVIEW"),
                                 ("café", "CAFE\u{301} catch-up")] {
            XCTAssertTrue(UpcomingEventFilter(include: [keyword]).matches(event(title)), title)
            XCTAssertFalse(UpcomingEventFilter(exclude: [keyword]).matches(event(title)), title)
        }
        XCTAssertEqual(UpcomingEventFilter.labels(["Café", "CAFE\u{301}", "cafe"]), ["Café"])
    }

    func testBlankKeywordsAreIgnoredOnBothLists() {
        let filter = UpcomingEventFilter(include: [" ", "\n\t"], exclude: ["", "  "])
        XCTAssertTrue(filter.matches(event("Interview")))
        XCTAssertTrue(filter.matches(event("")))
        XCTAssertFalse(UpcomingEventFilter(include: ["Interview"]).matches(event("")))
    }

    func testMultiplePhrasesAreLiteralSubstringsAndExclusionAlwaysWins() {
        let filter = UpcomingEventFilter(include: ["  technical interview  ", "design review", "C++"],
                                         exclude: ["cancelled", "practice", "[test]"])
        for title in ["Senior Technical Interview – round 2", "DESIGN REVIEW", "C++ interview"] {
            XCTAssertTrue(filter.matches(event(title)), title)
        }
        for title in ["Technical catch-up", "Design review CANCELLED", "Practice technical interview", "C++ [TEST]"] {
            XCTAssertFalse(filter.matches(event(title)), title)
        }
        XCTAssertTrue(UpcomingEventFilter(include: [".*"]).matches(event("Literal .* title")))
        XCTAssertFalse(UpcomingEventFilter(include: [".*"]).matches(event("Unrelated title")))
    }

    func testOnlyTitleParticipatesInKeywordMatching() {
        let item = CalendarEventSnapshot(identifier: "notes", calendarID: "work", title: "Lunch",
            start: now, end: now.addingTimeInterval(3600), location: "Interview room", notes: "Interview preparation")
        XCTAssertFalse(UpcomingEventFilter(include: ["interview"]).matches(item))
        XCTAssertTrue(UpcomingEventFilter(exclude: ["interview"]).matches(item))
    }

    func testOngoingAndMultiDayEventsOverlapButFinishedEventsDoNot() {
        let end = UpcomingEventFilter.range(now: now).end
        let ongoing = event("Ongoing", start: now.addingTimeInterval(-60))
        let spanning = event("Spanning", start: now.addingTimeInterval(-86400), end: end.addingTimeInterval(86400))
        let ended = event("Ended", start: now.addingTimeInterval(-3600), end: now)
        XCTAssertEqual(UpcomingEventFilter().events([ended, ongoing, spanning], now: now).map(\.title), ["Spanning", "Ongoing"])
    }

    func testAllDayExclusiveEndAndZeroDurationBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let midnight = calendar.startOfDay(for: now)
        let end = UpcomingEventFilter.range(now: midnight, calendar: calendar).end
        let yesterday = CalendarEventSnapshot(identifier: "yesterday", calendarID: "work", title: "Yesterday",
            start: midnight.addingTimeInterval(-86400), end: midnight, isAllDay: true)
        let today = CalendarEventSnapshot(identifier: "today", calendarID: "work", title: "Today",
            start: midnight, end: midnight.addingTimeInterval(86400), isAllDay: true)
        let pointNow = event("Point now", start: midnight, end: midnight)
        let pointEnd = event("Point end", start: end, end: end)
        let titles = Set(UpcomingEventFilter().events([yesterday, today, pointNow, pointEnd], now: midnight, calendar: calendar).map(\.title))
        XCTAssertEqual(titles, ["Today", "Point now"])
    }

    func testStableOrderingPreservesDistinctRecurringOccurrences() {
        let first = CalendarEventSnapshot(identifier: "series", calendarID: "work", title: "Interview",
            start: now, end: now.addingTimeInterval(3600))
        let next = CalendarEventSnapshot(identifier: "series", calendarID: "work", title: "Interview",
            start: now.addingTimeInterval(86400), end: now.addingTimeInterval(90000))
        let tie = event("Another interview")
        let filter = UpcomingEventFilter(include: ["interview"])
        let result = filter.events([next, first, tie], now: now)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.last?.id, next.id)
        XCTAssertEqual(result.map(\.id), filter.events([tie, next, first], now: now).map(\.id))
        XCTAssertEqual(Set(result.map(\.id)).count, 3)
    }

    func testChangingNowExpiresEventsAndMovesWindowForward() {
        let limit = UpcomingEventFilter.range(now: now).end
        let expiring = event("Expiring", end: now.addingTimeInterval(1))
        let arriving = event("Arriving", start: limit, end: limit.addingTimeInterval(3600))
        let filter = UpcomingEventFilter()
        XCTAssertEqual(filter.events([expiring, arriving], now: now).map(\.title), ["Expiring"])
        XCTAssertEqual(filter.events([expiring, arriving], now: now.addingTimeInterval(2)).map(\.title), ["Arriving"])
    }

    func testCalendarDaysAcrossFallBackYearAndLeapDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        for (year, month, day, endYear, endMonth, endDay, hours) in [
            (2026, 10, 31, 2026, 11, 7, 169),
            (2026, 12, 28, 2027, 1, 4, 168),
            (2028, 2, 26, 2028, 3, 4, 168)
        ] {
            let start = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
            let range = UpcomingEventFilter.range(now: start, calendar: calendar)
            XCTAssertEqual(range.start, start)
            XCTAssertEqual(calendar.dateComponents([.year, .month, .day, .hour], from: range.end),
                           DateComponents(year: endYear, month: endMonth, day: endDay, hour: 12))
            XCTAssertEqual(range.duration, Double(hours * 3600))
        }
    }

    func testCombinedKeywordsWindowAndVisibilityDoNotMutateInput() {
        let work = event("Work interview")
        let personal = CalendarEventSnapshot(identifier: "personal", calendarID: "personal", title: "Personal interview",
            start: now, end: now.addingTimeInterval(3600))
        let cancelled = event("Cancelled interview")
        let outside = event("Later interview", start: now.addingTimeInterval(8 * 86400), end: now.addingTimeInterval(9 * 86400))
        let input = [work, personal, cancelled, outside, event("Lunch")]
        let filter = UpcomingEventFilter(include: ["INTERVIEW"], exclude: ["CANCELLED"])
        XCTAssertEqual(filter.events(input, now: now, hiddenCalendarIDs: ["work"]).map(\.id), [personal.id])
        XCTAssertEqual(filter.events(input, now: now).count, 2, "Turning visibility back on must restore matching events")
        XCTAssertEqual(input.count, 5)
        XCTAssertEqual(filter.events([], now: now).count, 0)
    }

    func testManualInclusionOverridesBothKeywordListsAndRemovalRestoresRules() {
        let lunch = event("Lunch cancelled")
        let filter = UpcomingEventFilter(include: ["Interview"], exclude: ["cancelled"], manuallyIncludedIDs: [lunch.id])
        XCTAssertEqual(filter.events([lunch], now: now).map(\.id), [lunch.id])
        XCTAssertTrue(UpcomingEventFilter(include: filter.include, exclude: filter.exclude)
            .events([lunch], now: now).isEmpty)
    }

    func testManualInclusionNeverOverridesCalendarVisibilityOrSevenDayWindow() {
        let lunch = event("Lunch")
        let past = event("Past", start: now.addingTimeInterval(-3600), end: now)
        let limit = UpcomingEventFilter.range(now: now).end
        let later = event("Later", start: limit, end: limit.addingTimeInterval(3600))
        let filter = UpcomingEventFilter(include: ["Interview"], manuallyIncludedIDs: [lunch.id, past.id, later.id])
        XCTAssertEqual(filter.events([past, lunch, later], now: now).map(\.id), [lunch.id])
        XCTAssertTrue(filter.events([lunch], now: now, hiddenCalendarIDs: ["work"]).isEmpty)
    }

    func testManualInclusionIsScopedToOccurrenceAndCalendar() throws {
        let first = event("Lunch")
        let next = CalendarEventSnapshot(identifier: first.identifier, calendarID: first.calendarID,
            title: first.title, start: now.addingTimeInterval(86400), end: now.addingTimeInterval(90000))
        let otherCalendar = CalendarEventSnapshot(identifier: first.identifier, calendarID: "personal",
            title: first.title, start: first.start, end: first.end)
        // The same property-list representation is stored in UserDefaults.
        let data = try PropertyListEncoder().encode([first.id])
        let restored = Set(try PropertyListDecoder().decode([String].self, from: data))
        let filter = UpcomingEventFilter(include: ["Interview"], manuallyIncludedIDs: restored)
        XCTAssertEqual(filter.events([next, otherCalendar, first], now: now).map(\.id), [first.id])
    }

    func testManualAndKeywordMatchOnlyAppearOnceAndReflectUpdatedEventDetails() {
        let item = event("Interview")
        let filter = UpcomingEventFilter(include: ["Interview"], manuallyIncludedIDs: [item.id])
        XCTAssertEqual(filter.events([item], now: now).count, 1)
        let renamed = CalendarEventSnapshot(identifier: item.identifier, calendarID: item.calendarID,
            title: "New title", start: item.start, end: item.end)
        XCTAssertEqual(filter.events([renamed], now: now).map(\.title), ["New title"])
        XCTAssertTrue(filter.events([], now: now).isEmpty, "Deleted events must not be recreated from saved selections")
    }

    @MainActor
    func testFeedRefreshReappliesKeywordsWithoutRemovingDayViewData() async {
        let interview = event("INTERVIEW")
        let lunch = event("Lunch")
        let edited = CalendarEventSnapshot(identifier: interview.identifier, calendarID: "work", title: "Interview CANCELLED",
            start: interview.start, end: interview.end)
        let reader = UpcomingFixtureReader(batches: [[interview, lunch], [edited, lunch]])
        let feed = CalendarFeed(reader: reader)
        let range = UpcomingEventFilter.range(now: now)
        let filter = UpcomingEventFilter(include: ["interview"], exclude: ["cancelled"])
        await feed.refresh(ranges: [range])
        XCTAssertEqual(filter.events(feed.events, now: now).map(\.id), [interview.id])
        XCTAssertEqual(feed.events(in: range).count, 2, "Upcoming filters must not change the day view's data")
        await feed.refresh(ranges: [range])
        XCTAssertTrue(filter.events(feed.events, now: now).isEmpty)
        XCTAssertEqual(feed.events(in: range).count, 2)
    }

}


private actor UpcomingFixtureReader: CalendarReading {
    private var batches: [[CalendarEventSnapshot]]
    init(batches: [[CalendarEventSnapshot]]) { self.batches = batches }
    func requestAccess() async -> Bool { true }
    func read(ranges: [DateInterval], refreshSources: Bool) async throws -> CalendarReadResult {
        .loaded(calendars: [EventCalendarSnapshot(id: "work", title: "Work", source: "Fixture", tint: .ocean)],
                events: batches.removeFirst())
    }
}
