import Foundation

public struct UpcomingEventFilter: Sendable {
    public var include: [String]
    public var exclude: [String]
    public var manuallyIncludedIDs: Set<String>
    public init(include: [String] = [], exclude: [String] = [], manuallyIncludedIDs: Set<String> = []) {
        self.include = Self.labels(include)
        self.exclude = Self.labels(exclude)
        self.manuallyIncludedIDs = manuallyIncludedIDs
    }
    private static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
    public static func labels(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert(folded($0)).inserted }
    }
    public func matches(_ event: CalendarEventSnapshot) -> Bool {
        if manuallyIncludedIDs.contains(event.id) { return true }
        let title = Self.folded(event.title)
        return (include.isEmpty || include.contains { title.contains(Self.folded($0)) })
            && !exclude.contains { title.contains(Self.folded($0)) }
    }
    public static func range(now: Date, calendar: Calendar = .current) -> DateInterval {
        DateInterval(start: now, end: calendar.date(byAdding: .day, value: 7, to: now)!)
    }
    public func events(_ events: [CalendarEventSnapshot], now: Date, calendar: Calendar = .current,
                       hiddenCalendarIDs: Set<String> = []) -> [CalendarEventSnapshot] {
        let range = Self.range(now: now, calendar: calendar)
        return events.filter {
            !hiddenCalendarIDs.contains($0.calendarID) && $0.overlaps(range) && matches($0)
        }.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }
}
