import Foundation
import Observation

/// Local-only persistence. This type has no EventKit or network access.
@MainActor @Observable
public final class CalendarPersonalNotesStore {
    private let url: URL
    private var saved: [String: String] = [:]
    private var drafts: [String: String] = [:]
    private var errors: [String: String] = [:]
    private var loadError: String?

    public init(url: URL) {
        self.url = url
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                saved = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
            }
        } catch {
            loadError = "Existing personal notes could not be read. Changes have not been saved."
        }
    }

    public func text(for key: String) -> String { drafts[key] ?? saved[key] ?? "" }
    public func error(for key: String) -> String? { loadError ?? errors[key] }

    /// A small synchronous atomic write avoids debounce/disappearance races.
    /// Failed edits remain in memory when the user switches cards or sections.
    public func set(_ text: String, for key: String) {
        drafts[key] = text
        if loadError != nil {
            // A retry may recover after a permissions or disk problem is fixed.
            // Do not replace a damaged file with an empty dictionary.
            do {
                saved = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
                loadError = nil
            } catch { return }
        }
        var updated = saved
        if text.isEmpty { updated.removeValue(forKey: key) }
        else { updated[key] = text }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(updated).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            saved = updated
            drafts.removeValue(forKey: key)
            errors.removeValue(forKey: key)
        } catch {
            errors[key] = "Couldn’t save this note. Your edit is kept open in Beacon; try again before quitting."
        }
    }
}
