import Foundation
import EventKit
import CoreGraphics

/// EventKit objects remain on one actor. The UI only receives immutable values.
/// This feature reads events; event alerts and event edits remain in Calendar.
public actor CalendarStore: CalendarReading {
    private var cachedStore: EKEventStore?
    private var lastSourceRefresh: Date?
    private var store: EKEventStore {
        if let cachedStore { return cachedStore }
        let value = EKEventStore(); cachedStore = value; return value
    }
    public init() {}
    public func requestAccess() async -> Bool {
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess { return true }
        return (try? await store.requestFullAccessToEvents()) ?? false
    }
    public func read(ranges: [DateInterval], refreshSources: Bool) async throws -> CalendarReadResult {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: return .permissionNeeded
        case .fullAccess: break
        default: return .denied
        }
        let store = store
        // Asks EventKit to refresh its sources; provider sync can finish later.
        // EKEventStoreChanged triggers another read when those changes arrive.
        if refreshSources, lastSourceRefresh.map({ Date().timeIntervalSince($0) >= 5 }) ?? true {
            lastSourceRefresh = .now
            store.refreshSourcesIfNecessary()
        }
        let calendars = store.calendars(for: .event)
        let sources: [EventCalendarSnapshot] = calendars.map { calendar -> EventCalendarSnapshot in
            let converted = calendar.cgColor?.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)
            let components = converted?.components ?? [0.16, 0.39, 0.40, 1]
            let tint = components.count >= 3 ? CalendarTint(Double(components[0]), Double(components[1]), Double(components[2])) : .ocean
            return EventCalendarSnapshot(id: calendar.calendarIdentifier, title: calendar.title,
                                         source: calendar.source.title, tint: tint)
        }
        let sortedSources = sources.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        guard !calendars.isEmpty else { return .loaded(calendars: [], events: []) }
        var seen = Set<String>()
        var snapshots: [CalendarEventSnapshot] = []
        for range in ranges {
            let predicate = store.predicateForEvents(withStart: range.start, end: range.end, calendars: calendars)
            for event in store.events(matching: predicate) where event.status != .canceled {
                guard let start = event.startDate, let end = event.endDate, let calendarID = event.calendar?.calendarIdentifier else { continue }
                let linkText = [event.url?.absoluteString, event.notes, event.location].compactMap { $0 }.joined(separator: "\n")
                let snapshot = CalendarEventSnapshot(identifier: event.eventIdentifier ?? event.calendarItemIdentifier,
                    calendarID: calendarID, title: event.title ?? "Untitled event", start: start, end: end,
                    isAllDay: event.isAllDay, location: event.location ?? "", notes: event.notes ?? "",
                    meetingURL: CalendarEventSnapshot.meetingLink(in: linkText))
                if seen.insert(snapshot.id).inserted { snapshots.append(snapshot) }
            }
        }
        return .loaded(calendars: sortedSources, events: snapshots)
    }
}
