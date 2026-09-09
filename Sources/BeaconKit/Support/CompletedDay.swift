import Foundation

/// The current local day up to now, including midnight and excluding future completions.
public enum CompletedDay {
    public static func range(now: Date, calendar: Calendar = .current) -> DateInterval {
        DateInterval(start: calendar.startOfDay(for: now), end: now)
    }

    public static func contains(_ completion: Date?, now: Date, calendar: Calendar = .current) -> Bool {
        guard let completion else { return false }
        let interval = range(now: now, calendar: calendar)
        return completion >= interval.start && completion <= interval.end
    }
}
