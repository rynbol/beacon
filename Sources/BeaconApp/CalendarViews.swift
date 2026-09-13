import SwiftUI
import BeaconKit

struct CalendarWorkspace: View {
    @Bindable var model: CalendarModel
    var search: String
    let followUp: (CalendarEventSnapshot) -> Void
    var openFilters: () -> Void = {}
    @State private var selectedID: String?
    @State private var showingDatePicker = false
    @State private var dateDirection: CGFloat = 1
    @Namespace private var dayHighlight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var events: [CalendarEventSnapshot] {
        model.selectedEvents.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.location.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.feed.access == .granted {
                toolbar
                if let error = model.feed.error {
                    Text("Couldn’t refresh. \(error)")
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Group {
                    if model.showingUpcoming {
                        UpcomingCalendarAgenda(model: model, search: search, followUp: followUp)
                    } else {
                        VStack(alignment: .leading, spacing: 20) {
                            weekStrip
                            dayAgenda
                        }
                    }
                }.modifier(BeaconSectionMotion(value: model.showingUpcoming))
            } else { CalendarConnection(model: model); Spacer() }
        }.padding(.horizontal, 32).padding(.bottom, 22)
            .onChange(of: model.selectedDay) { _, _ in selectedID = nil }
            .onChange(of: model.hiddenIDs) { _, _ in selectedID = nil }
            .onChange(of: model.showingUpcoming) { _, _ in
                selectedID = nil
                showingDatePicker = false
                model.refreshAfterNavigation()
            }
            .onChange(of: events.map(\.id)) { _, ids in
                if let selectedID, !ids.contains(selectedID) { self.selectedID = nil }
            }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                viewButton("Day", upcoming: false)
                viewButton("Next 7 days", upcoming: true)
            }
            .padding(3)
            .background(Palette.band.opacity(0.7), in: RoundedRectangle(cornerRadius: 9))
            Spacer(minLength: 0)
            if model.showingUpcoming {
                UpcomingEventAddButton(model: model, variant: .quiet)
                Button(action: openFilters) {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease")
                        Text("Filters")
                        let count = model.includeKeywords.count + model.excludeKeywords.count
                        if count > 0 { Text("\(count)").monospacedDigit() }
                    }
                }.buttonStyle(SwiftcnButtonStyle(variant: .quiet))
                    .accessibilityLabel("Upcoming event filters")
            } else {
                dateNavigation
            }
        }
        .frame(minHeight: 36)
        .overlay(alignment: .topTrailing) {
            // Progress occupies no extra header band and never shifts navigation.
            if model.feed.isRefreshing {
                ProgressView().controlSize(.mini).offset(x: 19, y: 12)
                    .help("Refreshing Calendar")
                    .accessibilityLabel("Refreshing Calendar")
            }
        }
    }

    private func viewButton(_ title: String, upcoming: Bool) -> some View {
        let active = model.showingUpcoming == upcoming
        return Button { model.showingUpcoming = upcoming } label: {
            Text(title).font(.system(size: 12, weight: active ? .medium : .regular))
                .foregroundStyle(active ? Palette.ink : Palette.secondary)
                .padding(.horizontal, 11).frame(height: 28)
                .background(active ? Palette.card : .clear, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }.buttonStyle(BeaconControlButtonStyle())
            .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var dateNavigation: some View {
        HStack(spacing: 2) {
            navigationButton("chevron.left", label: "Previous week") { moveWeek(-1) }
            Button { showingDatePicker.toggle() } label: {
                HStack(spacing: 5) {
                    Text(model.selectedDay.formatted(.dateTime.month(.wide).year()))
                        .lineLimit(1).fixedSize()
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium))
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 5).frame(height: 32).contentShape(Rectangle())
            }.buttonStyle(BeaconControlButtonStyle())
                .help("Choose date").accessibilityLabel("Choose date")
                .accessibilityValue(model.selectedDay.formatted(date: .complete, time: .omitted))
                .popover(isPresented: $showingDatePicker) {
                    VStack(alignment: .trailing, spacing: 8) {
                        Button { showingDatePicker = false } label: {
                            Image(systemName: "xmark").frame(width: 28, height: 28).contentShape(Rectangle())
                        }.buttonStyle(BeaconControlButtonStyle()).accessibilityLabel("Close date picker")
                        DatePicker("Choose date", selection: Binding(
                            get: { model.selectedDay },
                            set: { selectDay($0); showingDatePicker = false }
                        ), displayedComponents: .date).datePickerStyle(.graphical).labelsHidden()
                    }.padding(14).frame(width: 290)
                }
            navigationButton("chevron.right", label: "Next week") { moveWeek(1) }
            Button { selectDay(.now) } label: {
                Text("Today").font(.system(size: 12)).padding(.horizontal, 10)
                    .frame(height: 32).contentShape(Rectangle())
            }.buttonStyle(BeaconControlButtonStyle()).padding(.leading, 4)
        }.foregroundStyle(Palette.secondary)
    }

    private var weekStrip: some View {
        HStack(spacing: 6) {
            ForEach(model.days, id: \.self) { day in
                let active = Calendar.current.isDate(day, inSameDayAs: model.selectedDay)
                Button { selectDay(day) } label: {
                    VStack(spacing: 6) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.system(size: 11))
                        Text(day.formatted(.dateTime.day())).font(.system(size: 17, weight: .medium))
                    }.frame(maxWidth: .infinity).frame(height: 58)
                        .foregroundStyle(active ? TaskListModel.shared.accent.color : Palette.secondary)
                        .background {
                            Group {
                                if active {
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(TaskListModel.shared.accent.color.opacity(0.10))
                                        .matchedGeometryEffect(id: "selectedDay", in: dayHighlight)
                                }
                            }
                            .animation(reduceMotion ? nil : BeaconMotion.selection, value: model.selectedDay)
                        }
                        .contentShape(Rectangle())
                }.buttonStyle(BeaconControlButtonStyle())
                    .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                    .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.hairline).frame(height: 1) }
        .modifier(BeaconSectionMotion(value: model.week.start, direction: dateDirection))
    }

    private var dayAgenda: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.secondary)
                .accessibilityAddTraits(.isHeader)
            BeaconScrollView {
                VStack(spacing: 4) {
                    if events.isEmpty {
                        Text(model.feed.isRefreshing ? "Loading this day…" : model.feed.calendars.isEmpty ? "No calendars are available. Add an account in Apple Calendar." : "No events to show for this day.")
                            .font(.system(size: 13)).foregroundStyle(Palette.secondary).padding(.vertical, 32)
                    }
                    ForEach(events) { event in
                        CalendarEventCard(event: event, model: model, selectedID: $selectedID, followUp: followUp)
                    }
                }.frame(maxWidth: .infinity)
                    .modifier(CalendarAgendaMotion(selection: selectedID))
            }
        }.modifier(BeaconSectionMotion(value: model.selectedDay, direction: dateDirection))
    }

    private func navigationButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 11, weight: .medium))
                .frame(width: 28, height: 32).contentShape(Rectangle())
        }.buttonStyle(BeaconControlButtonStyle()).help(label).accessibilityLabel(label)
    }
    private func selectDay(_ date: Date) {
        // Replace date content immediately. The section helper animates only
        // its visual position; the date grid owns its selection highlight.
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            dateDirection = date < model.selectedDay ? -1 : 1
            selectedID = nil
            model.selectDay(date)
        }
    }
    private func moveWeek(_ step: Int) {
        selectDay(Calendar.current.date(byAdding: .weekOfYear, value: step, to: model.selectedDay)!)
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
                }.buttonStyle(BeaconControlButtonStyle()).accessibilityLabel("See calendar")
            } else {
                HStack {
                    Text("Calendar").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Button("See all", action: showCalendar).buttonStyle(BeaconControlButtonStyle())
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
        .modifier(CalendarAgendaMotion(selection: selectedID))
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
        VStack(spacing: 0) {
            ForEach(model.feed.calendars) { calendar in
                HStack(spacing: 10) {
                    BeaconChoicePicker(
                        label: "Color for \(calendar.title)",
                        selection: Binding<Accent?>(
                            get: { model.colorOverrides[calendar.id].flatMap { Accent(rawValue: $0) } },
                            set: { model.setColor($0, for: calendar.id) }
                        ),
                        options: [BeaconChoice<Accent?>(value: nil, title: "Use Calendar’s color",
                                    symbol: "circle.fill", color: Color(red: calendar.tint.red,
                                        green: calendar.tint.green, blue: calendar.tint.blue))]
                            + Accent.allCases.map {
                                BeaconChoice(value: Optional($0), title: $0.title, symbol: "circle.fill", color: $0.color)
                            },
                        swatch: model.color(for: calendar.id)
                    ).help("Color for \(calendar.title)")
                    VStack(alignment: .leading, spacing: 3) {
                        Text(calendar.title).font(.system(size: 13, weight: .medium)).lineLimit(2)
                            .foregroundStyle(Palette.ink)
                        Text(calendar.source).font(.system(size: 12)).foregroundStyle(Palette.secondary).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                        .help("\(calendar.title) · \(calendar.source)")
                    Toggle("Show \(calendar.title)", isOn: Binding(
                        get: { !model.hiddenIDs.contains(calendar.id) },
                        set: { visible in
                            if visible == model.hiddenIDs.contains(calendar.id) { model.toggleCalendar(calendar.id) }
                        }
                    ))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                }.padding(.vertical, 9)
                BeaconSettingsDivider()
            }
        }
    }
}

/// Animate the stack's placement as well as each disclosure. Otherwise the
/// next row receives its final position before the local reveal has finished.
private struct CalendarAgendaMotion: ViewModifier {
    let selection: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : BeaconMotion.disclosure, value: selection)
    }
}

/// One agenda row and one selection model across Day, Next 7 days, and Today.
private struct CalendarEventCard: View {
    let event: CalendarEventSnapshot
    var model: CalendarModel
    @Binding var selectedID: String?
    let followUp: (CalendarEventSnapshot) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var expanded: Bool { selectedID == event.id }
    private var sourceTitle: String { model.source(for: event.calendarID)?.title ?? "Calendar" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { selectedID = expanded ? nil : event.id } label: {
                HStack(alignment: .center, spacing: 12) {
                    RoundedRectangle(cornerRadius: 2).fill(model.color(for: event.calendarID))
                        .frame(width: 3, height: 30)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(event.title).font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(CalendarEventFormatting.timeRange(event)) · \(sourceTitle)")
                            .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }.multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.tertiary).rotationEffect(.degrees(expanded ? 180 : 0))
                        .animation(reduceMotion ? nil : BeaconMotion.selection, value: expanded)
                        .frame(width: 24, height: 28)
                }.padding(.horizontal, 12).padding(.vertical, 14)
                    .frame(maxWidth: .infinity, minHeight: 68)
                    .contentShape(Rectangle()).fixedSize(horizontal: false, vertical: true)
            }.buttonStyle(BeaconControlButtonStyle())
                .help(model.source(for: event.calendarID).map { "\($0.title) · \($0.source)" } ?? "Calendar")
                .accessibilityLabel("\(event.title), \(CalendarEventFormatting.timeRange(event)), \(sourceTitle)")
                .accessibilityValue(expanded ? "Expanded" : "Collapsed")
                .accessibilityHint(expanded ? "Collapse event details" : "Expand event details")
            // Full-height content keeps its layout during nested reveals.
            BeaconDisclosure(isExpanded: expanded) {
                CalendarEventDetails(event: event, model: model, isExpanded: expanded) {
                    guard selectedID == event.id else { return }
                    selectedID = nil
                    followUp(event)
                }
                .id(event.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10).fill(Palette.card)
                .opacity(expanded ? 1 : 0)
                .animation(reduceMotion ? nil : BeaconMotion.disclosure, value: expanded)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Palette.hairline.opacity(0.8), lineWidth: 1)
                .opacity(expanded ? 1 : 0)
                .animation(reduceMotion ? nil : BeaconMotion.disclosure, value: expanded)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairline.opacity(0.55)).frame(height: 1)
                .padding(.horizontal, 12).opacity(expanded ? 0 : 1)
                .animation(reduceMotion ? nil : BeaconMotion.disclosure, value: expanded)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        // The agenda animates this row as a single geometry unit. Descendant
        // text keeps its final metrics; disclosures own their local viewport.
        .transaction { $0.animation = nil }
        .geometryGroup()
        .background {
            if expanded {
                Button("Collapse event") { selectedID = nil }
                    .keyboardShortcut(.cancelAction)
                    .frame(width: 0, height: 0).opacity(0)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
}

private struct CalendarEventDetails: View {
    let event: CalendarEventSnapshot
    var model: CalendarModel
    let isExpanded: Bool
    let followUp: () -> Void
    private var notes: (body: String, meetingDetails: String) {
        CalendarNotes.presentation(event.notes.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    @State private var showMeetingDetails = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var location: String {
        let value = event.location.trimmingCharacters(in: .whitespacesAndNewlines)
        // A meeting URL already has its own action; don't display the long URL
        // again as a street address or let it widen the card.
        if let meeting = event.meetingURL, URL(string: value) == meeting { return "" }
        return value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !location.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "mappin.and.ellipse").frame(width: 16, height: 18)
                        .foregroundStyle(Palette.secondary).accessibilityHidden(true)
                    Text(location).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }.font(.system(size: 13))
            }
            if !notes.body.isEmpty {
                CalendarEventNotes(text: notes.body)
            }
            if !notes.meetingDetails.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Button { showMeetingDetails.toggle() } label: {
                        HStack(spacing: 6) {
                            CalendarDetailHeading("Meeting details")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .medium))
                                .rotationEffect(.degrees(showMeetingDetails ? 90 : 0))
                                .animation(reduceMotion ? nil : BeaconMotion.selection, value: showMeetingDetails)
                        }.font(.system(size: 13)).padding(.vertical, 4).contentShape(Rectangle())
                    }.buttonStyle(BeaconControlButtonStyle()).foregroundStyle(Palette.secondary)
                        .accessibilityValue(showMeetingDetails ? "Expanded" : "Collapsed")
                    BeaconDisclosure(isExpanded: showMeetingDetails) {
                        CalendarEventNotes(text: notes.meetingDetails, showsHeading: false)
                            .padding(.top, 10)
                    }
                }
            }
            CalendarPersonalNotes(event: event, store: model.personalNotes, media: model.personalMedia, isExpanded: isExpanded)
                .id(event.personalNotesKey)
                .padding(.top, 2)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    joinMeeting
                    Spacer(minLength: 16)
                    followUpButton
                }
                VStack(alignment: .leading, spacing: 8) {
                    joinMeeting
                    HStack { Spacer(minLength: 0); followUpButton }
                }
            }
            .padding(.top, 12)
            .overlay(alignment: .top) {
                Rectangle().fill(Palette.hairline.opacity(0.6)).frame(height: 1)
            }

        }
        .frame(maxWidth: Metrics.notesWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 27).padding(.trailing, 18).padding(.bottom, 18)
            .foregroundStyle(Palette.ink)
    }

    @ViewBuilder private var joinMeeting: some View {
        if let url = event.meetingURL {
            Button { if !model.isPreview { NSWorkspace.shared.open(url) } } label: {
                Label("Join meeting", systemImage: "video")
            }.buttonStyle(SwiftcnButtonStyle(variant: .primary, accent: TaskListModel.shared.accent.color))
                .disabled(model.isPreview)
                .help(model.isPreview ? "Meeting links are disabled in the sample preview" : "Open meeting link")
        }
    }

    private var followUpButton: some View {
        Button(action: followUp) {
            Label("Follow-up reminder", systemImage: "plus")
        }.buttonStyle(SwiftcnButtonStyle(variant: .quiet))
            .accessibilityLabel("Create a follow-up reminder")
    }
}


/// Shared quiet hierarchy for event descriptions and private notes.
private struct CalendarDetailHeading: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct CalendarPersonalNotes: View {
    let event: CalendarEventSnapshot
    var store: CalendarPersonalNotesStore
    var media: CalendarMediaStore
    let isExpanded: Bool
    @State private var editing = false
    @State private var hasCreatedEditor = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var key: String { event.personalNotesKey }
    private var text: String { store.text(for: key) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Both modes keep their natural layout while only the container
            // height interpolates. Once used, the native editor
            // stays mounted so Done never destroys a moving NSTextView.
            CalendarNoteModeLayout(progress: editing ? 1 : 0) {
                readMode
                    .geometryGroup()
                    .opacity(editing ? 0 : 1)
                    .transaction { $0.animation = nil }
                    .allowsHitTesting(!editing)
                    .accessibilityElement(children: editing ? .ignore : .contain)
                    .accessibilityHidden(editing)
                editMode
                    .geometryGroup()
                    .opacity(editing ? 1 : 0)
                    .transaction { $0.animation = nil }
                    .allowsHitTesting(editing && isExpanded)
                    .accessibilityElement(children: editing && isExpanded ? .contain : .ignore)
                    .accessibilityHidden(!editing || !isExpanded)
            }
            .clipped()
            .contentShape(Rectangle())
            .animation(reduceMotion ? nil : BeaconMotion.disclosure, value: editing)
            CalendarPersonalMedia(store: media, noteKey: key)
            if let error = store.error(for: key) {
                Text(error).font(.taskMeta).foregroundStyle(Palette.secondary)
                Button("Retry saving") { store.set(text, for: key) }.buttonStyle(SwiftcnButtonStyle())
            }
        }
        .onChange(of: isExpanded) { _, active in
            if !active { editing = false }
        }
    }

    private var readMode: some View {
        VStack(alignment: .leading, spacing: 8) {
            heading(isEditing: false)
            if !text.isEmpty {
                CalendarEventNotes(text: text, showsHeading: false)
            }
        }
    }

    private var editMode: some View {
        VStack(alignment: .leading, spacing: 8) {
            heading(isEditing: true)
            if hasCreatedEditor {
                BeaconNotesEditor(text: Binding(get: { text }, set: { store.set($0, for: key) }),
                                  autofocus: true, isActive: editing && isExpanded,
                                  editorFont: .system(size: 14), editorHeight: 96,
                                  placeholder: "Add a note for yourself…",
                                  onSubmit: { setEditing(false) })
                    .accessibilityLabel("Personal event notes")
            } else {
                // Reserve the native editor's final height without eagerly
                // allocating a text view for every closed calendar event.
                Color.clear.frame(height: 96).accessibilityHidden(true)
            }
        }
    }

    private func heading(isEditing: Bool) -> some View {
        HStack(spacing: 6) {
            CalendarDetailHeading("Personal note")
            Image(systemName: "lock")
                .font(.system(size: 10))
                .foregroundStyle(Palette.tertiary)
                .help("Only on this Mac. Saves automatically and never syncs to your calendar.")
                .accessibilityLabel("Saved automatically on this Mac only")
            Spacer(minLength: 8)
            Button { setEditing(!isEditing) } label: {
                Text(isEditing ? "Done" : text.isEmpty ? "Add note" : "Edit")
                .font(.system(size: 12, weight: .medium))
                .frame(minWidth: 28, minHeight: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(BeaconControlButtonStyle())
            .help(isEditing ? "Done · Enter to finish, Shift+Enter for a new line" : "Only on this Mac. Personal notes never sync to your calendar.")
            .accessibilityLabel(isEditing ? "Done editing personal note" : text.isEmpty ? "Add personal note" : "Edit personal note")
        }
        .foregroundStyle(Palette.secondary)
    }

    private func setEditing(_ value: Bool) {
        if value { hasCreatedEditor = true }
        editing = value
    }
}

/// The native editor and read-only note each receive their final height, even
/// while their parent height is between the two. No text frame is interpolated.
private struct CalendarNoteModeLayout: Layout {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let natural = ProposedViewSize(width: proposal.width, height: nil)
        let sizes = subviews.map { $0.sizeThatFits(natural) }
        guard let read = sizes.first else { return .zero }
        let edit = sizes.count > 1 ? sizes[1] : read
        let fraction = min(1, max(0, progress))
        return CGSize(width: max(read.width, edit.width),
                      height: read.height + (edit.height - read.height) * fraction)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            subview.place(at: bounds.origin, anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: size.height))
        }
    }
}

/// The displayed text always has an unlimited line count. The hidden preview
/// supplies a collapsed height to the synchronous layout, not to @State frames.
private struct CalendarEventNotes: View {
    let text: String
    var showsHeading = true
    @State private var expanded = false
    @State private var fullHeight: CGFloat = 0
    @State private var previewHeight: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var overflows: Bool { fullHeight > previewHeight + 1 }

    private var bodyText: some View {
        Text(text).font(.system(size: 14)).lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if showsHeading { CalendarDetailHeading("Event notes") }
            BeaconRevealLayout(progress: expanded ? 1 : 0) {
                bodyText
                    .fixedSize(horizontal: false, vertical: true)
                    .geometryGroup()
                    .textSelection(.disabled)
                    // These observations only control the button's presence.
                    // Neither reported height is used to lay out visible text.
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fullHeight = ceil($0) }
                    .transaction { $0.animation = nil }
                bodyText.lineLimit(5).fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { previewHeight = ceil($0) }
                    .hidden().accessibilityHidden(true).allowsHitTesting(false)
                    .transaction { $0.animation = nil }
            }
                .clipped()
                .contentShape(Rectangle())
                .animation(reduceMotion ? nil : BeaconMotion.disclosure, value: expanded)
                .contextMenu {
                    Button("Copy notes") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                }
            if overflows {
                Button(expanded ? "Show less" : "Show full notes") { expanded.toggle() }
                    .buttonStyle(BeaconControlButtonStyle()).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TaskListModel.shared.accent.color)
                    .accessibilityValue(expanded ? "Expanded" : "Collapsed")
            }
        }
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
        VStack(alignment: .leading, spacing: 4) {
            BeaconScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if events.isEmpty {
                        Text(model.feed.isRefreshing ? "Loading upcoming events…" : "No upcoming events match. Check your keywords and calendar toggles.")
                            .font(.taskMeta).foregroundStyle(Palette.secondary).padding(.vertical, 28)
                    }
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        if index == 0 || !Calendar.current.isDate(event.start, inSameDayAs: events[index - 1].start) {
                            Text(event.start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.secondary)
                                .padding(.top, index == 0 ? 4 : 18).padding(.bottom, 6)
                                .accessibilityAddTraits(.isHeader)
                        }
                        CalendarEventCard(event: event, model: model, selectedID: $selectedID, followUp: followUp)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(CalendarAgendaMotion(selection: selectedID))
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
        VStack(alignment: .leading, spacing: 16) {
            BeaconSettingsGroup(title: "Next 7 days",
                                detail: "Choose which events appear. Keywords ignore uppercase and lowercase.") {
                VStack(alignment: .leading, spacing: 18) {
                    keywordList("Include", values: model.includeKeywords, draft: $includeDraft, excluding: false)
                    keywordList("Exclude", values: model.excludeKeywords, draft: $excludeDraft, excluding: true)
                }
            }
            BeaconSettingsDivider().padding(.top, 6)
            BeaconSettingsRow(title: "Manually added events",
                              detail: "Override keywords for individual events. Calendar toggles still apply.") {
                UpcomingEventAddButton(model: model)
            }
            ForEach(model.manuallyIncludedEvents) { event in
                HStack(spacing: 12) {
                    UpcomingEventSelectionLabel(event: event, model: model)
                    Spacer(minLength: 8)
                    Button { model.setManuallyIncluded(event, included: false) } label: {
                        Image(systemName: "xmark").frame(width: 28, height: 28)
                    }.buttonStyle(BeaconControlButtonStyle()).accessibilityLabel("Remove manual inclusion for \(event.title)")
                }
            }
            if model.manuallyIncludedEvents.isEmpty {
                Text("No events added this week.").font(.system(size: 12)).foregroundStyle(Palette.secondary)
            }
        }
    }
    private func keywordList(_ label: String, values: [String], draft: Binding<String>, excluding: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(label).font(.system(size: 13)).foregroundStyle(Palette.ink)
                .frame(width: 56, alignment: .leading).padding(.top, 8)
            VStack(alignment: .leading, spacing: 8) {
                if !values.isEmpty {
                    FlowRow(spacing: 6) {
                        ForEach(values, id: \.self) { keyword in
                            Button {
                                model.setKeywords(values.filter { $0 != keyword }, excluding: excluding)
                            } label: {
                                HStack(spacing: 8) {
                                    Text(keyword).lineLimit(2).multilineTextAlignment(.leading)
                                    Image(systemName: "xmark").font(.system(size: 9))
                                }.font(.system(size: 12)).foregroundStyle(Palette.ink)
                                    .padding(.horizontal, 9).padding(.vertical, 6)
                                    .background(Palette.band, in: RoundedRectangle(cornerRadius: 6))
                                    .frame(maxWidth: 250).contentShape(Rectangle())
                            }.buttonStyle(BeaconControlButtonStyle())
                                .accessibilityLabel("Remove \(label.lowercased()) keyword \(keyword)")
                        }
                    }
                }
                HStack(spacing: 6) {
                    TextField("Add keyword…", text: draft)
                        .font(.system(size: 13)).textFieldStyle(.plain)
                        .padding(.horizontal, 10).frame(height: 32)
                        .modifier(SwiftcnInputSurface()).accessibilityLabel("\(label) keyword")
                        .onSubmit { add(draft, excluding: excluding) }
                    Button("Add") { add(draft, excluding: excluding) }
                        .buttonStyle(SwiftcnButtonStyle(variant: .quiet))
                        .disabled(draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Add \(label.lowercased()) keyword")
                }
                Text(excluding ? "Excluded keywords take priority." : "Any matching title. Empty includes everything.")
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
    var variant: SwiftcnButtonStyle.Variant = .outline
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
        }.buttonStyle(SwiftcnButtonStyle(variant: variant))
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
                        }.buttonStyle(BeaconControlButtonStyle()).keyboardShortcut(.cancelAction).accessibilityLabel("Close event picker")
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
