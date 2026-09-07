import Foundation

/// Beacon's own per-task state, kept on this device only.
///
/// A JSON file rather than a database: the whole payload is a few hundred bytes
/// of counters, it is regenerable by definition, and a schema that can never
/// lose anything important does not need migrations. Losing this file costs
/// snooze positions and nothing else, because the floor beacon does not read it.
public actor Sidecar {

    private struct Record: Codable {
        var snoozeCount: Int = 0
        var snoozeAnchor: Date?
        var snoozedUntil: Date?
        var lastPlannedFire: Date?
        var explicitIntentAt: Date?
        var isMuted: Bool = false
    }

    private var records: [String: Record] = [:]
    private let url: URL

    public init(filename: String = "sidecar.json") {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Beacon", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent(filename)
        records = Self.load(from: url)
    }

    private static func load(from url: URL) -> [String: Record] {
        guard
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([String: Record].self, from: data)
        else { return [:] }
        return decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: url, options: .atomic)
    }

    public var state: [String: TaskState] {
        records.mapValues {
            TaskState(
                snoozeCount: $0.snoozeCount,
                snoozeAnchor: $0.snoozeAnchor,
                snoozedUntil: $0.snoozedUntil,
                lastPlannedFire: $0.lastPlannedFire,
                explicitIntentAt: $0.explicitIntentAt,
                isMuted: $0.isMuted
            )
        }
    }

    public func snoozeCount(for key: String) -> Int {
        records[key]?.snoozeCount ?? 0
    }

    /// Advances a task one rung. `anchor` is set only for repeating tasks,
    /// whose deferral cannot be written to the reminder itself.
    public func recordSnooze(key: String, anchor: Date?, now: Date, until: Date? = nil) {
        var record = records[key] ?? Record()
        record.snoozeCount += 1
        record.snoozeAnchor = anchor
        record.snoozedUntil = until
        record.explicitIntentAt = now
        records[key] = record
        save()
    }

    /// Marks a time the user chose by hand, which outranks quiet hours briefly.
    public func recordExplicitIntent(key: String, now: Date) {
        var record = records[key] ?? Record()
        record.explicitIntentAt = now
        record.snoozedUntil = nil
        record.snoozeAnchor = nil
        records[key] = record
        save()
    }

    public func recordPlannedFire(key: String, fire: Date) {
        var record = records[key] ?? Record()
        record.lastPlannedFire = fire
        records[key] = record
        save()
    }

    public func isMuted(_ key: String) -> Bool { records[key]?.isMuted ?? false }

    public func setMuted(_ muted: Bool, key: String) {
        var record = records[key] ?? Record()
        record.isMuted = muted
        records[key] = record
        save()
    }

    public func clear(key: String) {
        records.removeValue(forKey: key)
        save()
    }

    /// Drops rows for tasks that no longer exist, so the file cannot grow
    /// without bound.
    public func prune(keepingKeys keys: Set<String>) {
        let before = records.count
        records = records.filter { keys.contains($0.key) }
        if records.count != before { save() }
    }
}
