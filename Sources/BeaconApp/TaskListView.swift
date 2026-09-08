import SwiftUI
import BeaconKit

private enum Destination: String, CaseIterable, Identifiable {
    case all = "All reminders", today = "Today", calendar = "Calendar", upcoming = "Upcoming", someday = "Someday", done = "Completed"
    var id: Self { self }
    var glyph: BeaconGlyph.Kind {
        switch self {
        case .all: return .inbox
        case .today: return .today
        case .calendar: return .calendar
        case .upcoming: return .upcoming
        case .someday: return .someday
        case .done: return .completed
        }
    }
    var subtitle: String {
        switch self {
        case .all: return "All your reminders, in one place."
        case .today: return "What needs your attention today."
        case .calendar: return "Everything u have"
        case .upcoming: return "Scheduled for the days ahead."
        case .someday: return "Saved for when you’re ready."
        case .done: return "Finished in the last hour."
        }
    }
}

struct TaskListView: View {
    var model: TaskListModel
    private var calendarModel: CalendarModel { .shared }
    @State private var editing: EditorTarget?
    @State private var showingSettings = false
    @State private var showingSchedule = false
    @State private var destination: Destination = .all
    @State private var search = ""
    @State private var capture = ""
    @State private var capturing = false
    @FocusState private var captureFocused: Bool
    @FocusState private var searchFocused: Bool

    private var allTasks: [TaskSnapshot] { model.groups.flatMap(\.tasks) }
    private func matches(_ task: TaskSnapshot, destination: Destination) -> Bool {
        let section = Sections.bucket(task, now: .now, calendar: .current)
        switch destination {
        case .calendar: return false
        case .all: return !task.isCompleted
        case .today: return section == .today
        case .upcoming: return [.tomorrow, .next7, .next30, .later].contains(section)
        case .someday: return section == .someday
        case .done: return task.isCompleted
        }
    }
    private var visibleTasks: [TaskSnapshot] {
        allTasks.filter { task in
            matches(task, destination: destination) && (search.isEmpty ||
                task.title.localizedCaseInsensitiveContains(search) ||
                task.notes.localizedCaseInsensitiveContains(search) ||
                task.listName.localizedCaseInsensitiveContains(search))
        }
    }
    private struct DisplayGroup: Identifiable {
        let id: String
        let title: String
        let tasks: [TaskSnapshot]
    }
    private var displayGroups: [DisplayGroup] {
        if model.grouping == .list {
            return Sections.groupByList(visibleTasks, now: .now, calendar: .current).enumerated().map {
                DisplayGroup(id: "list-\($0.offset)", title: $0.element.name, tasks: $0.element.tasks)
            }
        }
        return Sections.group(visibleTasks, now: .now, calendar: .current).map {
            DisplayGroup(id: "time-\($0.id)", title: $0.section == .today ? "Today" : $0.section.title, tasks: $0.tasks)
        }
    }
    private var accent: Color { model.accent.color }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Palette.hairline).frame(width: 1)
            VStack(alignment: .leading, spacing: 0) {
                topbar
                heading
                banner
                if destination == .calendar {
                    CalendarWorkspace(model: calendarModel, search: search) { editing = .followUp($0) }
                } else {
                    quickCapture
                    if destination == .today {
                        GeometryReader { geometry in
                            if geometry.size.width >= 740 {
                                HStack(alignment: .top, spacing: 0) {
                                    content
                                    ScrollView {
                                        TodayCalendarAgenda(model: calendarModel, showCalendar: { destination = .calendar }, followUp: { editing = .followUp($0) })
                                    }.frame(width: 230).padding(.trailing, 32).padding(.leading, 12)
                                }
                            } else {
                                VStack(spacing: 18) {
                                    TodayCalendarAgenda(model: calendarModel, showCalendar: { destination = .calendar }, followUp: { editing = .followUp($0) }, maxEvents: 1)
                                        .padding(.horizontal, 32)
                                    content
                                }
                            }
                        }
                    } else { content }
                }
                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.wash)
        }
        .foregroundStyle(Palette.ink)
        .disabled(editing != nil || showingSettings)
        .accessibilityHidden(editing != nil || showingSettings)
        .overlay {
            if let editing {
                TaskEditor(model: model, target: editing) { self.editing = nil }
                    .id(editing.id)
            }
            if showingSettings {
                SettingsView(model: model) { showingSettings = false }
            }
        }
        .sheet(isPresented: $showingSchedule) {
            if let plan = model.plan { ScheduleView(plan: plan, accent: accent) }
        }
        .task { if !E2ECheck.isHarnessRun { await calendarModel.start() } }
        .onChange(of: destination) { _, _ in
            calendarModel.refreshAfterNavigation()
        }
        .frame(minWidth: 760, minHeight: 580)
        .background {
            Button("Search reminders") { searchFocused = true }.keyboardShortcut("f").hidden()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BeaconGlyph(kind: .beacon).frame(width: 28, height: 28).foregroundStyle(accent)
                Text("beacon").font(.system(size: 25, weight: .medium, design: .serif)).tracking(-0.8)
            }
            .padding(.horizontal, 24).padding(.top, 29).padding(.bottom, 38)
            Text("REMINDERS").font(.system(size: 10, weight: .semibold)).tracking(1.6)
                .foregroundStyle(Palette.secondary).padding(.horizontal, 25).padding(.bottom, 12)
            ForEach(Destination.allCases) { item in
                Button {
                    if destination == item { calendarModel.refreshAfterNavigation() }
                    destination = item
                } label: {
                    HStack(spacing: 11) {
                        BeaconGlyph(kind: item.glyph).frame(width: 20, height: 20)
                        Text(item.rawValue).font(.system(size: 13, weight: destination == item ? .semibold : .regular))
                        Spacer()
                        if item != .calendar {
                            Text("\(allTasks.filter { matches($0, destination: item) }.count)")
                                .font(.system(size: 11, weight: .medium)).monospacedDigit()
                        }
                    }
                    .foregroundStyle(destination == item ? accent : Palette.secondary)
                    .padding(.horizontal, 12).frame(height: 42)
                    .background(destination == item ? accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 9))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).padding(.horizontal, 12).padding(.bottom, 3)
            }
            if destination == .calendar || destination == .today {
                let day = destination == .calendar ? calendarModel.selectedDay : Date.now
                let calendars = calendarModel.feed.calendarsWithEvents(in: Calendar.current.dateInterval(of: .day, for: day)!)
                if !calendars.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(calendars) { calendar in
                                Button { calendarModel.toggleCalendar(calendar.id) } label: {
                                    HStack(spacing: 8) {
                                        Circle().fill(calendarModel.color(for: calendar.id)).frame(width: 7, height: 7)
                                        Text(calendar.title).lineLimit(1)
                                        Spacer()
                                        if calendarModel.hiddenIDs.contains(calendar.id) { Image(systemName: "eye.slash") }
                                    }.font(.system(size: 11)).foregroundStyle(Palette.secondary)
                                        .frame(minHeight: 28).contentShape(Rectangle())
                                }.buttonStyle(.plain).help("\(calendar.title) · \(calendar.source)")
                            }
                        }.padding(.horizontal, 25)
                    }.frame(maxHeight: CGFloat(min(calendars.count, 4) * 38))
                        .padding(.top, 22)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                Text("New reminder")
                Spacer()
                Text("⌘N").monospaced()
            }.font(.system(size: 11)).foregroundStyle(Palette.secondary)
                .padding(.horizontal, 25).padding(.bottom, 16)
            Button { showingSettings = true } label: {
                Label("Settings", systemImage: "slider.horizontal.3")
                    .font(.system(size: 13)).foregroundStyle(Palette.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }.buttonStyle(.plain).keyboardShortcut(",").padding(.horizontal, 12).padding(.bottom, 16)
        }.frame(width: 210).background(Palette.band.opacity(0.65))
    }

    private var topbar: some View {
        HStack {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: 12)).foregroundStyle(Palette.secondary)
            Spacer()
            Button {
                Task { await model.refresh(); await calendarModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise").frame(width: 28, height: 28)
            }.buttonStyle(.plain).help("Refresh reminders and Calendar · ⌘R").accessibilityLabel("Refresh")
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                TextField("Search", text: $search).textFieldStyle(.plain).focused($searchFocused)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("Clear search")
                }
            }.font(.system(size: 12)).foregroundStyle(Palette.secondary)
                .padding(9).frame(width: 170).background(Palette.card, in: RoundedRectangle(cornerRadius: 8))
        }.padding(.horizontal, 32).padding(.top, 21)
    }

    private var heading: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 9) {
                Text(destination.rawValue).font(.system(size: 30, weight: .semibold)).tracking(-0.9)
                Text(destination.subtitle).font(.system(size: 12)).foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: 12)
            Button { editing = .new(dictate: false, defaultDue: newReminderDue) } label: {
                Label("New reminder", systemImage: "plus").font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .foregroundStyle(.white).background(accent, in: RoundedRectangle(cornerRadius: 9))
            }.buttonStyle(.plain).keyboardShortcut("n")
        }.padding(.horizontal, 32).padding(.top, 31).padding(.bottom, 24)
    }

    private var quickCapture: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 11) {
                Image(systemName: "plus.circle").font(.system(size: 19)).foregroundStyle(accent)
                TextField("Remind me to…", text: $capture).textFieldStyle(.plain)
                    .font(.system(size: 14)).focused($captureFocused).onSubmit(addQuickReminder)
                    .accessibilityLabel("Quick reminder")
                Button { editing = .new(dictate: true, defaultDue: newReminderDue) } label: { Image(systemName: "mic") }
                    .buttonStyle(.plain)
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                    .help("Dictate a reminder · ⌘⇧M")
                    .accessibilityLabel("Dictate a reminder")
                Button(action: addQuickReminder) {
                    Image(systemName: "return").font(.system(size: 12)).padding(6)
                        .background(Palette.band, in: RoundedRectangle(cornerRadius: 5))
                }.buttonStyle(.plain).disabled(capture.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || capturing)
                    .accessibilityLabel("Add reminder")
            }.padding(16).background(Palette.card, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(captureFocused ? accent.opacity(0.55) : Palette.hairline, lineWidth: 1))
            Text(capture.isEmpty ? "Try “water the plants tomorrow at 9am”" : capturePreview)
                .font(.system(size: 11)).foregroundStyle(Palette.secondary).padding(.leading, 3)
        }.padding(.horizontal, 32).padding(.bottom, 24)
    }

    private var newReminderDue: Date? {
        let now = Date.now
        switch destination {
        case .today: return now
        case .upcoming: return DueChip.tomorrow.date(from: now, calendar: .current)
        case .calendar:
            if Calendar.current.isDate(calendarModel.selectedDay, inSameDayAs: now) { return now }
            return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: calendarModel.selectedDay)
        case .all, .someday, .done: return nil
        }
    }

    private var capturePreview: String {
        let parsed = Capture.parse(capture)
        if let due = parsed.due ?? newReminderDue { return "\(parsed.title)  ·  \(due.formatted(date: .abbreviated, time: .shortened))" }
        return "No date set · added to Someday"
    }
    private func addQuickReminder() {
        guard !capturing, !capture.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let parsed = Capture.parse(capture)
        let due = parsed.due ?? newReminderDue
        capturing = true
        Task {
            await model.create(title: parsed.title, due: due, notes: "", listID: nil, recurrence: nil)
            if model.writeError == nil { capture = "" }
            capturing = false
        }
    }

    @ViewBuilder private var banner: some View {
        if let refusal = model.refusal {
            NoticeBar(title: refusal.headline, detail: refusal.detail, dismiss: nil)
                .padding(.horizontal, 32).padding(.bottom, 16)
        } else if let error = model.writeError {
            NoticeBar(title: "Couldn’t save that change", detail: error) { model.dismissWriteError() }
                .padding(.horizontal, 32).padding(.bottom, 16)
        } else if let error = model.scheduleError {
            NoticeBar(title: "Some alerts need attention", detail: error, dismiss: nil)
                .padding(.horizontal, 32).padding(.bottom, 16)
        }
    }

    @ViewBuilder private var content: some View {
        if model.access == .denied {
            AccessDeniedView(accent: accent)
        } else if model.lastRefresh == nil {
            VStack { Spacer(); ProgressView("Loading your reminders…"); Spacer() }.frame(maxWidth: .infinity)
        } else if visibleTasks.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Group {
                    if search.isEmpty { BeaconGlyph(kind: destination.glyph) }
                    else { Image(systemName: "magnifyingglass").font(.system(size: 24)) }
                }.frame(width: 32, height: 32).foregroundStyle(accent).padding(.bottom, 8)
                Text(search.isEmpty ? "No reminders here" : "No matching reminders")
                    .font(.system(size: 23, design: .serif))
                Text(search.isEmpty ? "Use New reminder or ⌘N to add one." : "Try another title, note, or list name.")
                    .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                Spacer()
            }.frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(displayGroups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Text(group.title)
                                    .font(.system(size: 12, weight: .semibold))
                                Text("\(group.tasks.count)").font(.system(size: 11)).monospacedDigit()
                                    .foregroundStyle(Palette.tertiary)
                                Spacer()
                            }.foregroundStyle(Palette.secondary)
                            VStack(spacing: 0) {
                                ForEach(Array(group.tasks.enumerated()), id: \.element.id) { index, task in
                                    TaskRow(task: task, accent: accent, isMuted: model.isMuted(task),
                                            snoozeOptions: model.snoozeOptions(for: task), isLast: index == group.tasks.count - 1) {
                                        Task { await model.toggleCompleted(task) }
                                    } snooze: { interval in
                                        Task { await model.snooze(task, by: interval) }
                                    } mute: {
                                        Task { await model.toggleMuted(task) }
                                    } edit: { editing = .existing(task) }
                                }
                            }
                            .overlay(alignment: .top) { Rectangle().fill(Palette.hairline).frame(height: 1) }
                        }
                    }
                }.padding(.horizontal, 32).padding(.bottom, 24)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Image(systemName: model.access == .granted ? "checkmark.icloud" : "icloud.slash")
            Text(model.isPreview ? "Design preview · sample reminders" : model.access == .granted ? "Connected to Apple Reminders" : "Apple Reminders isn’t connected")
            Spacer()
            Button { showingSettings = true } label: {
                Label(model.isAlerting ? "Alerts on" : "Alerts off", systemImage: model.isAlerting ? "bell" : "bell.slash")
            }.buttonStyle(.plain)
            if model.plan != nil {
                Button { showingSchedule = true } label: { Image(systemName: "info.circle") }
                    .buttonStyle(.plain).help("View notification schedule")
            }
        }.font(.system(size: 10)).foregroundStyle(Palette.secondary)
            .padding(.horizontal, 32).padding(.vertical, 15)
            .overlay(alignment: .top) { Rectangle().fill(Palette.hairline).frame(height: 1) }
    }
}

/// What the editor sheet is currently editing.
enum EditorTarget: Identifiable {
    case new(dictate: Bool, defaultDue: Date?)
    case followUp(CalendarEventSnapshot)
    case existing(TaskSnapshot)

    var id: String {
        switch self {
        case .new: return "new"
        case let .followUp(event): return "followup-" + event.id
        case let .existing(task): return task.key
        }
    }
}

// MARK: - Section band

private struct SectionBand: View {
    let title: String
    let count: Int
    let isCollapsed: Bool
    let canCollapse: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.sectionHeader)
                    .foregroundStyle(Palette.secondary)
                if canCollapse {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Palette.tertiary)
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                }
                Spacer()
                if isCollapsed {
                    Text("\(count)")
                        .font(.taskMeta)
                        .monospacedDigit()
                        .foregroundStyle(Palette.tertiary)
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canCollapse)
        .background(Palette.band)
    }
}

// MARK: - Row

struct TaskRow: View {
    let task: TaskSnapshot
    let accent: Color
    let isMuted: Bool
    let snoozeOptions: [(label: String, interval: TimeInterval)]
    let isLast: Bool
    let toggle: () -> Void
    let snooze: (TimeInterval) -> Void
    let mute: () -> Void
    let edit: () -> Void
    @State private var hovered = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: toggle) {
                    ZStack {
                        if task.isCompleted {
                            Circle().fill(Palette.tertiary)
                                .frame(width: Metrics.circle, height: Metrics.circle)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.white)
                        } else {
                            Circle().strokeBorder(accent.opacity(0.55), lineWidth: 1.5)
                                .frame(width: Metrics.circle, height: Metrics.circle)
                        }
                    }
                    .frame(width: Metrics.target, height: Metrics.target)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isCompleted ? "Mark incomplete: \(task.title)" : "Complete: \(task.title)")

                Button(action: edit) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(task.title)
                            .font(.taskTitle)
                            .strikethrough(task.isCompleted, color: Palette.tertiary)
                            .foregroundStyle(task.isCompleted ? Palette.tertiary : Palette.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 5) {
                            Text(task.listName).foregroundStyle(Palette.secondary)
                            Text("·")
                            Text(Sections.relativeText(for: task, now: .now, calendar: .current))
                                .monospacedDigit()
                            if task.isRecurring {
                                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                                    .font(.system(size: 9))
                            }
                            if isMuted {
                                // Silence the user chose has to be visible, or
                                // it is indistinguishable from a task the app
                                // simply lost.
                                Image(systemName: "bell.slash")
                                    .font(.system(size: 9))
                            }
                        }
                        .font(.taskMeta)
                        .foregroundStyle(Palette.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if !task.isCompleted {
                    Menu {
                        ForEach(snoozeOptions, id: \.label) { option in
                            Button("Snooze \(option.label)") { snooze(option.interval) }
                        }
                        Divider()
                        Button(isMuted ? "Alert me about this again" : "Stop alerting me about this",
                               action: mute)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isMuted ? "bell.slash" : "clock")
                            Text(isMuted ? "Muted" : "Snooze").font(.system(size: 11))
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(isMuted ? Palette.secondary : accent)
                        .padding(.horizontal, 9).padding(.vertical, 7)
                        .background(hovered ? accent.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 90)
                    .help("Snooze")
                }
            }
            .padding(.trailing, Metrics.gutter - 4)
            .frame(minHeight: Metrics.rowHeight)

            if !isLast { InsetDivider(leading: Metrics.target + 12) }
        }
        .padding(.leading, 9)
        .background(hovered ? accent.opacity(0.025) : .clear)
        .onHover { hovered = $0 }
    }
}

// MARK: - Supporting views

private struct NoticeBar: View {
    let title: String
    let detail: String?
    let dismiss: (() -> Void)?
    var action: (label: String, run: () -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondary)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Palette.ink)
                if let detail {
                    Text(detail).font(.taskMeta).foregroundStyle(Palette.secondary)
                }
            }
            Spacer(minLength: 0)
            if let action {
                Button(action.label, action: action.run)
                    .buttonStyle(.plain)
                    .font(.taskMeta)
                    .foregroundStyle(Palette.ink)
            }
            if let dismiss {
                Button("Dismiss", action: dismiss)
                    .buttonStyle(.plain)
                    .font(.taskMeta)
                    .foregroundStyle(Palette.tertiary)
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 10)
        .background(Palette.band)
    }
}

private struct EmptyStateView: View {
    let accent: Color
    let add: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("Nothing waiting")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.ink)
            Text("Add one here, or say it to Siri.")
                .font(.taskMeta)
                .foregroundStyle(Palette.tertiary)
            Chip(label: "New task", isSelected: true, accent: accent, action: add)
                .padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AccessDeniedView: View {
    let accent: Color

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("Beacon needs your reminders")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.ink)
            Text("Your tasks stay in Apple Reminders. Beacon keeps no copy of its own.")
                .font(.taskMeta)
                .foregroundStyle(Palette.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            Chip(label: "Open Privacy Settings", isSelected: true, accent: accent) {
                let path = "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"
                if let url = URL(string: path) { NSWorkspace.shared.open(url) }
            }
            .padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
