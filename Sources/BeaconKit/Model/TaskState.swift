import Foundation

/// Beacon's own per-task state: the handful of facts Apple Reminders cannot hold.
///
/// This is the pure-value mirror of the SwiftData sidecar model. It is always
/// regenerable — losing it costs a snooze count, never a task, because the floor
/// beacon does not consult it (DESIGN.md §6).
public struct TaskState: Sendable, Equatable {
    /// Rung index into `Settings.ladder`. Grows on an explicit snooze and on an
    /// ignored fire.
    public var snoozeCount: Int

    /// Set when a recurring task is snoozed. Recurring tasks cannot take a
    /// due-date write, so their deferral lives here instead.
    public var snoozeAnchor: Date?
    public var snoozedUntil: Date?

    /// The fire time the previous plan chose. Ignored-fire detection compares
    /// this against the clock.
    public var lastPlannedFire: Date?

    /// When the user last asked for a specific time by hand. Inside
    /// `Settings.explicitIntentWindow`, quiet hours do not override them:
    /// "remind me in 15 minutes" at 23:00 must mean 23:15 (DESIGN.md §5.4).
    public var explicitIntentAt: Date?

    /// The user asked this one task to stop alerting.
    ///
    /// A muted task still appears in the list. Silence here is a decision the
    /// user made and can see, which is a different thing from a task going
    /// quiet because the app lost track of it.
    public var isMuted: Bool

    public init(
        snoozeCount: Int = 0,
        snoozeAnchor: Date? = nil,
        snoozedUntil: Date? = nil,
        lastPlannedFire: Date? = nil,
        explicitIntentAt: Date? = nil,
        isMuted: Bool = false
    ) {
        self.snoozeCount = snoozeCount
        self.snoozeAnchor = snoozeAnchor
        self.snoozedUntil = snoozedUntil
        self.lastPlannedFire = lastPlannedFire
        self.explicitIntentAt = explicitIntentAt
        self.isMuted = isMuted
    }
}
