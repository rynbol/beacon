import SwiftUI
import BeaconKit

/// The due-time presets. Their labels change once a task repeats, because
/// "15 minutes" is meaningless on something that already recurs daily.
enum DueChip: Identifiable, Hashable {
    case minutes(Int)
    case hours(Int)
    case moreDays(Int)
    case today
    case tomorrow
    case days(Int)
    /// Deferred indefinitely: kept and listed, never nagged about.
    case someday

    var id: String { label }

    var label: String {
        switch self {
        case let .minutes(n): return "\(n) minutes"
        case let .hours(n): return n == 1 ? "1 hour" : "\(n) hours"
        case let .moreDays(n): return n == 1 ? "1 more day" : "\(n) more days"
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case let .days(n): return "\(n) days"
        case .someday: return "Someday"
        }
    }

    func date(from now: Date, calendar: Calendar) -> Date? {
        switch self {
        case let .minutes(n): return now.addingTimeInterval(TimeInterval(n) * 60)
        case let .hours(n): return now.addingTimeInterval(TimeInterval(n) * 3_600)
        case let .moreDays(n): return calendar.date(byAdding: .day, value: n, to: now)
        case .today: return now
        case .tomorrow:
            let next = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: next)
        case let .days(n):
            let next = calendar.date(byAdding: .day, value: n, to: now) ?? now
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: next)
        case .someday:
            return nil
        }
    }

    static let plain: [DueChip] = [
        .today, .minutes(15), .hours(1), .hours(2), .hours(4), .tomorrow, .days(7), .someday,
    ]
    static let repeating: [DueChip] = [
        .today, .hours(1), .moreDays(1), .moreDays(2), .moreDays(3), .moreDays(7),
    ]
}

struct TaskEditor: View {
    var model: TaskListModel
    let target: EditorTarget

    let dismiss: () -> Void
    @FocusState private var titleFocused: Bool

    @State private var title = ""
    @State private var notes = ""
    @State private var due: Date?
    @State private var chip: DueChip?
    @State private var recurrence: Recurrence?
    @State private var urgency: Urgency = .none
    @State private var listID: String?
    @State private var showingDatePicker = false
    @State private var loaded = false
    @State private var saving = false
    @State private var dictationUnavailable = false
    @State private var dictationStarting = false
    @State private var dictationTask: Task<Void, Never>?
    /// Whether the user chose the time themselves. The default selection is
    /// not a choice, so a date typed into the title still overrides it.
    @State private var chipWasChosen = false

    private var accent: Color { model.accent.color }
    private var isNew: Bool { if case .existing = target { return false } else { return true } }
    private var chips: [DueChip] { recurrence == nil ? DueChip.plain : DueChip.repeating }
    private var canSave: Bool { !saving && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        ZStack {
            Button(action: dismiss) {
                Color.black.opacity(0.12).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(saving || showingDatePicker)
            .accessibilityLabel("Dismiss reminder without saving")
            editorCard
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.14), radius: 24, y: 8)
                .padding(24)
        }
    }

    private var editorCard: some View {
        ZStack {
            Palette.wash.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                BeaconScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let error = model.writeError {
                            Text(error).font(.system(size: 12)).foregroundStyle(Palette.secondary)
                        }
                        titleField
                        chipRow
                        notesField
                        attachments
                        if let recurrence { RepeatCard(recurrence: bindingTo(recurrence), due: due, accent: accent) }
                        if !isNew { deleteButton }
                    }
                    .padding(Metrics.gutter)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(width: 520)
        .frame(maxHeight: 670)
        .onAppear {
            load()
            if case .new(dictate: true, defaultDue: _) = target {
                beginDictation()
            }
        }
        .onDisappear { dictationTask?.cancel() }
        .popover(isPresented: $showingDatePicker) {
            VStack {
                DatePicker(
                    "Remind me",
                    selection: Binding(
                        get: { due ?? Date().addingTimeInterval(3_600) },
                        set: { due = $0; chip = nil }
                    )
                )
                .datePickerStyle(.graphical)
                Button("Clear time") { due = nil; chip = nil; showingDatePicker = false }
                    .buttonStyle(.plain)
                    .font(.taskMeta)
                    .foregroundStyle(Palette.secondary)
            }
            .padding()
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Palette.card.opacity(0.8)))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)

            Spacer()
            Text(isNew ? "New reminder" : "Edit reminder")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Spacer()

            Button(saving ? "Saving…" : "Save", action: save)
                .buttonStyle(SwiftcnButtonStyle(variant: .primary, accent: accent))
            .disabled(!canSave)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 12)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Title").font(.fieldLabel).foregroundStyle(Palette.secondary)
            HStack(spacing: 10) {
                TextField("What would you like to remember?", text: $title, axis: .vertical)
                    .font(.captureField)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .focused($titleFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .modifier(SwiftcnInputSurface(focused: titleFocused))

                micButton
            }
            if dictationUnavailable {
                Text(SystemDictation.hint).font(.taskMeta).foregroundStyle(Palette.secondary)
            }
            if let due {
                HStack(spacing: 5) {
                    Image(systemName: "clock").font(.system(size: 10))
                    Text(Sections.relativeText(
                        for: TaskSnapshot(key: "", title: "", due: due, hasTimeOfDay: true),
                        now: .now, calendar: .current
                    ))
                    .monospacedDigit()
                    Button("Clear") { self.due = nil; chip = nil }
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.tertiary)
                }
                .font(.taskMeta)
                .foregroundStyle(Palette.secondary)
            } else if isNew, !chipWasChosen, let parsedDue = Capture.parse(title).due {
                Text("Detected: \(parsedDue.formatted(date: .abbreviated, time: .shortened))")
                    .font(.taskMeta).foregroundStyle(accent)
            } else {
                Text("No date set · Someday. Choose a date when you want a reminder.")
                    .font(.taskMeta)
                    .foregroundStyle(Palette.tertiary)
            }
        }
    }

    /// Focuses the field, then asks macOS to dictate into it. Beacon never
    /// touches the microphone itself.
    private var micButton: some View {
        Button(action: beginDictation) {
            Image(systemName: "mic")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.ink)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Palette.card))
        }
        .buttonStyle(.plain)
        .disabled(dictationStarting)
        .keyboardShortcut("m", modifiers: [.command, .shift])
        .help("Dictate into the title · ⌘⇧M")
        .accessibilityLabel("Dictate into the title")
    }

    private func beginDictation() {
        guard !dictationStarting else { return }
        titleFocused = true
        dictationStarting = true
        dictationUnavailable = false
        dictationTask = Task { @MainActor in
            let started = await SystemDictation.start()
            guard !Task.isCancelled else { return }
            dictationUnavailable = !started
            dictationStarting = false
        }
    }

    private var chipRow: some View {
        FlowRow(spacing: 8) {
            ForEach(chips) { option in
                Chip(label: option.label, isSelected: chip == option, accent: accent) {
                    chipWasChosen = true
                    if chip == option {
                        chip = nil; due = nil
                    } else {
                        chip = option
                        due = option.date(from: .now, calendar: .current)
                    }
                }
            }
            Chip(label: "Date", systemImage: "chevron.right", isSelected: false, accent: accent) {
                chipWasChosen = true
                showingDatePicker = true
            }
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes").font(.fieldLabel).foregroundStyle(Palette.secondary)
            BeaconNotesEditor(text: $notes)
        }
    }

    private var attachments: some View {
        Card {
            if case let .existing(task) = target, task.isRecurring, task.recurrence == nil {
                Text("This reminder uses a custom Apple repeat rule. Beacon preserves it; edit the rule in Apple Reminders.")
                    .font(.taskMeta).foregroundStyle(Palette.secondary).padding(16)
            } else if recurrence == nil {
                editorRow(icon: "arrow.trianglehead.2.clockwise.rotate.90", label: "Add Repeat") {
                    recurrence = Recurrence(
                        frequency: .weekly,
                        daysOfWeek: [Calendar.current.component(.weekday, from: due ?? .now)]
                    )
                    if due == nil { due = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) }
                }
                InsetDivider(leading: 46)
            }
            HStack(spacing: 10) {
                Image(systemName: urgency == .none ? "circle.slash" : "flag")
                    .foregroundStyle(UrgencyColors.shared.color(for: urgency)).frame(width: 30)
                Picker("Urgency", selection: $urgency) {
                    ForEach(Urgency.allCases, id: \.self) { level in
                        Label(level.title, systemImage: level == .none ? "circle.slash" : "flag").tag(level)
                    }
                }.pickerStyle(.menu).font(.rowLabel)
            }.padding(.horizontal, Metrics.gutter).frame(height: 46)
            InsetDivider(leading: 46)
            if model.lists.count > 1 {
                HStack {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14))
                        .foregroundStyle(accent)
                        .frame(width: 30)
                    Picker("", selection: $listID) {
                        ForEach(model.lists, id: \.id) { list in
                            Text(list.title).tag(Optional(list.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .font(.rowLabel)
                }
                .padding(.horizontal, Metrics.gutter)
                .frame(height: 46)
            }
        }
    }

    private func editorRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(accent)
                    .frame(width: 30)
                Text(label).font(.rowLabel).foregroundStyle(accent)
                Spacer()
            }
            .padding(.horizontal, Metrics.gutter)
            .frame(height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button("Delete reminder") {
            if case let .existing(task) = target {
                Task {
                    saving = true
                    await model.delete(task)
                    saving = false
                    if model.writeError == nil { dismiss() }
                }
            }
        }
        .buttonStyle(.plain)
        .font(.rowLabel)
        .foregroundStyle(Palette.secondary)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card)
        )
    }

    // MARK: - Behaviour

    private func bindingTo(_ value: Recurrence) -> Binding<Recurrence> {
        Binding(get: { recurrence ?? value }, set: { recurrence = $0 })
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        listID = model.selectedListID

        model.dismissWriteError()
        if case let .new(_, defaultDue) = target {
            due = defaultDue
            if let defaultDue {
                if Calendar.current.isDateInToday(defaultDue) { chip = .today }
                else if Calendar.current.isDateInTomorrow(defaultDue) { chip = .tomorrow }
                else { chip = nil }
            } else { chip = .someday }
        }

        if case let .followUp(event) = target {
            title = "Follow up on " + event.title
            notes = "From Calendar: " + event.start.formatted(date: .abbreviated, time: .shortened)
            if let url = event.meetingURL { notes += "\n" + url.absoluteString }
            due = nil; chip = .someday; chipWasChosen = true
        }

        if case let .existing(task) = target {
            urgency = task.urgency
            title = task.title
            notes = task.notes
            due = task.due
            recurrence = task.recurrence
            listID = task.listID.isEmpty ? model.selectedListID : task.listID
        }
        titleFocused = true
    }

    /// Lifts a date out of what was typed, and takes it out of the title.
    ///
    /// A typed date beats the Someday default, because typing "pay rent friday"
    /// is a clearer statement of intent than a default the user never touched.
    private func absorbTypedDate(_ text: String) {
        guard !chipWasChosen else { return }
        let parsed = Capture.parse(text)
        guard let parsedDue = parsed.due, parsed.title != text else { return }
        title = parsed.title
        due = parsedDue
        chip = nil
    }

    private func save() {
        guard canSave else { return }
        let parsed = Capture.parse(title)
        let useParsed = isNew && !chipWasChosen && parsed.due != nil
        let cleaned = (useParsed ? parsed.title : title).trimmingCharacters(in: .whitespacesAndNewlines)
        let chosenDue = useParsed ? parsed.due : due
        saving = true
        Task {
            switch target {
            case .new, .followUp:
                await model.create(
                    title: cleaned, due: chosenDue, notes: notes,
                    listID: listID, recurrence: recurrence, urgency: urgency
                )
            case let .existing(task):
                await model.update(
                    task, title: cleaned, due: chosenDue, notes: notes,
                    listID: listID, recurrence: recurrence, urgency: urgency == task.urgency ? nil : urgency
                )
            }
            saving = false
            if model.writeError == nil { dismiss() }
        }
    }
}

/// Wraps chips onto as many rows as they need, which the reference app's
/// two-row preset block requires.
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 400
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
