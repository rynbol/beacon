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
    /// Original occurrence date stays stable when a recurring occurrence moves.
    public let occurrenceDate: Date?
    public var personalNotesKey: String {
        let parts = [calendarID, identifier, occurrenceDate.map { String($0.timeIntervalSinceReferenceDate) } ?? "event"]
        return (try? JSONEncoder().encode(parts).base64EncodedString()) ?? id
    }
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
                isAllDay: Bool = false, location: String = "", notes: String = "", meetingURL: URL? = nil, occurrenceDate: Date? = nil) {
        self.occurrenceDate = occurrenceDate
        self.identifier = identifier; self.calendarID = calendarID; self.title = title
        self.start = start; self.end = end; self.isAllDay = isAllDay
        self.location = location; self.notes = CalendarNotes.plainText(notes); self.meetingURL = meetingURL
    }
    public func overlaps(_ interval: DateInterval) -> Bool {
        // Calendar all-day/multiday end dates are exclusive.
        start < interval.end && (end > interval.start || (end == start && start >= interval.start))
    }
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    /// Providers named outright. A match here always wins.
    private static let knownMeetingHosts = ["meet.google.com", "zoom.us", "zoom.com",
                                            "teams.microsoft.com", "teams.microsoft.us",
                                            "teams.live.com", "webex.com"]
    /// Words that mark a host as a place where a meeting happens. They cover
    /// providers the list above does not name, and company hosts such as
    /// meet.example.com.
    private static let meetingHostSignals = ["meet", "zoom", "teams", "webex", "huddle", "whereby",
                                             "chime", "hangout", "bluejeans", "gotomeeting",
                                             "ringcentral", "around", "video", "conference"]
    /// A link that acts on the meeting instead of opening it. "Join meeting"
    /// must never open one of these, because a click then cancels the event.
    private static let refusedInURL = ["cancel", "reschedule", "decline", "unsubscribe",
                                       "optout", "opt-out", "/support", "support.",
                                       "/privacy", "/terms", "/help"]
    private static let refusedNearby = ["cancel", "reschedule", "decline", "unsubscribe",
                                        "opt out", "opt-out"]

    private static func isKnownMeetingHost(_ host: String) -> Bool {
        knownMeetingHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// A host that carries a named provider anywhere but the end impersonates
    /// it, as `meet.google.com.attacker.test` does. The loose rule alone never
    /// catches this, because anyone can name their first label "meet".
    private static func impersonatesKnownHost(_ host: String) -> Bool {
        knownMeetingHosts.contains { host.contains($0) } && !isKnownMeetingHost(host)
    }

    /// Only the first label and the registrable tail carry a signal. Reading
    /// every label would accept a provider name buried in the middle of a host
    /// that belongs to somebody else.
    private static func hostCarriesMeetingSignal(_ host: String) -> Bool {
        guard !impersonatesKnownHost(host) else { return false }
        let labels = host.split(separator: ".").map(String.init)
        let first = labels.first ?? ""
        let tail = labels.suffix(2).joined(separator: ".")
        return meetingHostSignals.contains { first.contains($0) || tail.contains($0) }
    }

    public static func meetingLink(in text: String) -> URL? {
        guard let detector = linkDetector else { return nil }
        let lines = CalendarNotes.plainText(text).components(separatedBy: .newlines)
        var candidates: [(url: URL, nearby: String)] = []
        for (index, line) in lines.enumerated() {
            // The line above usually carries the label, as in "Join Zoom
            // Meeting" over a bare link.
            let nearby = ((index > 0 ? lines[index - 1] : "") + " " + line).lowercased()
            for match in detector.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
                guard let url = match.url, url.scheme?.lowercased() == "https" else { continue }
                candidates.append((url, nearby))
            }
        }
        let usable = candidates.filter { candidate in
            let absolute = candidate.url.absoluteString.lowercased()
            return !refusedInURL.contains(where: { absolute.contains($0) })
                && !refusedNearby.contains(where: { candidate.nearby.contains($0) })
        }
        if let known = usable.first(where: { isKnownMeetingHost($0.url.host?.lowercased() ?? "") }) {
            return known.url
        }
        return usable.first { hostCarriesMeetingSignal($0.url.host?.lowercased() ?? "") }?.url
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
