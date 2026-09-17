import Foundation

/// Day buckets for an already-filtered agenda. Calendar arithmetic preserves
/// local midnight boundaries across daylight-saving and month changes.
public struct CalendarBoardDay: Identifiable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let events: [CalendarEventSnapshot]

    public static func days(events: [CalendarEventSnapshot], range: DateInterval,
                            calendar: Calendar = .current) -> [Self] {
        var result: [Self] = []
        var day = calendar.startOfDay(for: range.start)
        while day < range.end {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
            let interval = DateInterval(start: day, end: next)
            let matches = events.filter { $0.overlaps(range) && $0.overlaps(interval) }.sorted {
                if $0.isAllDay != $1.isAllDay { return $0.isAllDay }
                if $0.start != $1.start { return $0.start < $1.start }
                return $0.id < $1.id
            }
            result.append(Self(date: day, events: matches))
            day = next
        }
        return result
    }
}
