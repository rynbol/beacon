import XCTest
@testable import BeaconKit

final class CalendarNotePresentationTests: XCTestCase {
    func testStandaloneURLUsesHostButPreservesFullTarget() {
        let url = "https://www.yelp.com/reservations/restaurant/confirmed/123?share=1"
        let displayed = CalendarNotes.displayText("Booking\n\n" + url)
        XCTAssertEqual(String(displayed.characters), "Booking\n\nOpen yelp.com ↗")
        XCTAssertEqual(displayed.runs.compactMap(\.link), [URL(string: url)!])
    }
    func testInlineLinksAndUnsafeSchemesAreNotRelabeled() {
        let prose = "See https://example.com/path for details."
        XCTAssertEqual(String(CalendarNotes.displayText(prose).characters), prose)
        let unsafe = CalendarNotes.displayText("javascript:alert(1)")
        XCTAssertTrue(unsafe.runs.compactMap(\.link).isEmpty)
    }
    func testOnlyExactRepeatedLocationIsRemoved() {
        let notes = "Address: Wasabi Bistro, 524 Castro St\n\nArrive at 6.\nAddress: Different venue"
        XCTAssertEqual(CalendarNotes.withoutRepeatedLocation(notes, location: "Wasabi Bistro, 524 Castro St"),
                       "Arrive at 6.\nAddress: Different venue")
        XCTAssertEqual(CalendarNotes.withoutRepeatedLocation(notes, location: ""), notes)
    }
}
