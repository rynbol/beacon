import SwiftUI
import BeaconKit

struct SettingsView: View {
    var model: TaskListModel
    let dismiss: () -> Void
    private enum Section: String, CaseIterable { case appearance = "Appearance", calendars = "Calendars", alerts = "Notifications", snooze = "Snooze", help = "Help" }
    @Namespace private var sectionHighlight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var section: Section
    @State private var activeChoices: Set<UUID> = []
    private var choosingOption: Bool { !activeChoices.isEmpty }

    init(model: TaskListModel, dismiss: @escaping () -> Void,
         initiallyCalendars: Bool = false, initiallyNotifications: Bool = false) {
        self.model = model
        self.dismiss = dismiss
        // Build the requested pane on the first frame, without an appearance
        // pane replacement competing with the modal entrance.
        _section = State(initialValue: initiallyCalendars ? .calendars : initiallyNotifications ? .alerts : .appearance)
    }

    var body: some View {
        ZStack {
            Button(action: dismiss) {
                Color.clear.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Dismiss settings").disabled(choosingOption)
            settingsCard
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.14), radius: 24, y: 8)
                .padding(24)
        }.environment(\.beaconChoicePresentation, $activeChoices)
    }

    private var settingsCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings").font(.system(size: 17, weight: .semibold))
                    .frame(height: 28)
                    .padding(.horizontal, 10).padding(.top, 12).padding(.bottom, 16)
                ForEach(Section.allCases, id: \.self) { item in
                    Button { section = item } label: {
                        Text(item.rawValue).font(.system(size: 13, weight: section == item ? .medium : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).frame(height: 34)
                            .foregroundStyle(section == item ? Palette.ink : Palette.secondary)
                            .background {
                                ZStack {
                                    if section == item {
                                        RoundedRectangle(cornerRadius: 6).fill(Palette.card)
                                            .matchedGeometryEffect(id: "selection", in: sectionHighlight)
                                    }
                                }
                                .animation(reduceMotion ? nil : BeaconMotion.selection, value: section)
                                .allowsHitTesting(false)
                            }
                            .contentShape(Rectangle())
                    }.buttonStyle(BeaconControlButtonStyle())
                        .accessibilityAddTraits(section == item ? .isSelected : [])
                }
                Spacer()
            }.padding(12).frame(width: 148).background(Palette.band)
            Rectangle().fill(Palette.hairline).frame(width: 1)
            VStack(spacing: 0) {
                HStack {
                    Text(section.rawValue).font(.system(size: 19, weight: .semibold))
                    Spacer()
                    Button(action: dismiss) {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .medium))
                            .frame(width: 28, height: 28).contentShape(Rectangle())
                    }.buttonStyle(BeaconControlButtonStyle()).keyboardShortcut(.cancelAction)
                        .foregroundStyle(Palette.secondary)
                        .accessibilityLabel("Close settings").help("Close settings · Esc").disabled(choosingOption)
                }.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 16)
                BeaconScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        switch section {
                        case .appearance:
                            appearanceSection
                        case .help:
                            siriSection
                            aboutSection
                        case .calendars:
                            calendarSection
                            BeaconSettingsDivider()
                            UpcomingKeywordSettings(model: .shared)
                        case .alerts:
                            notificationSection
                            quietHoursSection
                        case .snooze:
                            ladderSection
                        }
                    }.padding(.horizontal, 24).padding(.bottom, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.scrollContentBackground(.hidden).id(section)
                    .modifier(BeaconSectionMotion(value: section, axis: .vertical))
            }.frame(maxWidth: .infinity).background(Palette.washTop)
        }
        .foregroundStyle(Palette.ink)
        .frame(width: 700).frame(maxHeight: 600)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ThemePicker().padding(.bottom, 10)
            BeaconSettingsDivider()
            accentSection
            BeaconSettingsDivider()
            groupingSection
            BeaconSettingsDivider()
            UrgencyColorSettings().padding(.top, 12)
        }
    }

    private var accentSection: some View {
        BeaconSettingsRow(title: "Highlight") {
            HStack(spacing: 10) {
                ForEach(Accent.allCases) { option in
                    Button { model.setAccent(option) } label: {
                        RoundedRectangle(cornerRadius: 7).fill(option.color).frame(width: 30, height: 30)
                            .overlay {
                                if model.accent == option { Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.onAccent) }
                            }
                    }.buttonStyle(BeaconControlButtonStyle()).help(option.title).accessibilityLabel("\(option.title) highlight")
                        .accessibilityAddTraits(model.accent == option ? .isSelected : [])
                }
            }
        }
    }

    private var notificationSection: some View {
        BeaconSettingsGroup(title: "Reminder alerts") {
            BeaconSettingsRow(title: "Remind me", detail: alertsDetail) {
                Toggle("Enable Beacon notifications", isOn: Binding(
                    get: { model.alertsEnabled },
                    set: { on in Task { await model.setAlertsEnabled(on) } }
                ))
                .labelsHidden().toggleStyle(.switch)
            }
            if model.alertsEnabled, model.authorization != .granted {
                BeaconSettingsDivider()
                BeaconSettingsRow(title: "macOS permission", detail: model.authorization == .denied
                                  ? "Turn Beacon on in System Settings → Notifications."
                                  : "Allow notifications to receive reminder alerts.") {
                    Chip(label: model.authorization == .denied ? "Open" : "Allow",
                         isSelected: true, accent: model.accent.color) {
                        if model.authorization == .denied {
                            let path = "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
                            if let url = URL(string: path) { NSWorkspace.shared.open(url) }
                        } else {
                            Task { await model.enableNotifications() }
                        }
                    }
                }
            }
            DisclosureGroup("Duplicate alerts") {
                Text("If Apple Reminders also sends alerts, adjust its notifications in System Settings.")
                    .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 6)
            }
            .font(.system(size: 12)).foregroundStyle(Palette.secondary).padding(.top, 12)
        }
    }

    private var alertsDetail: String {
        guard model.alertsEnabled else {
            return "Off. Reminders stay in your list."
        }
        switch model.authorization {
        case .granted: return "\(model.pendingCount) alerts are scheduled."
        case .notAsked: return "Beacon still needs permission from macOS."
        case .denied: return "macOS is blocking them."
        }
    }

    private var groupingSection: some View {
        BeaconSettingsRow(title: "Group reminders") {
            BeaconChoicePicker(label: "Group reminders",
                selection: Binding(get: { model.grouping }, set: { model.setGrouping($0) }),
                options: Grouping.allCases.map { BeaconChoice(value: $0, title: $0.title) })
        }
    }

    private var ladderSection: some View {
        BeaconSettingsGroup(title: "Snooze intervals",
                            detail: "Each snooze moves to the next interval. The final interval repeats.") {
            ForEach(Array(model.settings.ladder.enumerated()), id: \.offset) { index, interval in
                BeaconSettingsRow(title: "Snooze \(index + 1)") {
                    HStack {
                        Text(IntervalText.short(interval))
                            .font(.system(size: 13)).monospacedDigit()
                            .foregroundStyle(Palette.secondary)
                            .frame(minWidth: 70, alignment: .trailing)
                        BeaconStepper(label: "Snooze \(index + 1) interval",
                            decrease: { model.adjustLadder(at: index, by: -1) },
                            increase: { model.adjustLadder(at: index, by: 1) })
                    }
                }
                if index < model.settings.ladder.count - 1 { BeaconSettingsDivider() }
            }
        }
    }

    private var quietHoursSection: some View {
        BeaconSettingsGroup(title: "Quiet hours",
                            detail: "Automatic alerts wait until quiet hours end. Manual snoozes keep their chosen time.") {
                BeaconSettingsRow(title: "From") {
                    hourPicker(
                        label: "Quiet hours start", value: Binding(
                            get: { model.settings.quietStartHour },
                            set: { model.setQuietHours(start: $0, end: model.settings.quietEndHour) }
                        )
                    )
                }
                BeaconSettingsDivider()
                BeaconSettingsRow(title: "Until") {
                    hourPicker(
                        label: "Quiet hours end", value: Binding(
                            get: { model.settings.quietEndHour },
                            set: { model.setQuietHours(start: model.settings.quietStartHour, end: $0) }
                        )
                    )
                }
        }
    }

    private func hourPicker(label: String, value: Binding<Int>) -> some View {
        BeaconChoicePicker(label: label, selection: value,
            options: (0..<24).map { BeaconChoice(value: $0, title: String(format: "%02d:00", $0)) })
    }

    private var siriSection: some View {
        VStack(alignment: .leading, spacing: 26) {
            BeaconSettingsGroup(title: "Siri") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Say “Add a reminder in Beacon,” then tell Siri what to remember.")
                    Text("Say “Remind me to…” as usual. No date means Someday; “today,” “tomorrow,” or a time keeps that schedule.")
                    Button("Open Shortcuts") {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.shortcuts") {
                            NSWorkspace.shared.open(url)
                        }
                    }.buttonStyle(.link)
                }.font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            BeaconSettingsGroup(title: "Dictation") {
                BeaconSettingsRow(title: "Dictate a reminder", detail: "Use the microphone in the reminder title field.") {
                    Text("⌘⇧M").font(.system(size: 12, design: .monospaced)).foregroundStyle(Palette.secondary)
                }
            }
        }
    }

    private var calendarSection: some View {
        BeaconSettingsGroup(title: "Connected calendars") {
            VStack(alignment: .leading, spacing: 12) {
                if CalendarModel.shared.feed.access != .granted || CalendarModel.shared.feed.error != nil {
                    CalendarConnection(model: .shared)
                }
                if CalendarModel.shared.feed.access == .granted {
                    CalendarFilters(model: .shared)
                    if CalendarModel.shared.feed.calendars.isEmpty {
                        Text("No calendars available on this Mac.")
                            .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    }
                }
                DisclosureGroup("Accounts & sync") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Beacon reads the calendars connected to this Mac. Add Google in Apple Calendar → Add Account.")
                        Text("Press ⌘R to refresh. Remote changes appear as macOS syncs them. Colors apply only to Beacon; event alerts stay in Calendar.")
                        Button("Open Apple Calendar") {
                            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") { NSWorkspace.shared.open(url) }
                        }.buttonStyle(.link)
                    }.font(.system(size: 12)).foregroundStyle(Palette.secondary)
                        .fixedSize(horizontal: false, vertical: true).padding(.top, 8)
                }.font(.system(size: 12)).foregroundStyle(Palette.secondary)
            }
        }
    }

    private var aboutSection: some View {
        BeaconSettingsGroup(title: "Your data") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your tasks live in Apple Reminders. Beacon stores your preferences, snooze timing, and muted reminders locally.")
                Text("Delete Beacon and every task is still there.")
            }
            .font(.system(size: 12)).foregroundStyle(Palette.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
