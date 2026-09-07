import Foundation

/// Every tunable the planner reads. Held in one struct so a plan is a function
/// of its arguments alone, and so the M8 soak can retune the app without
/// touching scheduler code.
public struct Settings: Sendable, Equatable {
    /// Snooze intervals by rung. User-editable: this is the second-largest
    /// complaint against the app Beacon is modelled on (DESIGN.md §2).
    public var ladder: [TimeInterval]

    /// Quiet window as local hours, `[start, end)` crossing midnight.
    public var quietStartHour: Int
    public var quietEndHour: Int

    /// Local hour holding the digest beacon; per-task beacons follow it.
    public var digestHour: Int

    /// Working ceiling on pending notification requests. The system cap is 64,
    /// the eviction policy above it is undocumented, and M2 measures the real
    /// number — so this stays well clear of it (DESIGN.md §3 C1).
    public var slotBudget: Int

    public var maxTaskBeacons: Int
    public var maxLadderPerTask: Int

    /// Minimum gap between two one-shot alerts.
    public var spacingSeconds: TimeInterval

    /// How far the spacing sweep may push an alert before dropping it instead.
    /// A dropped alert is not a lost task: the floor beacon still covers it.
    public var maxDriftSeconds: TimeInterval

    /// Quantum for past-due and undated fire times. `now` reaches the planner
    /// only through this grid, which is what makes two rebuilds seconds apart
    /// produce identical plans (DESIGN.md §5.1).
    public var gridSeconds: TimeInterval

    /// How long an explicit user-chosen time outranks quiet hours.
    public var explicitIntentWindow: TimeInterval

    /// Ladder rungs further out than this are not worth a slot today.
    public var ladderHorizon: TimeInterval

    /// A task due further ahead than this is a Someday task: kept, listed, and
    /// deliberately not nagged about. Anything nearer is ordinary work.
    public var somedayHorizon: TimeInterval

    public static let `default` = Settings(
        ladder: [15 * 60, 30 * 60, 3600, 2 * 3600, 4 * 3600, 8 * 3600, 24 * 3600],
        quietStartHour: 22,
        quietEndHour: 8,
        digestHour: 9,
        slotBudget: 50,
        maxTaskBeacons: 30,
        maxLadderPerTask: 3,
        spacingSeconds: 90,
        maxDriftSeconds: 30 * 60,
        gridSeconds: 15 * 60,
        explicitIntentWindow: 10 * 60,
        ladderHorizon: 36 * 3600,
        somedayHorizon: 365 * 86_400
    )

    public init(
        ladder: [TimeInterval],
        quietStartHour: Int,
        quietEndHour: Int,
        digestHour: Int,
        slotBudget: Int,
        maxTaskBeacons: Int,
        maxLadderPerTask: Int,
        spacingSeconds: TimeInterval,
        maxDriftSeconds: TimeInterval,
        gridSeconds: TimeInterval,
        explicitIntentWindow: TimeInterval,
        ladderHorizon: TimeInterval,
        somedayHorizon: TimeInterval = 365 * 86_400
    ) {
        self.ladder = ladder
        self.quietStartHour = quietStartHour
        self.quietEndHour = quietEndHour
        self.digestHour = digestHour
        self.slotBudget = slotBudget
        self.maxTaskBeacons = maxTaskBeacons
        self.maxLadderPerTask = maxLadderPerTask
        self.spacingSeconds = spacingSeconds
        self.maxDriftSeconds = maxDriftSeconds
        self.gridSeconds = gridSeconds
        self.explicitIntentWindow = explicitIntentWindow
        self.ladderHorizon = ladderHorizon
        self.somedayHorizon = somedayHorizon
    }

    /// The date a Someday task gets. Far enough out that no scheduler tier will
    /// ever reach it, and still a real date so the reminder stays valid in
    /// Apple Reminders and means something there too.
    public static func somedayDate(from now: Date, calendar: Calendar) -> Date {
        let far = calendar.date(byAdding: .year, value: 10, to: now) ?? now.addingTimeInterval(10 * 365 * 86_400)
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: far) ?? far
    }

    /// Snooze interval for a rung, clamped to the last one.
    public func interval(forSnoozeCount n: Int) -> TimeInterval {
        guard !ladder.isEmpty else { return 15 * 60 }
        return ladder[min(max(n, 0), ladder.count - 1)]
    }
}
