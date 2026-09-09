import XCTest
@testable import BeaconKit

final class UrgencyTests: XCTestCase {
    func testApplePriorityRangesAndUnsetFallback() {
        XCTAssertEqual(Urgency(priority: 0), .none)
        for value in 1...4 { XCTAssertEqual(Urgency(priority: value), .high) }
        XCTAssertEqual(Urgency(priority: 5), .medium)
        for value in 6...9 { XCTAssertEqual(Urgency(priority: value), .low) }
        for value in [-1, 10, Int.max] { XCTAssertEqual(Urgency(priority: value), .none) }
    }
    func testCanonicalValuesRoundTrip() {
        XCTAssertEqual(Urgency.none.priority, 0)
        XCTAssertEqual(Urgency.low.priority, 9)
        XCTAssertEqual(Urgency.medium.priority, 5)
        XCTAssertEqual(Urgency.high.priority, 1)
        for urgency in Urgency.allCases {
            XCTAssertEqual(Urgency(priority: urgency.priority), urgency)
        }
    }
    func testSnapshotsDefaultToNoneAndRetainOriginalPriority() {
        XCTAssertEqual(TaskSnapshot(key: "new", title: "New").urgency, .none)
        for value in 0...9 {
            let task = TaskSnapshot(key: "existing", title: "Existing", priority: value)
            XCTAssertEqual(task.priority, value)
            XCTAssertEqual(task.urgency, Urgency(priority: value))
            XCTAssertNil(task.due)
        }
    }
}
