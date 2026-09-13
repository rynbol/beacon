import Foundation
import XCTest
import BeaconKit
@testable import BeaconApp

@MainActor
final class PreviewReminderTests: XCTestCase {
    func testCaptureEditCompleteAndDeleteStayInOnePreviewSession() async throws {
        let model = TaskListModel(isPreview: true)
        let otherPreview = TaskListModel(isPreview: true)
        await model.start()
        await otherPreview.start()
        let sampleCount = model.taskCount
        let otherKeys = Set(otherPreview.groups.flatMap(\.tasks).map(\.key))

        await model.create(title: "Animation fixture", due: nil, notes: "Local sample",
                           listID: "preview-work", recurrence: nil, urgency: .high)
        let created = try XCTUnwrap(model.groups.flatMap(\.tasks).first { $0.title == "Animation fixture" })
        XCTAssertEqual(model.taskCount, sampleCount + 1)
        XCTAssertTrue(created.key.hasPrefix("preview-"))
        XCTAssertNil(created.due)
        XCTAssertEqual(created.listName, "Work")
        XCTAssertEqual(created.urgency, .high)

        let due = Date().addingTimeInterval(600)
        await model.update(created, title: "Edited sample", due: due, notes: "Updated note",
                           listID: "preview-personal", recurrence: nil, urgency: .low)
        let edited = try XCTUnwrap(model.task(withKey: created.key))
        XCTAssertEqual(edited.title, "Edited sample")
        XCTAssertEqual(edited.due, due)
        XCTAssertEqual(edited.listName, "Personal")
        XCTAssertEqual(edited.notes, "Updated note")
        XCTAssertEqual(edited.urgency, .low)

        // Completion uses the current snapshot even if a pending UI action
        // captured the item before its edit. Repeated delivery stays complete.
        await model.complete(created)
        await model.complete(created)
        let completed = try XCTUnwrap(model.task(withKey: created.key))
        XCTAssertTrue(completed.isCompleted)
        XCTAssertNotNil(completed.completionDate)
        XCTAssertEqual(completed.title, "Edited sample")
        await model.toggleCompleted(completed)
        XCTAssertEqual(model.task(withKey: created.key)?.isCompleted, false)
        XCTAssertNil(model.task(withKey: created.key)?.completionDate)
        await model.delete(edited)
        XCTAssertNil(model.task(withKey: created.key))
        XCTAssertEqual(model.taskCount, sampleCount)
        XCTAssertNil(model.writeError)

        XCTAssertEqual(Set(otherPreview.groups.flatMap(\.tasks).map(\.key)), otherKeys)
        XCTAssertEqual(otherPreview.taskCount, sampleCount)
        XCTAssertFalse(model.alertsEnabled)
        XCTAssertEqual(model.pendingCount, 0)
        XCTAssertEqual(model.authorization, .notAsked)
    }

    func testPreviewSnoozePreservesRecurringDatesAndAdvancesLocalOptions() async throws {
        let model = TaskListModel(isPreview: true)
        await model.start()
        let recurring = try XCTUnwrap(model.task(withKey: "preview-3"))
        let initialOptions = model.snoozeOptions(for: recurring)
        await model.snooze(recurring, by: 900)
        XCTAssertEqual(model.task(withKey: recurring.key)?.due, recurring.due)
        XCTAssertEqual(model.snoozeOptions(for: recurring).first?.interval, initialOptions[1].interval)

        let ordinary = try XCTUnwrap(model.task(withKey: "preview-1"))
        let before = Date().addingTimeInterval(900)
        await model.snooze(ordinary, by: 900)
        let snoozed = try XCTUnwrap(model.task(withKey: ordinary.key))
        let actualDue = try XCTUnwrap(snoozed.due)
        XCTAssertGreaterThanOrEqual(actualDue, before)
        XCTAssertLessThanOrEqual(actualDue, Date().addingTimeInterval(900))
        await model.toggleMuted(snoozed)
        XCTAssertTrue(model.isMuted(snoozed))
        await model.complete(snoozed)
        XCTAssertFalse(model.isMuted(snoozed))

        let fresh = TaskListModel(isPreview: true)
        await fresh.start()
        XCTAssertEqual(fresh.snoozeOptions(for: recurring).first?.interval, initialOptions.first?.interval)
        XCTAssertEqual(fresh.task(withKey: ordinary.key)?.isCompleted, false)
        XCTAssertFalse(fresh.isMuted(ordinary))
        XCTAssertEqual(model.pendingCount, 0)
    }

    func testInvalidRepeatingPreviewCaptureDoesNotChangeSamples() async {
        let model = TaskListModel(isPreview: true)
        await model.start()
        let keys = Set(model.groups.flatMap(\.tasks).map(\.key))
        await model.create(title: "Invalid repeat", due: nil, notes: "",
                           listID: nil, recurrence: Recurrence())
        XCTAssertNotNil(model.writeError)
        XCTAssertEqual(Set(model.groups.flatMap(\.tasks).map(\.key)), keys)
        XCTAssertEqual(model.pendingCount, 0)
    }
}
