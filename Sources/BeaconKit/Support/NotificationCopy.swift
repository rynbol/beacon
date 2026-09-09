import Foundation

/// Stable, compact copy: no notes or relative dates that can go stale while
/// a notification waits in Notification Center.
public enum NotificationCopy {
    public static func title(for task: TaskSnapshot) -> String {
        // Native notification titles are plain text, so use one standard flag
        // rather than pretending the app's configurable colors can be applied.
        let flag: String
        switch task.urgency {
        case .none: return task.title
        case .low: flag = "⚐"
        case .medium: flag = "⚑"
        case .high: flag = "🚩"
        }
        return "\(task.title) \(flag)"
    }

}
