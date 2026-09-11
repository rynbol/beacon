import XCTest
@testable import BeaconKit

@MainActor
final class CalendarMediaTests: XCTestCase {
    func testCopiesPersistAndStaySeparateFromSourceAndOtherEvents() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("sample.png")
        let data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aO1cAAAAASUVORK5CYII=")!
        try data.write(to: source)
        let storage = root.appendingPathComponent("media")
        let store = CalendarMediaStore(root: storage)
        try await store.add(source, for: "../../event")
        try await store.add(source, for: "../../event")
        let copies = store.files(for: "../../event")
        XCTAssertEqual(copies.count, 2)
        XCTAssertNotEqual(copies[0], copies[1])
        XCTAssertTrue(store.files(for: "other").isEmpty)
        XCTAssertEqual(try Data(contentsOf: source), data)
        try FileManager.default.removeItem(at: source)
        let reopened = CalendarMediaStore(root: storage)
        XCTAssertEqual(reopened.files(for: "../../event"), copies)
        for copy in copies {
            XCTAssertTrue(copy.resolvingSymlinksInPath().path.hasPrefix(storage.resolvingSymlinksInPath().path + "/"))
            XCTAssertEqual(try Data(contentsOf: copy), data)
            let attrs = try FileManager.default.attributesOfItem(atPath: copy.path)
            XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        }
        XCTAssertTrue(CalendarMediaStore(root: root.appendingPathComponent("preview")).files(for: "../../event").isEmpty)
    }

    func testUnsupportedAndOversizedFilesDoNotLeaveAttachments() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = CalendarMediaStore(root: root.appendingPathComponent("media"))
        let text = root.appendingPathComponent("sample.txt")
        try Data("Not media".utf8).write(to: text)
        do { try await store.add(text, for: "event"); XCTFail("Accepted text") }
        catch { XCTAssertTrue(error is CalendarMediaStore.MediaError) }
        let large = root.appendingPathComponent("large.png")
        FileManager.default.createFile(atPath: large.path, contents: Data())
        let handle = try FileHandle(forWritingTo: large)
        try handle.truncate(atOffset: 101 * 1024 * 1024)
        try handle.close()
        do { try await store.add(large, for: "event"); XCTFail("Accepted oversized media") }
        catch { XCTAssertTrue(error is CalendarMediaStore.MediaError) }
        XCTAssertTrue(store.files(for: "event").isEmpty)
    }
}
