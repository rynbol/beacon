import AppIntents
import BeaconKit
import Foundation

struct AddBeaconReminderIntent: AppIntent {
    static let title: LocalizedStringResource = "Add a Beacon reminder"
    static let description = IntentDescription("Create a reminder in Apple Reminders and refresh Beacon’s alerts. Include a time in the reminder text, or supply a date.")
    static let openAppWhenRun = true

    @Parameter(title: "Reminder", requestValueDialog: "What would you like to remember?")
    var reminder: String

    @Parameter(title: "When")
    var when: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$reminder) to Beacon") { \.$when }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = reminder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw CaptureError.empty }
        let model = TaskListModel.shared
        await model.start()
        let parsed = Capture.parse(text)
        await model.create(title: parsed.title, due: when ?? parsed.due,
                           notes: "", listID: nil, recurrence: nil)
        if let error = model.writeError { throw CaptureError.failed(error) }
        return .result(dialog: "Added your reminder to Beacon.")
    }

    enum CaptureError: LocalizedError {
        case empty
        case failed(String)
        var errorDescription: String? {
            switch self {
            case .empty: return "Please give the reminder a title."
            case let .failed(message): return message
            }
        }
    }
}

struct ShowBeaconRemindersIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Beacon reminders"
    static let description = IntentDescription("Open Beacon and refresh your reminders.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        await TaskListModel.shared.start()
        await TaskListModel.shared.refresh()
        return .result()
    }
}

struct BeaconShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddBeaconReminderIntent(), phrases: [
            "Add a reminder in \(.applicationName)",
            "Remember something with \(.applicationName)"
        ], shortTitle: "Add reminder", systemImageName: "plus.circle")
        AppShortcut(intent: ShowBeaconRemindersIntent(), phrases: [
            "Show my reminders in \(.applicationName)"
        ], shortTitle: "Show reminders", systemImageName: "checklist")
    }
}
