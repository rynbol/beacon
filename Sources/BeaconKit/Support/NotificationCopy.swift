import Foundation

/// Stable, compact copy: no notes or relative dates that can go stale while
/// a notification waits in Notification Center.
public enum NotificationCopy {
    public static func subtitle(for task: TaskSnapshot) -> String {
        let urgency = task.urgency == .none ? "" : "\(task.urgency.title) urgency"
        let list = task.listName.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        let compactList = list.count > 48 ? String(list.prefix(47)) + "…" : list
        return [urgency, compactList].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    public static func body(urgency: Urgency, snooze: TimeInterval, followUp: Bool) -> String {
        let nudge: String
        if followUp { nudge = "Still on your list." }
        else {
            switch urgency {
            case .none, .medium: nudge = "A little nudge."
            case .low: nudge = "When you have a moment."
            case .high: nudge = "Give this one a moment."
            }
        }
        return "\(nudge) Snooze for \(IntervalText.short(snooze))."
    }
}
