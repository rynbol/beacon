import SwiftUI
import BeaconKit

struct CalendarWorkspace: View {
    @Bindable var model: CalendarModel
    var search: String
    let followUp: (CalendarEventSnapshot) -> Void
    @State private var selectedID: String?
    @State private var showingDatePicker = false
    private var events: [CalendarEventSnapshot] {
        model.selectedEvents.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.location.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CalendarConnection(model: model)
            if model.feed.access == .granted {
                Picker("Calendar view", selection: $model.showingUpcoming) {
                    Text("Day").tag(false)
                    Text("Upcoming · 7 days").tag(true)
                }.pickerStyle(.segmented).frame(width: 260)
                    .onChange(of: model.showingUpcoming) { _, _ in model.refreshAfterNavigation() }
                if model.showingUpcoming {
                    UpcomingCalendarAgenda(model: model, search: search, followUp: followUp)
                } else {
                    HStack(spacing: 8) {
                        navigationButton("chevron.left", label: "Previous week") { moveWeek(-1) }
                        Text(model.selectedDay.formatted(.dateTime.month(.wide).year()))
                            .font(.system(size: 16, weight: .medium)).lineLimit(1)
                        navigationButton("chevron.right", label: "Next week") { moveWeek(1) }
                        Spacer(minLength: 8)
                        Button { model.selectDay(.now) } label: {
                            Text("Today").padding(.horizontal, 12).frame(height: 36)
                                .background(Palette.card, in: RoundedRectangle(cornerRadius: 8)).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Button { showingDatePicker.toggle() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                Text(model.selectedDay.formatted(.dateTime.month(.abbreviated).day().year())).lineLimit(1)
                            }.font(.system(size: 12)).padding(.horizontal, 12).frame(height: 36)
                                .background(Palette.card, in: RoundedRectangle(cornerRadius: 8)).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel("Choose date")
                            .popover(isPresented: $showingDatePicker) {
                                VStack(alignment: .trailing, spacing: 8) {
                                    Button { showingDatePicker = false } label: {
                                        Image(systemName: "xmark").frame(width: 28, height: 28).contentShape(Rectangle())
                                    }.buttonStyle(.plain).accessibilityLabel("Close date picker")
                                    DatePicker("Choose date", selection: Binding(
                                        get: { model.selectedDay },
                                        set: { model.selectDay($0); showingDatePicker = false }
                                    ), displayedComponents: .date).datePickerStyle(.graphical).labelsHidden()
                                }.padding(14).frame(width: 290)
                            }
                    }.foregroundStyle(Palette.secondary)
                    HStack(spacing: 7) {
                        ForEach(model.days, id: \.self) { day in
                            let active = Calendar.current.isDate(day, inSameDayAs: model.selectedDay)
                            Button { model.selectDay(day) } label: {
                                VStack(spacing: 8) {
                                    Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.system(size: 11))
                                    Text(day.formatted(.dateTime.day())).font(.system(size: 18, weight: .medium))
                                }.frame(maxWidth: .infinity).frame(height: 64)
                                    .foregroundStyle(active ? Accent.ocean.color : Palette.secondary)
                                    .background(active ? Accent.ocean.color.opacity(0.10) : Palette.card.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                                .accessibilityAddTraits(active ? .isSelected : [])
                        }
                    }
                    Text(model.selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.secondary)
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if events.isEmpty {
                                Text(model.feed.isRefreshing ? "Loading this day…" : model.feed.calendars.isEmpty ? "No calendars are available. Add an account in Apple Calendar." : "No events to show for this day.")
                                    .font(.system(size: 13)).foregroundStyle(Palette.secondary).padding(.vertical, 32)
                            }
                            ForEach(events) { event in
                                VStack(spacing: 0) {
                                    CalendarEventRow(event: event, model: model) { selectedID = selectedID == event.id ? nil : event.id }
                                    if selectedID == event.id {
                                        CalendarEventDetails(event: event, model: model, close: { selectedID = nil }) {
                                            selectedID = nil; followUp(event)
                                        }.padding(.top, 8)
                                    }
                                }
                            }
                        }.frame(maxWidth: .infinity)
                    }
                }
            } else { Spacer() }
        }.padding(.horizontal, 32).padding(.bottom, 22)
            .onChange(of: model.selectedDay) { _, _ in selectedID = nil }
            .onChange(of: model.hiddenIDs) { _, _ in selectedID = nil }
    }
    private func navigationButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).frame(width: 36, height: 36)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 8)).contentShape(Rectangle())
        }.buttonStyle(.plain).help(label).accessibilityLabel(label)
    }
    private func moveWeek(_ step: Int) {
        model.selectDay(Calendar.current.date(byAdding: .weekOfYear, value: step, to: model.selectedDay)!)
    }
}

struct TodayCalendarAgenda: View {
    var model: CalendarModel
    let showCalendar: () -> Void
    let followUp: (CalendarEventSnapshot) -> Void
    var maxEvents = 3
    @State private var selectedID: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Up next").font(.system(size: 12, weight: .semibold))
                Spacer()
                Button(action: showCalendar) {
                    Image(systemName: "arrow.up.right").frame(width: 32, height: 32).contentShape(Rectangle())
                }.buttonStyle(.plain).help("See calendar").accessibilityLabel("See calendar")
            }.foregroundStyle(Accent.ocean.color)
            CalendarConnection(model: model, compact: true)
            if model.feed.access == .granted {
                ForEach(Array(model.upcomingToday.prefix(maxEvents))) { event in
                    CalendarEventRow(event: event, model: model) { selectedID = selectedID == event.id ? nil : event.id }
                    if selectedID == event.id {
                        CalendarEventDetails(event: event, model: model, close: { selectedID = nil }) { selectedID = nil; followUp(event) }
                    }
                }
                if model.upcomingToday.isEmpty {
                    Text("No more events today.").font(.system(size: 12)).foregroundStyle(Palette.secondary)
                }
                Button("See calendar", action: showCalendar).buttonStyle(.link).font(.system(size: 12))
            }
        }
    }
}

struct CalendarConnection: View {
    var model: CalendarModel
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch model.feed.access {
            case .notDetermined:
                Text("Your schedule, alongside your reminders.").font(.system(size: 13, weight: .medium))
                Text("Connect Calendar to see iCloud, Google, and other accounts added on this Mac.")
                    .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                Button("Connect Calendar") { Task { await model.connect() } }.buttonStyle(.borderedProminent).tint(Accent.ocean.color)
            case .denied:
                Text("Calendar access is off").font(.system(size: 13, weight: .medium))
                Button("Open Calendar Privacy Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") { NSWorkspace.shared.open(url) }
                }.buttonStyle(.link)
            case .granted:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini).opacity(model.feed.isRefreshing ? 1 : 0)
                        .accessibilityHidden(!model.feed.isRefreshing)
                    Text(model.isPreview ? "Sample events" : model.feed.isRefreshing ? "Refreshing Calendar…" : model.feed.lastRead.map { "Updated \($0.formatted(date: .omitted, time: .shortened))" } ?? "Calendar connected")
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                }.frame(height: 18, alignment: .leading)
            }
            if let error = model.feed.error {
                Text("Couldn’t refresh. \(error)").font(.system(size: 12)).foregroundStyle(Palette.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Source controls live in Settings, with bounded rows even for long account names.
struct CalendarFilters: View {
    var model: CalendarModel
    var body: some View {
        VStack(spacing: 4) {
            ForEach(model.feed.calendars) { calendar in
                HStack(spacing: 8) {
                    Button { model.toggleCalendar(calendar.id) } label: {
                        HStack(spacing: 9) {
                            Image(systemName: model.hiddenIDs.contains(calendar.id) ? "circle" : "checkmark.circle.fill")
                                .foregroundStyle(model.color(for: calendar.id))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(calendar.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                Text(calendar.source).font(.system(size: 10)).foregroundStyle(Palette.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }.padding(8).frame(maxWidth: .infinity, minHeight: 40).contentShape(Rectangle())
                    }.buttonStyle(.plain).help("Show or hide \(calendar.title) · \(calendar.source)")
                    Menu {
                        Button("Use Calendar’s color") { model.setColor(nil, for: calendar.id) }
                        Divider()
                        ForEach(Accent.allCases) { color in
                            Button(color.title) { model.setColor(color, for: calendar.id) }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Circle().fill(model.color(for: calendar.id)).frame(width: 12, height: 12)
                            Image(systemName: "chevron.down").font(.system(size: 10))
                        }.frame(width: 48, height: 36).contentShape(Rectangle())
                    }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                        .accessibilityLabel("Color for \(calendar.title)").help("Color for \(calendar.title)")
                }.background(model.color(for: calendar.id).opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct CalendarEventRow: View {
    let event: CalendarEventSnapshot
    var model: CalendarModel
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2).fill(model.color(for: event.calendarID)).frame(width: 3)
                VStack(alignment: .leading, spacing: 7) {
                    Text(CalendarEventFormatting.timeRange(event)).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    Text(event.title).font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                    HStack(spacing: 5) {
                        Circle().fill(model.color(for: event.calendarID)).frame(width: 6, height: 6)
                        Text(model.source(for: event.calendarID).map { "\($0.title) · \($0.source)" } ?? "Calendar").lineLimit(1)
                        if event.meetingURL != nil { Image(systemName: "video") }
                    }.font(.system(size: 10)).foregroundStyle(Palette.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(13).frame(maxWidth: .infinity, minHeight: 80)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.hairline.opacity(0.5), lineWidth: 1).allowsHitTesting(false))
                .contentShape(Rectangle()).fixedSize(horizontal: false, vertical: true)
        }.buttonStyle(.plain)
    }
}

private struct CalendarEventDetails: View {
    let event: CalendarEventSnapshot
    var model: CalendarModel
    let close: () -> Void
    let followUp: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(event.title).font(.system(size: 20, design: .serif))
                Spacer(minLength: 4)
                Button(action: close) { Image(systemName: "xmark").frame(width: 28, height: 28).contentShape(Rectangle()) }
                    .buttonStyle(.plain).accessibilityLabel("Close event details")
            }
            Text(event.start.formatted(date: .abbreviated, time: .omitted) + " · " + CalendarEventFormatting.timeRange(event))
                .font(.system(size: 12)).foregroundStyle(Palette.secondary)
            if !event.location.isEmpty { Label(event.location, systemImage: "mappin").font(.system(size: 12)) }
            if !event.notes.isEmpty {
                ScrollView { Text(event.notes).font(.system(size: 12)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 100)
            }
            if let url = event.meetingURL {
                Button("Join meeting") { if !model.isPreview { NSWorkspace.shared.open(url) } }
                    .disabled(model.isPreview).buttonStyle(.borderedProminent).tint(model.color(for: event.calendarID))
            }
            Button("Create a follow-up reminder", action: followUp).buttonStyle(.link)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.band.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}


struct UpcomingCalendarAgenda: View {
    var model: CalendarModel
    var search: String
    let followUp: (CalendarEventSnapshot) -> Void
    @State private var selectedID: String?
    private var events: [CalendarEventSnapshot] {
        model.upcomingEvents.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming").font(.system(size: 18, weight: .semibold))
                Spacer()
                Text("Next 7 days · \(events.count) \(events.count == 1 ? "event" : "events")").font(.taskMeta).foregroundStyle(Palette.secondary)
            }
            Text("Include: \(model.includeKeywords.isEmpty ? "All titles" : model.includeKeywords.joined(separator: ", ")) · Exclude: \(model.excludeKeywords.isEmpty ? "None" : model.excludeKeywords.joined(separator: ", "))")
                .font(.taskMeta).foregroundStyle(Palette.secondary)
            Text("Change keywords in Settings → Upcoming calendar events.")
                .font(.system(size: 11)).foregroundStyle(Palette.secondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if events.isEmpty {
                        Text(model.feed.isRefreshing ? "Loading upcoming events…" : "No upcoming events match. Check your keywords and calendar toggles.")
                            .font(.taskMeta).foregroundStyle(Palette.secondary).padding(.vertical, 28)
                    }
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        if index == 0 || !Calendar.current.isDate(event.start, inSameDayAs: events[index - 1].start) {
                            Text(event.start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.secondary).padding(.top, 8)
                        }
                        CalendarEventRow(event: event, model: model) { selectedID = selectedID == event.id ? nil : event.id }
                        if selectedID == event.id {
                            CalendarEventDetails(event: event, model: model, close: { selectedID = nil }) {
                                selectedID = nil; followUp(event)
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct UpcomingKeywordSettings: View {
    var model: CalendarModel
    @State private var includeDraft = ""
    @State private var excludeDraft = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming calendar events").font(.fieldLabel).foregroundStyle(Palette.secondary)
            Text("Filter event titles in Calendar → Upcoming. Match any include keyword; exclude keywords always win. Matching ignores case. Leave Include empty to show all titles.")
                .font(.taskMeta).foregroundStyle(Palette.secondary)
            keywordList("Include", values: model.includeKeywords, draft: $includeDraft, excluding: false)
            keywordList("Exclude", values: model.excludeKeywords, draft: $excludeDraft, excluding: true)
        }
    }
    private func keywordList(_ label: String, values: [String], draft: Binding<String>, excluding: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 12, weight: .semibold))
            HStack {
                TextField("Add keyword", text: draft)
                    .textFieldStyle(.roundedBorder).accessibilityLabel("\(label) keyword")
                    .onSubmit { add(draft, excluding: excluding) }
                Button("Add") { add(draft, excluding: excluding) }
                    .disabled(draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Add \(label.lowercased()) keyword")
            }
            FlowRow(spacing: 6) {
                ForEach(values, id: \.self) { keyword in
                    Button {
                        model.setKeywords(values.filter { $0 != keyword }, excluding: excluding)
                    } label: {
                        HStack(spacing: 6) { Text(keyword); Image(systemName: "xmark").font(.system(size: 9)) }
                            .font(.taskMeta).padding(.horizontal, 9).padding(.vertical, 7)
                            .background(Palette.band, in: RoundedRectangle(cornerRadius: 6))
                    }.buttonStyle(.plain).accessibilityLabel("Remove \(label.lowercased()) keyword \(keyword)")
                }
            }
        }
    }
    private func add(_ draft: Binding<String>, excluding: Bool) {
        let existing = excluding ? model.excludeKeywords : model.includeKeywords
        model.setKeywords(existing + [draft.wrappedValue], excluding: excluding)
        draft.wrappedValue = ""
    }
}
