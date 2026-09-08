import XCTest
@testable import BeaconKit

@MainActor
final class CalendarTests: XCTestCase {
    private let range = DateInterval(start: Date(timeIntervalSince1970: 1_000), end: Date(timeIntervalSince1970: 2_000))
    private func event(_ id: String = "event", start: Double = 1_100, end: Double = 1_200, calendar: String = "work", allDay: Bool = false) -> CalendarEventSnapshot {
        CalendarEventSnapshot(identifier: id, calendarID: calendar, title: id,
            start: Date(timeIntervalSince1970: start), end: Date(timeIntervalSince1970: end), isAllDay: allDay)
    }
    func testAllDayEndIsExclusiveAndMultiDayEventOverlaps() {
        XCTAssertFalse(event(start: 0, end: 1_000, allDay: true).overlaps(range))
        XCTAssertFalse(event(start: 2_000, end: 2_100).overlaps(range))
        XCTAssertTrue(event(start: 0, end: 3_000, allDay: true).overlaps(range))
        XCTAssertTrue(event(start: 1_000, end: 1_000).overlaps(range))
    }
    func testCalendarTogglesFollowDateWithoutDependingOnVisibilityOrFourItemLimit() async {
        let calendars = (0..<6).map {
            EventCalendarSnapshot(id: "c\($0)", title: "Calendar \($0)", source: "Test", tint: .ocean)
        }
        let events = (0..<5).map { event("e\($0)", calendar: "c\($0)") }
            + [event("tomorrow", start: 2_000, end: 2_100, calendar: "c5")]
        let feed = CalendarFeed(reader: StubCalendarReader(results: [.loaded(calendars: calendars, events: events)]))
        await feed.refresh(ranges: [range])
        XCTAssertEqual(feed.calendarsWithEvents(in: range).map(\.id), ["c0", "c1", "c2", "c3", "c4"])
        XCTAssertTrue(feed.events(in: range, hiddenCalendarIDs: Set(calendars.map(\.id))).isEmpty)
        XCTAssertEqual(feed.calendarsWithEvents(in: range).count, 5)
        XCTAssertEqual(feed.calendarsWithEvents(in: DateInterval(start: range.end, duration: 100)).map(\.id), ["c5"])
        XCTAssertTrue(feed.calendarsWithEvents(in: DateInterval(start: range.end.addingTimeInterval(200), duration: 100)).isEmpty)
    }

    func testRecurringOccurrencesHaveDistinctIdentities() {
        XCTAssertNotEqual(event(start: 1_100).id, event(start: 1_300).id)
        XCTAssertNotEqual(event(calendar: "work").id, event(calendar: "personal").id)
    }
    func testMeetingLinksRequireRecognizedHTTPSHost() {
        XCTAssertEqual(CalendarEventSnapshot.meetingLink(in: "Join https://meet.google.com/abc-defg-hij")?.host, "meet.google.com")
        XCTAssertEqual(CalendarEventSnapshot.meetingLink(in: "https://us02web.zoom.us/j/123")?.host, "us02web.zoom.us")
        XCTAssertNil(CalendarEventSnapshot.meetingLink(in: "https://meet.google.com.attacker.test/abc"))
        XCTAssertNil(CalendarEventSnapshot.meetingLink(in: "http://meet.google.com/abc"))
    }
    func testEveryRefreshRereadsEvenWhenRangeIsUnchanged() async {
        let reader = StubCalendarReader(results: [.loaded(calendars: [], events: [event("before")]), .loaded(calendars: [], events: [event("after")])])
        let feed = CalendarFeed(reader: reader)
        await feed.refresh(ranges: [range])
        XCTAssertEqual(feed.events.first?.title, "before")
        await feed.refresh(ranges: [range])
        XCTAssertEqual(feed.events.first?.title, "after")
        let calls = await reader.calls
        XCTAssertEqual(calls, [true, true])
    }
    func testExternalChangeReadDoesNotRequestAnotherSourceSync() async {
        let reader = StubCalendarReader(results: [.loaded(calendars: [], events: [])])
        let feed = CalendarFeed(reader: reader)
        await feed.refresh(ranges: [range], requestSourceRefresh: false)
        let calls = await reader.calls
        XCTAssertEqual(calls, [false])
    }
    func testReadFailureRetainsEventsButRevokedPermissionClearsThem() async {
        let reader = StubCalendarReader(results: [.loaded(calendars: [], events: [event()]), .denied])
        let feed = CalendarFeed(reader: reader)
        await feed.refresh(ranges: [range])
        let readTime = feed.lastRead
        await reader.failNext()
        await feed.refresh(ranges: [range])
        XCTAssertEqual(feed.events.count, 1)
        XCTAssertEqual(feed.lastRead, readTime)
        XCTAssertNotNil(feed.error)
        await feed.refresh(ranges: [range])
        XCTAssertTrue(feed.events.isEmpty)
        XCTAssertNil(feed.lastRead)
        XCTAssertNil(feed.error)
        XCTAssertEqual(feed.access, .denied)
    }
    func testCalendarVisibilityAndAllDayOrdering() async {
        let reader = StubCalendarReader(results: [.loaded(calendars: [], events: [event(), event("all day", start: 1_000, end: 2_000, calendar: "personal", allDay: true)])])
        let feed = CalendarFeed(reader: reader)
        await feed.refresh(ranges: [range])
        XCTAssertEqual(feed.events(in: range).first?.title, "all day")
        XCTAssertEqual(feed.events(in: range, hiddenCalendarIDs: ["personal"]).map(\.title), ["event"])
    }
    func testNewNavigationDiscardsOlderInFlightResultAndAwaitsFreshRead() async {
        let reader = GatedCalendarReader()
        let feed = CalendarFeed(reader: reader)
        let first = Task { await feed.refresh(ranges: [range]) }
        await reader.waitForReads(1)
        let nextRange = DateInterval(start: range.end, duration: 1_000)
        let second = Task { await feed.refresh(ranges: [nextRange]) }
        // Both tasks are MainActor-bound. Yield lets the second request queue
        // while the reader still holds the first result.
        await Task.yield()
        await reader.resolve(.loaded(calendars: [], events: [event("stale")]))
        await reader.waitForReads(2)
        XCTAssertTrue(feed.events.isEmpty, "Old range must not flash into the new page")
        await reader.resolve(.loaded(calendars: [], events: [event("fresh", start: 2_100, end: 2_200)]))
        await first.value; await second.value
        XCTAssertEqual(feed.events.first?.title, "fresh")
        let ranges = await reader.ranges
        XCTAssertEqual(ranges.last, [nextRange])
        XCTAssertFalse(feed.isRefreshing)
    }
}

private actor StubCalendarReader: CalendarReading {
    var results: [CalendarReadResult]
    var calls: [Bool] = []
    var shouldFail = false
    init(results: [CalendarReadResult]) { self.results = results }
    func requestAccess() -> Bool { true }
    func failNext() { shouldFail = true }
    func read(ranges: [DateInterval], refreshSources: Bool) throws -> CalendarReadResult {
        calls.append(refreshSources)
        if shouldFail { shouldFail = false; throw CocoaError(.fileReadUnknown) }
        return results.removeFirst()
    }
}

private actor GatedCalendarReader: CalendarReading {
    var ranges: [[DateInterval]] = []
    var pending: CheckedContinuation<CalendarReadResult, Never>?
    var observers: [(Int, CheckedContinuation<Void, Never>)] = []
    func requestAccess() -> Bool { true }
    func waitForReads(_ count: Int) async {
        if ranges.count >= count { return }
        await withCheckedContinuation { observers.append((count, $0)) }
    }
    func read(ranges: [DateInterval], refreshSources: Bool) async -> CalendarReadResult {
        self.ranges.append(ranges)
        return await withCheckedContinuation { continuation in
            pending = continuation
            let ready = observers.filter { $0.0 <= self.ranges.count }
            observers.removeAll { $0.0 <= self.ranges.count }
            ready.forEach { $0.1.resume() }
        }
    }
    func resolve(_ result: CalendarReadResult) { let next = pending; pending = nil; next?.resume(returning: result) }
}
