import Foundation

public struct CalendarTint: Sendable, Equatable, Codable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red; self.green = green; self.blue = blue
    }
    public static let ocean = CalendarTint(0.16, 0.39, 0.40)
}

public struct EventCalendarSnapshot: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let source: String
    public let tint: CalendarTint
    public init(id: String, title: String, source: String, tint: CalendarTint) {
        self.id = id; self.title = title; self.source = source; self.tint = tint
    }
}

public struct CalendarEventSnapshot: Identifiable, Sendable, Equatable {
    /// A recurring event's identifier alone does not identify its occurrence.
    public var id: String { "\(calendarID)|\(identifier)|\(start.timeIntervalSinceReferenceDate)" }
    public let identifier: String
    public let calendarID: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let location: String
    public let notes: String
    public let meetingURL: URL?
    public init(identifier: String, calendarID: String, title: String, start: Date, end: Date,
                isAllDay: Bool = false, location: String = "", notes: String = "", meetingURL: URL? = nil) {
        self.identifier = identifier; self.calendarID = calendarID; self.title = title
        self.start = start; self.end = end; self.isAllDay = isAllDay
        self.location = location; self.notes = notes; self.meetingURL = meetingURL
    }
    public func overlaps(_ interval: DateInterval) -> Bool {
        // Calendar all-day/multiday end dates are exclusive.
        start < interval.end && (end > interval.start || (end == start && start >= interval.start))
    }
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    public static func meetingLink(in text: String) -> URL? {
        guard let detector = linkDetector else { return nil }
        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap(\.url).first { url in
            guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
            return ["meet.google.com", "zoom.us", "teams.microsoft.com", "teams.live.com", "webex.com"].contains {
                host == $0 || host.hasSuffix("." + $0)
            }
        }
    }
}

public enum CalendarReadResult: Sendable {
    case permissionNeeded
    case denied
    case loaded(calendars: [EventCalendarSnapshot], events: [CalendarEventSnapshot])
}

public protocol CalendarReading: Sendable {
    func requestAccess() async -> Bool
    func read(ranges: [DateInterval], refreshSources: Bool) async throws -> CalendarReadResult
}
