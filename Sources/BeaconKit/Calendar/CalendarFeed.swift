import Foundation
import Observation

/// Coalesces refreshes and discards results for a date range the user has left.
/// A failed read keeps the last successful events and exposes the failure.
@MainActor @Observable
public final class CalendarFeed {
    public enum Access: Sendable { case notDetermined, granted, denied }
    public private(set) var access: Access = .notDetermined
    public private(set) var calendars: [EventCalendarSnapshot] = []
    public private(set) var events: [CalendarEventSnapshot] = []
    public private(set) var lastRead: Date?
    public private(set) var error: String?
    public private(set) var isRefreshing = false
    private let reader: any CalendarReading
    private var revision = 0
    private var requestedRanges: [DateInterval] = []
    private var pendingSync = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    public init(reader: any CalendarReading) { self.reader = reader }
    public func connect(ranges: [DateInterval]) async {
        _ = await reader.requestAccess()
        await refresh(ranges: ranges)
    }
    public func refresh(ranges: [DateInterval], requestSourceRefresh: Bool = true) async {
        revision += 1
        requestedRanges = ranges
        pendingSync = pendingSync || requestSourceRefresh
        if isRefreshing {
            await withCheckedContinuation { waiters.append($0) }
            return
        }
        isRefreshing = true
        repeat {
            let token = revision
            let sync = pendingSync
            pendingSync = false
            do {
                let result = try await reader.read(ranges: requestedRanges, refreshSources: sync)
                // Re-read for the latest navigation request before publishing.
                if token == revision {
                    switch result {
                    case .permissionNeeded:
                        access = .notDetermined; calendars = []; events = []; lastRead = nil
                    case .denied:
                        access = .denied; calendars = []; events = []; lastRead = nil
                    case let .loaded(calendars, events):
                        access = .granted
                        if self.calendars != calendars { self.calendars = calendars }
                        let sortedEvents = events.sorted {
                            if $0.start != $1.start { return $0.start < $1.start }
                            return $0.id < $1.id
                        }
                        if self.events != sortedEvents { self.events = sortedEvents }
                        lastRead = .now
                    }
                    error = nil
                }
            } catch {
                if token == revision { self.error = error.localizedDescription }
            }
            if token == revision { break }
        } while true
        isRefreshing = false
        let waiting = waiters; waiters.removeAll()
        waiting.forEach { $0.resume() }
    }
    /// Includes hidden calendars so their events can be switched back on.
    public func calendarsWithEvents(in range: DateInterval) -> [EventCalendarSnapshot] {
        let ids = Set(events.filter { $0.overlaps(range) }.map(\.calendarID))
        return calendars.filter { ids.contains($0.id) }
    }

    public func events(in range: DateInterval, hiddenCalendarIDs: Set<String> = []) -> [CalendarEventSnapshot] {
        events.filter { !hiddenCalendarIDs.contains($0.calendarID) && $0.overlaps(range) }.sorted {
            if $0.isAllDay != $1.isAllDay { return $0.isAllDay }
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.id < $1.id
        }
    }
}
