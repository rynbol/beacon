import XCTest
@testable import BeaconKit

@MainActor
final class CalendarPersonalNotesTests: XCTestCase {
    private func path() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("notes.json")
    }
    func testSaveReopenUpdateAndClearKeepOtherEvents() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = CalendarPersonalNotesStore(url: url)
        store.set("Private thoughts\n第二行", for: "one")
        store.set("Other note", for: "two")
        XCTAssertNil(store.error(for: "one"))
        let reopened = CalendarPersonalNotesStore(url: url)
        XCTAssertEqual(reopened.text(for: "one"), "Private thoughts\n第二行")
        reopened.set("Edited", for: "one")
        XCTAssertEqual(CalendarPersonalNotesStore(url: url).text(for: "one"), "Edited")
        reopened.set("", for: "one")
        let cleared = CalendarPersonalNotesStore(url: url)
        XCTAssertEqual(cleared.text(for: "one"), "")
        XCTAssertEqual(cleared.text(for: "two"), "Other note")
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }
    func testCorruptFileIsNotOverwrittenAndDraftSurvives() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data("broken json".utf8)
        try original.write(to: url)
        let store = CalendarPersonalNotesStore(url: url)
        store.set("Unsaved draft", for: "one")
        XCTAssertNotNil(store.error(for: "one"))
        XCTAssertEqual(store.text(for: "one"), "Unsaved draft")
        XCTAssertEqual(try Data(contentsOf: url), original)
        try JSONEncoder().encode(["two": "Recovered"]).write(to: url)
        store.set(store.text(for: "one"), for: "one")
        XCTAssertNil(store.error(for: "one"))
        XCTAssertEqual(CalendarPersonalNotesStore(url: url).text(for: "two"), "Recovered")
    }
    func testWriteFailureKeepsDraftAndRetrySavesIt() async throws {
        let url = path()
        let parent = url.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: parent) }
        try Data("block directory creation".utf8).write(to: parent)
        let store = CalendarPersonalNotesStore(url: url)
        store.set("Draft", for: "one")
        XCTAssertNotNil(store.error(for: "one"))
        XCTAssertEqual(store.text(for: "one"), "Draft")
        try FileManager.default.removeItem(at: parent)
        store.set(store.text(for: "one"), for: "one")
        XCTAssertNil(store.error(for: "one"))
        XCTAssertEqual(CalendarPersonalNotesStore(url: url).text(for: "one"), "Draft")
    }
    func testIdentitySurvivesRescheduleAndSeparatesRecurringOccurrences() async {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        func event(_ start: Date, occurrence: Date? = nil, calendar: String = "work") -> CalendarEventSnapshot {
            CalendarEventSnapshot(identifier: "event", calendarID: calendar, title: "Meeting", start: start,
                end: start.addingTimeInterval(1800), notes: "Provider notes", occurrenceDate: occurrence)
        }
        let later = date.addingTimeInterval(86400)
        XCTAssertEqual(event(date).personalNotesKey, event(later).personalNotesKey)
        XCTAssertEqual(event(date, occurrence: date).personalNotesKey, event(later, occurrence: date).personalNotesKey)
        XCTAssertNotEqual(event(date, occurrence: date).personalNotesKey, event(later, occurrence: later).personalNotesKey)
        XCTAssertNotEqual(event(date).personalNotesKey, event(date, calendar: "home").personalNotesKey)
        XCTAssertEqual(event(date).notes, "Provider notes")
    }
    func testSeparateFilesKeepPreviewNotesIsolated() async {
        let first = path(), second = path()
        defer {
            try? FileManager.default.removeItem(at: first.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: second.deletingLastPathComponent())
        }
        let preview = CalendarPersonalNotesStore(url: first)
        preview.set("Preview", for: "same-key")
        XCTAssertEqual(CalendarPersonalNotesStore(url: second).text(for: "same-key"), "")
    }
}
