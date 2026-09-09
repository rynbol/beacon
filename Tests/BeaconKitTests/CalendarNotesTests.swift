import XCTest
@testable import BeaconKit

final class CalendarNotesTests: XCTestCase {
    func testPlainTextIsPreservedIncludingLineBreaksAndComparisons() {
        let text = "Keep <draft> as written.\n\nCost < 50 & time > 20.\n"
        XCTAssertEqual(CalendarNotes.plainText(text), text)
    }

    func testProviderHTMLBecomesReadableNotesWithListsAndEntities() {
        let html = "<p>Interview &amp; review</p>Join at noon<br />Bring notes<ul><li><p>Meet the team</p></li><li>Q&amp;A</li></ul>"
        XCTAssertEqual(CalendarNotes.plainText(html), "Interview & review\nJoin at noon\nBring notes\n• Meet the team\n• Q&A")
    }

    func testLinksKeepTheirDestinationsAndDecodeQueryEntities() {
        let html = #"<a href="https://example.com/reschedule?a=1&amp;b=2">Reschedule</a>"#
        XCTAssertEqual(CalendarNotes.plainText(html), "Reschedule (https://example.com/reschedule?a=1&b=2)")
        let same = #"<a href="https://example.com">https://example.com</a>"#
        XCTAssertEqual(CalendarNotes.plainText(same), "https://example.com")
    }

    func testHTMLIsInertAndMalformedFragmentsAreTolerated() {
        let html = "<p>Hello<script>alert('x')</script><style>.bad{}</style><img src='https://example.com/pixel' alt='diagram'><br><b>World"
        XCTAssertEqual(CalendarNotes.plainText(html), "Hellodiagram\nWorld")
        XCTAssertEqual(CalendarNotes.plainText("<a href='javascript:alert(1)'>Label</a>"), "Label")
    }

    func testSnapshotNormalizesHTMLWithoutChangingIdentityOrMeetingTime() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let event = CalendarEventSnapshot(identifier: "fixture", calendarID: "work", title: "Review", start: date, end: date,
            notes: "<p>One</p><p>Two</p>")
        XCTAssertEqual(event.notes, "One\nTwo")
        XCTAssertEqual(event.start, date)
        XCTAssertEqual(event.identifier, "fixture")
    }

    func testZoomDotComAndHTMLMeetingLinksAreRecognized() {
        let url = "https://sample.zoom.com/j/123?pwd=sample&token=example"
        let html = #"<p>Join <a href="https://sample.zoom.com/j/123?pwd=sample&amp;token=example">meeting</a></p>"#
        XCTAssertEqual(CalendarEventSnapshot.meetingLink(in: html)?.absoluteString, url)
        XCTAssertNil(CalendarEventSnapshot.meetingLink(in: "https://sample.zoom.com.attacker.test/j/123"))
        XCTAssertNil(CalendarEventSnapshot.meetingLink(in: "http://sample.zoom.com/j/123"))
    }
}
