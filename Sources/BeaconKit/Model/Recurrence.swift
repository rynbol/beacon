import Foundation

/// A repeat rule, in the subset the editor can express.
///
/// Deliberately not `EKRecurrenceRule`: that type is immutable, so editing one
/// means building a new one anyway, and it carries cases the editor has no UI
/// for. Converting at the EventKit boundary keeps the editor and the previews
/// working on a plain value.
public struct Recurrence: Sendable, Equatable, Hashable {

    public enum Frequency: String, Sendable, CaseIterable, Hashable {
        case daily, weekly, monthly, yearly

        public var singular: String {
            switch self {
            case .daily: return "day"
            case .weekly: return "week"
            case .monthly: return "month"
            case .yearly: return "year"
            }
        }

        public var plural: String { singular + "s" }

        public var title: String {
            switch self {
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }
    }

    public enum End: Sendable, Equatable, Hashable {
        case never
        case on(Date)
        case after(Int)
    }

    public var frequency: Frequency
    public var interval: Int
    /// Weekday numbers, 1 = Sunday, matching `Calendar`. Weekly only.
    public var daysOfWeek: Set<Int>
    public var end: End

    public init(
        frequency: Frequency = .weekly,
        interval: Int = 1,
        daysOfWeek: Set<Int> = [],
        end: End = .never
    ) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.daysOfWeek = daysOfWeek
        self.end = end
    }

    // MARK: - Description

    /// The rule as a sentence, shown under the editor so the settings above it
    /// are never ambiguous.
    public func sentence(calendar: Calendar) -> String {
        var text = interval == 1
            ? "Repeats every \(frequency.singular)"
            : "Repeats every \(interval) \(frequency.plural)"

        if frequency == .weekly, !daysOfWeek.isEmpty {
            let names = daysOfWeek.sorted().map { calendar.weekdaySymbols[$0 - 1] }
            text += " on " + list(names)
        }

        switch end {
        case .never:
            break
        case let .on(date):
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "d MMMM yyyy"
            text += ", until \(formatter.string(from: date))"
        case let .after(count):
            text += ", \(count) \(count == 1 ? "time" : "times")"
        }

        return text + "."
    }

    private func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + ", and " + items[items.count - 1]
        }
    }

    // MARK: - Projection

    /// The next occurrences after a date.
    ///
    /// Shown literally in the editor, because a repeat rule is easy to
    /// misconfigure and a list of real dates is the only unambiguous proof of
    /// what it will do.
    public func nextOccurrences(
        after start: Date, count: Int, calendar: Calendar
    ) -> [Date] {
        guard count > 0 else { return [] }
        var results: [Date] = []
        var cursor = start
        var produced = 0

        // Bounded so a rule that can never match cannot spin.
        for _ in 0..<(count * 400) {
            guard results.count < count else { break }
            guard let next = step(from: cursor, calendar: calendar) else { break }
            cursor = next

            if case let .on(limit) = end, next > limit { break }

            results.append(next)
            produced += 1
            if case let .after(limit) = end, produced >= limit { break }
        }
        return results
    }

    private func step(from date: Date, calendar: Calendar) -> Date? {
        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: interval, to: date)

        case .weekly:
            guard !daysOfWeek.isEmpty else {
                return calendar.date(byAdding: .weekOfYear, value: interval, to: date)
            }
            // Walk day by day to the next selected weekday, honouring the
            // "every N weeks" gap by comparing week numbers against the anchor.
            var cursor = date
            for _ in 0..<(7 * interval + 7) {
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { return nil }
                cursor = next
                let weekday = calendar.component(.weekday, from: cursor)
                guard daysOfWeek.contains(weekday) else { continue }
                guard interval > 1 else { return cursor }
                let weeks = calendar.dateComponents(
                    [.weekOfYear],
                    from: calendar.startOfWeek(for: date),
                    to: calendar.startOfWeek(for: cursor)
                ).weekOfYear ?? 0
                if weeks % interval == 0 { return cursor }
            }
            return nil

        case .monthly:
            return calendar.date(byAdding: .month, value: interval, to: date)

        case .yearly:
            return calendar.date(byAdding: .year, value: interval, to: date)
        }
    }
}

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        dateInterval(of: .weekOfYear, for: date)?.start ?? startOfDay(for: date)
    }
}
