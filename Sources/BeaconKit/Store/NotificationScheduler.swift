import Foundation
import UserNotifications

/// Applies a `Plan` to the system notification centre.
///
/// Two rules govern everything here. Every planned request is re-added on every
/// rebuild, because notification content is frozen at schedule time and a
/// renamed task would otherwise keep announcing its old title forever. And a
/// plan is only ever applied whole, so a stale request cannot outlive the task
/// that produced it.
@MainActor
public final class NotificationScheduler {

    public enum Action: String {
        case complete = "BEACON_COMPLETE"
        case snooze = "BEACON_SNOOZE"
        case snoozeLonger = "BEACON_SNOOZE_LONGER"
    }

    private let center = UNUserNotificationCenter.current()

    public init() {}

    public enum Authorization: Sendable, Equatable {
        case notAsked
        case granted
        case denied
    }

    public var authorization: Authorization {
        get async {
            switch await center.notificationSettings().authorizationStatus {
            case .authorized, .provisional, .ephemeral: return .granted
            case .notDetermined: return .notAsked
            default: return .denied
            }
        }
    }

    public var isAuthorized: Bool {
        get async { await authorization == .granted }
    }

    /// The exact authorization state, for diagnostics. "Not authorized" has
    /// several causes and they need different fixes.
    public var authorizationDescription: String {
        get async {
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .notDetermined: return "not asked yet"
            case .denied: return "denied — turn Beacon on in System Settings > Notifications"
            case .authorized: return "authorized"
            case .provisional: return "provisional (quiet delivery)"
            case .ephemeral: return "ephemeral"
            @unknown default: return "unknown"
            }
        }
    }

    public func registeredCategoryIdentifiers() async -> Set<String> {
        Set(await center.notificationCategories().map(\.identifier))
    }

    @discardableResult
    public func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Registers the action buttons. Titles are fixed, because a category is
    /// registered once for the whole app while the snooze interval changes per
    /// task — so the interval is named in the notification body instead.
    public func registerCategories() {
        let complete = UNNotificationAction(
            identifier: Action.complete.rawValue, title: "Done", options: []
        )
        let snooze = UNNotificationAction(
            identifier: Action.snooze.rawValue, title: "Snooze", options: []
        )
        let longer = UNNotificationAction(
            identifier: Action.snoozeLonger.rawValue, title: "Snooze longer", options: []
        )

        let task = UNNotificationCategory(
            identifier: Scheduler.taskCategory,
            actions: [snooze, longer, complete],
            intentIdentifiers: [],
            // A swipe-away counts as a response, which is the only way an
            // ignored notification can hand the app any execution time at all.
            options: [.customDismissAction]
        )
        let digest = UNNotificationCategory(
            identifier: Scheduler.digestCategory,
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([task, digest])
    }

    /// Replaces the pending set with exactly this plan.
    @discardableResult
    public func apply(_ plan: Plan) async -> Int {
        lastError = nil
        let pending = await center.pendingNotificationRequests()
        let wanted = plan.identifiers

        let stale = pending.map(\.identifier).filter { !wanted.contains($0) }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        var added = 0
        for notification in plan.notifications {
            guard let request = Self.request(for: notification) else { continue }
            do {
                // Adding with an existing identifier replaces that request,
                // which is how edited titles and changed intervals reach the
                // system.
                try await center.add(request)
                added += 1
            } catch {
                // Swallowing this would hide the app's whole purpose failing.
                lastError = "Could not schedule \(notification.identifier): \(error.localizedDescription)"
            }
        }
        return added
    }

    /// The most recent scheduling failure, so the window can say so instead of
    /// going quiet.
    public private(set) var lastError: String?

    public func removeAll() {
        center.removeAllPendingNotificationRequests()
    }

    public func pendingCount() async -> Int {
        await center.pendingNotificationRequests().count
    }

    public static func request(for planned: PlannedNotification) -> UNNotificationRequest? {
        let content = UNMutableNotificationContent()
        content.title = planned.title
        content.subtitle = planned.subtitle
        content.body = planned.body
        content.categoryIdentifier = planned.categoryIdentifier
        content.threadIdentifier = planned.threadIdentifier
        content.sound = .default
        // Breaks through Focus and the notification summary. A reminder the
        // user has to go looking for has already failed.
        content.interruptionLevel = .timeSensitive
        if let key = planned.taskKey { content.userInfo = ["taskKey": key] }

        let trigger: UNNotificationTrigger
        switch planned.trigger {
        case let .repeatingDaily(hour, minute):
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        case let .oneShot(date):
            guard date > Date() else { return nil }
            var components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: date
            )
            components.calendar = Calendar(identifier: .gregorian)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }

        return UNNotificationRequest(
            identifier: planned.identifier, content: content, trigger: trigger
        )
    }
}
