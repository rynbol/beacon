import Foundation

/// How the system should be asked to fire a notification.
///
/// The two cases are not interchangeable. A repeating calendar trigger is the
/// only mechanism that keeps firing with the app never running, which is why the
/// floor is built from it and nothing else (DESIGN.md §3 C3).
public enum PlannedTrigger: Sendable, Equatable {
    /// Repeats every day at a local wall-clock time, forever, until removed.
    case repeatingDaily(hour: Int, minute: Int)
    /// Fires once at an absolute date.
    case oneShot(Date)
}

public struct PlannedNotification: Sendable, Equatable, Identifiable {
    public enum Kind: String, Sendable, Equatable {
        /// The floor. One request, present whenever any task is active, holding
        /// at any task count.
        case digest
        /// Named daily nag for one task. A quality layer above the floor.
        case taskBeacon
        /// Dense same-day escalation.
        case ladder
    }

    public let identifier: String
    public let taskKey: String?
    public let kind: Kind
    public let trigger: PlannedTrigger
    public let title: String
    public let subtitle: String
    public let body: String
    public let categoryIdentifier: String
    public let threadIdentifier: String

    public var id: String { identifier }

    public init(
        identifier: String,
        taskKey: String?,
        kind: Kind,
        trigger: PlannedTrigger,
        title: String,
        subtitle: String = "",
        body: String,
        categoryIdentifier: String,
        threadIdentifier: String
    ) {
        self.identifier = identifier
        self.taskKey = taskKey
        self.kind = kind
        self.trigger = trigger
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.categoryIdentifier = categoryIdentifier
        self.threadIdentifier = threadIdentifier
    }
}

/// The complete set of notifications that should be pending right now.
///
/// A plan is total, not incremental. The rebuild re-adds every entry and removes
/// every identifier absent from it, so a stale request cannot survive.
public struct Plan: Sendable, Equatable {
    public let notifications: [PlannedNotification]

    /// Tasks whose ladder alert the spacing sweep pushed past the drift cap.
    /// Recorded rather than silently discarded, so a bounded plan never reads
    /// as full coverage.
    public let spacingDropped: [String]

    /// Tasks active but holding no named beacon, because the beacon tier is
    /// full. The digest still covers them.
    public let beaconOverflow: [String]

    public init(
        notifications: [PlannedNotification],
        spacingDropped: [String] = [],
        beaconOverflow: [String] = []
    ) {
        self.notifications = notifications
        self.spacingDropped = spacingDropped
        self.beaconOverflow = beaconOverflow
    }

    public var identifiers: Set<String> { Set(notifications.map(\.identifier)) }
}
