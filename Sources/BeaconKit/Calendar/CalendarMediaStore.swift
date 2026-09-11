import Foundation
import CryptoKit
import Observation
import UniformTypeIdentifiers

/// Private copies, separate from both EventKit and the text-note file.
@MainActor @Observable
public final class CalendarMediaStore {
    private let root: URL
    private var revision = 0
    public init(root: URL) { self.root = root }

    private func directory(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent(digest, isDirectory: true)
    }

    public func files(for key: String) -> [URL] {
        _ = revision
        return ((try? FileManager.default.contentsOfDirectory(at: directory(for: key), includingPropertiesForKeys: nil)) ?? [])
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public func refresh() { revision += 1 }

    public func add(_ source: URL, for key: String) async throws {
        let folder = directory(for: key)
        try await Task.detached {
            let access = source.startAccessingSecurityScopedResource()
            defer { if access { source.stopAccessingSecurityScopedResource() } }
            let values = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentTypeKey])
            guard values.isRegularFile == true,
                  let type = values.contentType, type.conforms(to: .image) || type.conforms(to: .movie) else {
                throw MediaError.unsupported
            }
            guard (values.fileSize ?? Int.max) <= 100 * 1024 * 1024 else { throw MediaError.tooLarge }
            let manager = FileManager.default
            try manager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let target = folder.appendingPathComponent(UUID().uuidString + "_" + source.lastPathComponent)
            let temporary = folder.appendingPathComponent("." + UUID().uuidString)
            defer { try? manager.removeItem(at: temporary) }
            try manager.copyItem(at: source, to: temporary)
            try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
            try manager.moveItem(at: temporary, to: target)
        }.value
        revision += 1
    }

    public enum MediaError: LocalizedError {
        case unsupported, tooLarge
        public var errorDescription: String? {
            switch self {
            case .unsupported: "Choose an image or video file."
            case .tooLarge: "Choose a file smaller than 100 MB."
            }
        }
    }
}
