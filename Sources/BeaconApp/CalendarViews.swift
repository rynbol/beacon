import SwiftUI
import BeaconKit

struct CalendarWorkspace: View {
    @Bindable var model: CalendarModel
    var search: String
    let followUp: (CalendarEventSnapshot) -> Void
    var openFilters: () -> Void = {}
    @State private var selectedID: String?
    @State private var showingDatePicker = false
    private var events: [CalendarEventSnapshot] {
        model.selectedEvents.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.location.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if model.feed.access == .granted {
                HStack(spacing: 20) {
                    SwiftcnTabs(selection: $model.showingUpcoming, options: [(false, "Day"), (true, "Next 7 days")])
                        .onChange(of: model.showingUpcoming) { _, _ in model.refreshAfterNavigation() }
                    Spacer(minLength: 8)
                    CalendarConnection(model: model, compact: true).fixedSize(horizontal: true, vertical: false)
                }
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.hairline).frame(height: 1) }
                VStack(alignment: .leading, spacing: 18) {
                    if model.showingUpcoming {
                        UpcomingCalendarAgenda(model: model, search: search, followUp: followUp, openFilters: openFilters)
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
                                        .foregroundStyle(active ? TaskListModel.shared.accent.color : Palette.secondary)
                                        .background(active ? TaskListModel.shared.accent.color.opacity(0.10) : Palette.card.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                                        .contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                                    .accessibilityAddTraits(active ? .isSelected : [])
                            }
                        }
                        Text(model.selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.secondary)
                        BeaconScrollView {
                            VStack(spacing: 10) {
                                if events.isEmpty {
                                    Text(model.feed.isRefreshing ? "Loading this day…" : model.feed.calendars.isEmpty ? "No calendars are available. Add an account in Apple Calendar." : "No events to show for this day.")
                                        .font(.system(size: 13)).foregroundStyle(Palette.secondary).padding(.vertical, 32)
                                }
                                ForEach(events) { event in
                                    CalendarEventCard(event: event, model: model, selectedID: $selectedID, followUp: followUp)
                                }
                            }.frame(maxWidth: .infinity)
                                .modifier(CalendarExpansionMotion(selection: selectedID))
                        }
                    }
                }.modifier(BeaconSectionMotion(value: model.showingUpcoming))
            } else { CalendarConnection(model: model); Spacer() }
        }.padding(.horizontal, 32).padding(.bottom, 22)
            .onChange(of: model.selectedDay) { _, _ in selectedID = nil }
            .onChange(of: model.hiddenIDs) { _, _ in selectedID = nil }
            .onChange(of: model.showingUpcoming) { _, _ in selectedID = nil }
            .onChange(of: events.map(\.id)) { _, ids in
                if let selectedID, !ids.contains(selectedID) { self.selectedID = nil }
            }
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
        VStack(alignment: .leading, spacing: 10) {
            if model.feed.access == .granted && model.upcomingToday.isEmpty && model.feed.error == nil {
                Button(action: showCalendar) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar").font(.system(size: 12))
                        Text(model.feed.isRefreshing ? "Checking today’s calendar…" : "No more events today")
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 10))
                    }.font(.system(size: 12)).foregroundStyle(Palette.secondary)
                        .frame(minHeight: 32).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("See calendar")
            } else {
                HStack {
                    Text("Calendar").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Button("See all", action: showCalendar).buttonStyle(.plain)
                        .font(.system(size: 12)).accessibilityLabel("See calendar")
                }.foregroundStyle(Palette.secondary)
                if model.feed.access != .granted || model.feed.error != nil {
                    CalendarConnection(model: model, compact: true)
                }
                if model.feed.access == .granted {
                    ForEach(Array(model.upcomingToday.prefix(maxEvents))) { event in
                        CalendarEventCard(event: event, model: model, selectedID: $selectedID, followUp: followUp)
                    }
                }
            }
        }
        .modifier(CalendarExpansionMotion(selection: selectedID))
        .onChange(of: model.upcomingToday.prefix(maxEvents).map(\.id)) { _, ids in
            if let selectedID, !ids.contains(selectedID) { self.selectedID = nil }
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
                Button("Connect Calendar") { Task { await model.connect() } }.buttonStyle(.borderedProminent).tint(TaskListModel.shared.accent.color)
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
                }.overlay(alignment: .bottom) { Rectangle().fill(Palette.hairline.opacity(0.5)).frame(height: 1).allowsHitTesting(false) }
            }
        }
    }
}

/// One card and one selection model across Day, Next 7 days, and Today.
private struct CalendarEventCard: View {
    let event: CalendarEventSnapshot
    var model: CalendarModel
    @Binding var selectedID: String?
    let followUp: (CalendarEventSnapshot) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var expanded: Bool { selectedID == event.id }

    var body: some View {
        SwiftcnCard {
            Button { selectedID = expanded ? nil : event.id } label: {
                HStack(alignment: .center, spacing: 12) {
                    RoundedRectangle(cornerRadius: 2).fill(model.color(for: event.calendarID))
                        .frame(width: 3)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(event.title).font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.ink).lineLimit(expanded ? nil : 2)
                        Text(CalendarEventFormatting.timeRange(event))
                            .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                        Text(model.source(for: event.calendarID).map { "\($0.title) · \($0.source)" } ?? "Calendar")
                            .font(.system(size: 10)).foregroundStyle(Palette.secondary).lineLimit(1)
                    }.multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.secondary).rotationEffect(.degrees(expanded ? 180 : 0))
                        .frame(width: 24, height: 28)
                }.padding(14).frame(maxWidth: .infinity, minHeight: 80)
                    .contentShape(Rectangle()).fixedSize(horizontal: false, vertical: true)
            }.buttonStyle(.plain)
                .accessibilityLabel("\(event.title), \(CalendarEventFormatting.timeRange(event))")
                .accessibilityValue(expanded ? "Expanded" : "Collapsed")
                .accessibilityHint(expanded ? "Collapse event details" : "Expand event details")
            // Clip the reveal to its own region, so details emerge below the
            // header rather than sliding over the title or neighboring events.
            VStack(spacing: 0) {
                if expanded {
                    CalendarEventDetails(event: event, model: model, close: {
                        if selectedID == event.id { selectedID = nil }
                    }) {
                        guard selectedID == event.id else { return }
                        selectedID = nil
                        followUp(event)
                    }
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }.clipped()
                // Clipping alone does not limit SwiftUI hit testing. Outgoing
                // content must not cover headers while its transition finishes.
                .contentShape(Rectangle())
                .allowsHitTesting(expanded)
                .accessibilityHidden(!expanded)
        }.clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct CalendarExpansionMotion: ViewModifier {
    let selection: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : .easeInOut(duration: 0.26), value: selection)
    }
}

private struct CalendarEventDetails: View {
    let event: CalendarEventSnapshot
    var model: CalendarModel
    let close: () -> Void
    let followUp: () -> Void
    @State private var showingFullNotes = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var notes: String { event.notes.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var location: String {
        let value = event.location.trimmingCharacters(in: .whitespacesAndNewlines)
        // A meeting URL already has its own action; don't display the long URL
        // again as a street address or let it widen the card.
        if let meeting = event.meetingURL, URL(string: value) == meeting { return "" }
        return value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Rectangle().fill(Palette.hairline).frame(height: 1)
            if !location.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "mappin.and.ellipse").frame(width: 16, height: 18)
                        .foregroundStyle(Palette.secondary).accessibilityHidden(true)
                    Text(location).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }.font(.system(size: 12))
            }
            if !notes.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Notes").font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.secondary)
                    Text(notes).font(.system(size: 12)).lineSpacing(3)
                        .lineLimit(showingFullNotes ? nil : 5).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // Always offer expansion: even a short string can contain
                    // more than five lines. No nested scroll area traps scrolling.
                    Button(showingFullNotes ? "Show less" : "Show full notes") {
                        showingFullNotes.toggle()
                    }.buttonStyle(.plain).font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TaskListModel.shared.accent.color)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { actions }
                    VStack(alignment: .leading, spacing: 8) { actions }
                }
                Spacer(minLength: 0)
                Button(action: close) {
                    Image(systemName: "xmark").frame(width: 28, height: 32).contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(Palette.secondary)
                    .keyboardShortcut(.cancelAction).help("Close event details · Esc")
                    .accessibilityLabel("Close event details")
            }
        }.padding(.leading, 29).padding(.trailing, 14).padding(.bottom, 16)
            .foregroundStyle(Palette.ink)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showingFullNotes)
    }

    @ViewBuilder private var actions: some View {
        if let url = event.meetingURL {
            Button { if !model.isPreview { NSWorkspace.shared.open(url) } } label: {
                Label("Join meeting", systemImage: "video")
            }.buttonStyle(SwiftcnButtonStyle(variant: .primary, accent: TaskListModel.shared.accent.color))
                .disabled(model.isPreview)
                .help(model.isPreview ? "Meeting links are disabled in the sample preview" : "Open meeting link")
        }
        Button(action: followUp) {
            Label("Follow-up reminder", systemImage: "plus")
        }.buttonStyle(SwiftcnButtonStyle())
            .accessibilityLabel("Create a follow-up reminder")
    }
}


struct UpcomingCalendarAgenda: View {
    var model: CalendarModel
    var search: String
    let followUp: (CalendarEventSnapshot) -> Void
    var openFilters: () -> Void = {}
    @State private var selectedID: String?
    private var events: [CalendarEventSnapshot] {
        model.upcomingEvents.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer(minLength: 8)
                UpcomingEventAddButton(model: model)
                Button(action: openFilters) {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease")
                        Text("Filters")
                        let count = model.includeKeywords.count + model.excludeKeywords.count
                        if count > 0 { Text("\(count)").monospacedDigit() }
                    }
                }.buttonStyle(SwiftcnButtonStyle()).accessibilityLabel("Upcoming event filters")

            }
            BeaconScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if events.isEmpty {
                        Text(model.feed.isRefreshing ? "Loading upcoming events…" : "No upcoming events match. Check your keywords and calendar toggles.")
                            .font(.taskMeta).foregroundStyle(Palette.secondary).padding(.vertical, 28)
                    }
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        if index == 0 || !Calendar.current.isDate(event.start, inSameDayAs: events[index - 1].start) {
                            Text(event.start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.secondary).padding(.top, 8)
                        }
                        CalendarEventCard(event: event, model: model, selectedID: $selectedID, followUp: followUp)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(CalendarExpansionMotion(selection: selectedID))
            }
        }
        .onChange(of: events.map(\.id)) { _, ids in
            if let selectedID, !ids.contains(selectedID) { self.selectedID = nil }
        }
    }
}

struct UpcomingKeywordSettings: View {
    var model: CalendarModel
    @State private var includeDraft = ""
    @State private var excludeDraft = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming filters").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.ink)
            Text("Match event titles, regardless of case. Exclusions take priority unless you manually add an event.")
                .font(.taskMeta).foregroundStyle(Palette.secondary)
            keywordList("Include", values: model.includeKeywords, draft: $includeDraft, excluding: false)
            keywordList("Exclude", values: model.excludeKeywords, draft: $excludeDraft, excluding: true)
            Divider().padding(.vertical, 4)
            HStack {
                Text("Manually added").font(.system(size: 12, weight: .semibold))
                Spacer()
                UpcomingEventAddButton(model: model)
            }
            Text("Include individual events in the next 7 days, even when keywords hide them. Calendar toggles still apply.")
                .font(.taskMeta).foregroundStyle(Palette.secondary)
            ForEach(model.manuallyIncludedEvents) { event in
                HStack(spacing: 12) {
                    UpcomingEventSelectionLabel(event: event, model: model)
                    Spacer(minLength: 8)
                    Button { model.setManuallyIncluded(event, included: false) } label: {
                        Image(systemName: "xmark").frame(width: 28, height: 28)
                    }.buttonStyle(.plain).accessibilityLabel("Remove manual inclusion for \(event.title)")
                }
            }
            if model.manuallyIncludedEvents.isEmpty {
                Text("No manually added events this week.").font(.taskMeta).foregroundStyle(Palette.secondary)
            }
        }
    }
    private func keywordList(_ label: String, values: [String], draft: Binding<String>, excluding: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 12, weight: .semibold))
            Text(excluding ? "Hide titles containing any of these keywords." : "Show titles containing any keyword. Empty means all events.")
                .font(.system(size: 11)).foregroundStyle(Palette.secondary)
            HStack {
                TextField("Add keyword", text: draft)
                    .textFieldStyle(.plain).padding(.horizontal, 10).frame(height: 32)
                    .modifier(SwiftcnInputSurface()).accessibilityLabel("\(label) keyword")
                    .onSubmit { add(draft, excluding: excluding) }
                Button("Add") { add(draft, excluding: excluding) }
                    .buttonStyle(SwiftcnButtonStyle())
                    .disabled(draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Add \(label.lowercased()) keyword")
            }
            VStack(spacing: 6) {
                ForEach(values, id: \.self) { keyword in
                    Button {
                        model.setKeywords(values.filter { $0 != keyword }, excluding: excluding)
                    } label: {
                        HStack(spacing: 8) {
                            Text(keyword).lineLimit(2).multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Image(systemName: "xmark").font(.system(size: 10))
                        }.frame(maxWidth: .infinity).contentShape(Rectangle())
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

/// Shared picker for the calendar toolbar and Calendar settings.
private struct UpcomingEventAddButton: View {
    var model: CalendarModel
    @State private var showing = false
    @State private var search = ""
    @State private var presentationID = UUID()
    @State private var releaseTask: Task<Void, Never>?
    @Environment(\.beaconChoicePresentation) private var parentPresentation
    private var events: [CalendarEventSnapshot] {
        model.availableUpcomingEvents.filter {
            search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)
        }
    }
    var body: some View {
        Button { search = ""; parentPresentation.wrappedValue.insert(presentationID); showing = true } label: {
            Label("Add events", systemImage: "plus")
        }.buttonStyle(SwiftcnButtonStyle())
            .onChange(of: showing) { _, value in
                releaseTask?.cancel()
                if value { parentPresentation.wrappedValue.insert(presentationID) }
                else {
                    releaseTask = Task { @MainActor in
                        do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                        guard !showing else { return }
                        parentPresentation.wrappedValue.remove(presentationID)
                    }
                }
            }
            .onDisappear {
                releaseTask?.cancel()
                parentPresentation.wrappedValue.remove(presentationID)
            }
            .popover(isPresented: $showing, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Add events").font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Button { showing = false } label: {
                            Image(systemName: "xmark").frame(width: 28, height: 28)
                        }.buttonStyle(.plain).keyboardShortcut(.cancelAction).accessibilityLabel("Close event picker")
                    }
                    Text("Choose extra events for the next 7 days.")
                        .font(.taskMeta).foregroundStyle(Palette.secondary)
                    TextField("Search events", text: $search).textFieldStyle(.plain)
                        .padding(10).modifier(SwiftcnInputSurface())
                    BeaconScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            if let error = model.feed.error {
                                Text(error).font(.taskMeta).foregroundStyle(Palette.secondary)
                            }
                            if events.isEmpty {
                                Text(model.feed.isRefreshing ? "Loading events…" : search.isEmpty ? "No extra events to add. Check your calendar toggles if something is missing." : "No matching events.")
                                    .font(.taskMeta).foregroundStyle(Palette.secondary).padding(.vertical, 12)
                            }
                            ForEach(events) { event in
                                Button { model.setManuallyIncluded(event, included: true) } label: {
                                    HStack(spacing: 12) {
                                        UpcomingEventSelectionLabel(event: event, model: model)
                                        Spacer(minLength: 8)
                                        Image(systemName: "plus").font(.system(size: 12))
                                    }.padding(8).contentShape(Rectangle())
                                }.buttonStyle(SwiftcnButtonStyle(variant: .quiet))
                                    .accessibilityLabel("Include \(event.title), \(event.start.formatted(date: .abbreviated, time: .shortened))")
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(height: 260)
                }.padding(18).frame(width: 380)
                    .foregroundStyle(Palette.ink).background(Palette.wash)
                    .task { await model.refresh() }
            }
    }
}

private struct UpcomingEventSelectionLabel: View {
    let event: CalendarEventSnapshot
    var model: CalendarModel
    private var detail: String {
        let date = event.start.formatted(.dateTime.month(.abbreviated).day())
        let time = event.isAllDay ? "All day" : event.start.formatted(date: .omitted, time: .shortened)
        let calendar = model.source(for: event.calendarID)?.title ?? "Calendar"
        return "\(date) · \(time) · \(calendar)"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title).font(.taskMeta).foregroundStyle(Palette.ink)
                .lineLimit(2).multilineTextAlignment(.leading)
            Text(detail)
                .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                .lineLimit(2).multilineTextAlignment(.leading)
        }
    }
}
