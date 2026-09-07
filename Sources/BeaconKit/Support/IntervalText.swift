import Foundation

/// Plain-language interval names for notification bodies and snooze chips.
///
/// One source of truth, so the button the user reads and the delay the planner
/// applies can never describe different things.
public enum IntervalText {
    public static func short(_ interval: TimeInterval) -> String {
        let seconds = Int(interval.rounded())
        if seconds % 86_400 == 0, seconds >= 86_400 {
            let days = seconds / 86_400
            return days == 1 ? "1 day" : "\(days) days"
        }
        if seconds % 3_600 == 0, seconds >= 3_600 {
            let hours = seconds / 3_600
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        let minutes = max(1, seconds / 60)
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }
}
