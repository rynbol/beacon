import SwiftUI
import BeaconKit
import EventKit

@MainActor @Observable
final class CalendarModel {
    static let shared = CalendarModel()
    let feed: CalendarFeed
    private(set) var selectedDay = Calendar.current.startOfDay(for: Date())
    private(set) var hiddenIDs: Set<String>
    private(set) var colorOverrides: [String: String]
    private let defaults: UserDefaults
    private var watcher: Task<Void, Never>?
    private var debounce: Task<Void, Never>?
    private var navigationRefresh: Task<Void, Never>?
    var showingUpcoming = false
    private(set) var includeKeywords: [String]
    private(set) var excludeKeywords: [String]
    private(set) var manuallyIncludedIDs: Set<String>
    let isPreview: Bool

    init() {
        let preview = ProcessInfo.processInfo.arguments.contains("--preview") || Bundle.main.bundleIdentifier == "dev.dylan.beacon.v2.preview"
        isPreview = preview
        defaults = preview ? UserDefaults(suiteName: "dev.dylan.beacon.v2.design-preview")! : .standard
        includeKeywords = UpcomingEventFilter.labels(defaults.stringArray(forKey: "upcomingIncludeKeywords") ?? [])
        excludeKeywords = UpcomingEventFilter.labels(defaults.stringArray(forKey: "upcomingExcludeKeywords") ?? [])
        manuallyIncludedIDs = Set(defaults.stringArray(forKey: "upcomingManualEventIDs") ?? [])
        hiddenIDs = Set(defaults.stringArray(forKey: "hiddenEventCalendars") ?? [])
        colorOverrides = defaults.dictionary(forKey: "eventCalendarColors") as? [String: String] ?? [:]
        feed = CalendarFeed(reader: preview ? PreviewCalendarReader() : CalendarStore())
    }
    var week: DateInterval {
        Calendar.current.dateInterval(of: .weekOfYear, for: selectedDay)!
    }
    var days: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: week.start) }
    }
    var ranges: [DateInterval] {
        let today = Calendar.current.dateInterval(of: .day, for: .now)!
        return [week, today, UpcomingEventFilter.range(now: .now)]
    }
    var selectedEvents: [CalendarEventSnapshot] {
        feed.events(in: Calendar.current.dateInterval(of: .day, for: selectedDay)!, hiddenCalendarIDs: hiddenIDs)
    }
    var upcomingCalendars: [EventCalendarSnapshot] {
        let matches = UpcomingEventFilter(include: includeKeywords, exclude: excludeKeywords, manuallyIncludedIDs: manuallyIncludedIDs)
            .events(feed.events, now: .now)
        let ids = Set(matches.map(\.calendarID))
        return feed.calendars.filter { ids.contains($0.id) }
    }
    var upcomingEvents: [CalendarEventSnapshot] {
        UpcomingEventFilter(include: includeKeywords, exclude: excludeKeywords, manuallyIncludedIDs: manuallyIncludedIDs)
            .events(feed.events, now: .now, hiddenCalendarIDs: hiddenIDs)
    }
    var manuallyIncludedEvents: [CalendarEventSnapshot] {
        UpcomingEventFilter().events(feed.events, now: .now)
            .filter { manuallyIncludedIDs.contains($0.id) }
    }
    var availableUpcomingEvents: [CalendarEventSnapshot] {
        let shown = Set(upcomingEvents.map(\.id))
        return UpcomingEventFilter().events(feed.events, now: .now, hiddenCalendarIDs: hiddenIDs)
            .filter { !shown.contains($0.id) }
    }
    func setManuallyIncluded(_ event: CalendarEventSnapshot, included: Bool) {
        if included { manuallyIncludedIDs.insert(event.id) }
        else { manuallyIncludedIDs.remove(event.id) }
        defaults.set(manuallyIncludedIDs.sorted(), forKey: "upcomingManualEventIDs")
    }
    func setKeywords(_ values: [String], excluding: Bool) {
        let labels = UpcomingEventFilter.labels(values)
        if excluding { excludeKeywords = labels } else { includeKeywords = labels }
        defaults.set(labels, forKey: excluding ? "upcomingExcludeKeywords" : "upcomingIncludeKeywords")
        refreshAfterNavigation()
    }
    var upcomingToday: [CalendarEventSnapshot] {
        feed.events(in: Calendar.current.dateInterval(of: .day, for: .now)!, hiddenCalendarIDs: hiddenIDs)
            .filter { $0.isAllDay || $0.end > .now }
    }
    func start() async {
        if watcher == nil, !isPreview {
            watcher = Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged) {
                    guard !Task.isCancelled, let self else { return }
                    self.debounce?.cancel()
                    self.debounce = Task { [weak self] in
                        do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                        await self?.refresh(requestSourceRefresh: false)
                    }
                }
            }
        }
        await refresh()
    }
    func refresh(requestSourceRefresh: Bool = true) async {
        await feed.refresh(ranges: ranges, requestSourceRefresh: requestSourceRefresh)
    }
    /// Collapse rapid clicks into one read for the final visible date.
    func refreshAfterNavigation() {
        navigationRefresh?.cancel()
        navigationRefresh = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
            guard let self else { return }
            await self.refresh()
        }
    }
    func selectDay(_ day: Date) {
        selectedDay = Calendar.current.startOfDay(for: day)
        refreshAfterNavigation()
    }
    func connect() async { await feed.connect(ranges: ranges) }
    func toggleCalendar(_ id: String) {
        if hiddenIDs.contains(id) { hiddenIDs.remove(id) } else { hiddenIDs.insert(id) }
        defaults.set(Array(hiddenIDs), forKey: "hiddenEventCalendars")
        refreshAfterNavigation()
    }
    func setColor(_ accent: Accent?, for id: String) {
        colorOverrides[id] = accent?.rawValue
        defaults.set(colorOverrides, forKey: "eventCalendarColors")
    }
    func color(for id: String) -> Color {
        if let name = colorOverrides[id], let accent = Accent(rawValue: name) { return accent.color }
        guard let tint = feed.calendars.first(where: { $0.id == id })?.tint else { return Accent.ocean.color }
        return Color(red: tint.red, green: tint.green, blue: tint.blue)
    }
    func source(for id: String) -> EventCalendarSnapshot? { feed.calendars.first { $0.id == id } }
}

private actor PreviewCalendarReader: CalendarReading {
    func requestAccess() -> Bool { true }
    func read(ranges: [DateInterval], refreshSources: Bool) -> CalendarReadResult {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let work = EventCalendarSnapshot(id: "preview-work", title: "Work", source: "Google", tint: .ocean)
        let personal = EventCalendarSnapshot(id: "preview-personal", title: "Personal", source: "iCloud", tint: CalendarTint(0.65, 0.33, 0.17))
        let events = (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            let start = calendar.date(bySettingHour: offset == 0 ? 23 : 10, minute: 30, second: 0, of: day)!
            return CalendarEventSnapshot(identifier: "sample-\(offset)", calendarID: offset % 2 == 0 ? work.id : personal.id,
                title: ["Design review", "Dentist", "Weekly planning", "Lunch with Maya", "Project demo", "Coffee with Sam", "Sunday walk"][offset],
                start: offset == 6 ? day : start,
                end: offset == 6 ? calendar.date(byAdding: .day, value: 1, to: day)! : start.addingTimeInterval(1800),
                isAllDay: offset == 6,
                location: offset % 2 == 0 ? "Google Meet" : "Downtown",
                notes: offset == 0 ? "Review the latest screens and capture the decisions.\n\nAgenda\n• Walk through the reminder flow\n• Check the calendar layouts\n• Review keyboard access\n• Agree on follow-ups\n\nBring any open questions. These are sample notes for testing the expanded event layout." : "",
                meetingURL: offset % 2 == 0 ? URL(string: "https://meet.google.com/example-preview") : nil)
        }
        return .loaded(calendars: [work, personal], events: events.filter { event in ranges.contains { event.overlaps($0) } })
    }
}
