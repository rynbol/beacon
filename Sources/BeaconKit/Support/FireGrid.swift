import Foundation

/// Quantizes fire times so that the current instant cannot leak into a plan.
///
/// This is the fix for the defect that made v1's "pure" planner impure: with
/// `fire = max(due, now)`, every rebuild moved a past-due task's alert a little
/// further into the future, so a frequently-rebuilding app could starve exactly
/// the tasks it most needed to surface, and two devices rebuilding seconds apart
/// disagreed about the plan.
public enum FireGrid {
    /// The first grid boundary strictly after `now`.
    ///
    /// Every instant inside one grid window maps to the same boundary, so any
    /// number of rebuilds during that window produce identical output.
    public static func nextBoundary(
        after now: Date,
        calendar: Calendar,
        gridSeconds: TimeInterval
    ) -> Date {
        precondition(gridSeconds > 0, "grid must be positive")
        let startOfDay = calendar.startOfDay(for: now)
        let elapsed = now.timeIntervalSince(startOfDay)
        let index = (elapsed / gridSeconds).rounded(.down)
        let candidate = startOfDay.addingTimeInterval((index + 1) * gridSeconds)
        // A backwards DST shift can put the computed boundary behind `now`;
        // walk forward until it is genuinely in the future.
        var result = candidate
        while result <= now {
            result = result.addingTimeInterval(gridSeconds)
        }
        return result
    }

    /// Whether a local wall-clock hour falls inside the quiet window, which may
    /// cross midnight.
    public static func isQuiet(hour: Int, startHour: Int, endHour: Int) -> Bool {
        if startHour == endHour { return false }
        if startHour < endHour { return hour >= startHour && hour < endHour }
        return hour >= startHour || hour < endHour
    }

    /// Moves a fire out of the quiet window to the morning that follows it.
    public static func applyQuietHours(
        to fire: Date,
        calendar: Calendar,
        startHour: Int,
        endHour: Int
    ) -> Date {
        let hour = calendar.component(.hour, from: fire)
        guard isQuiet(hour: hour, startHour: startHour, endHour: endHour) else { return fire }

        var day = calendar.startOfDay(for: fire)
        // Late-evening fires belong to the next morning; small-hours fires to
        // the morning already underway.
        if hour >= startHour, startHour > endHour {
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        }
        return calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: day) ?? fire
    }
}
