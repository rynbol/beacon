import SwiftUI
import BeaconKit

struct SettingsView: View {
    var model: TaskListModel
    let dismiss: () -> Void
    var initiallyCalendars = false
    var initiallyNotifications = false
    private enum Section: String, CaseIterable { case appearance = "Appearance", calendars = "Calendars", alerts = "Notifications", snooze = "Snooze", help = "Help" }
    @State private var section: Section = .appearance

    var body: some View {
        ZStack {
            Button(action: dismiss) {
                Color.black.opacity(0.12).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Dismiss settings")
            settingsCard
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.14), radius: 24, y: 8)
                .padding(24)
        }
    }

    private var settingsCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings").font(.system(size: 19, weight: .semibold))
                    .frame(height: 28)
                    .padding(.horizontal, 10).padding(.top, 12).padding(.bottom, 16)
                ForEach(Section.allCases, id: \.self) { item in
                    Button { section = item } label: {
                        Text(item.rawValue).font(.system(size: 13, weight: section == item ? .medium : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).frame(height: 34)
                            .foregroundStyle(section == item ? Palette.ink : Palette.secondary)
                            .background(section == item ? Palette.card : .clear, in: RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityAddTraits(section == item ? .isSelected : [])
                }
                Spacer()
            }.padding(12).frame(width: 154).background(Palette.band)
            Rectangle().fill(Palette.hairline).frame(width: 1)
            VStack(spacing: 0) {
                HStack {
                    Text(section.rawValue).font(.system(size: 19, weight: .semibold))
                    Spacer()
                    Button(action: dismiss) {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .medium))
                            .frame(width: 28, height: 28).contentShape(Rectangle())
                    }.buttonStyle(.plain).keyboardShortcut(.cancelAction)
                        .foregroundStyle(Palette.secondary)
                        .accessibilityLabel("Close settings").help("Close settings · Esc")
                }.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 16)
                BeaconScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch section {
                        case .appearance:
                            ThemePicker()
                            accentSection
                            Divider()
                            groupingSection
                            UrgencyColorSettings()
                        case .help:
                            siriSection
                            aboutSection
                        case .calendars:
                            UpcomingKeywordSettings(model: .shared)
                            calendarSection
                        case .alerts:
                            notificationSection
                            quietHoursSection
                        case .snooze:
                            ladderSection
                        }
                    }.padding(.horizontal, 24).padding(.bottom, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.scrollContentBackground(.hidden).id(section)
            }.frame(maxWidth: .infinity).background(Palette.washTop)
        }
        .foregroundStyle(Palette.ink)
        .frame(width: 700).frame(maxHeight: 600)
        .onAppear {
            if initiallyCalendars { section = .calendars }
            else if initiallyNotifications { section = .alerts }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.ink)
    }

    private var accentSection: some View {
        HStack {
            Text("Highlight").font(.system(size: 13, weight: .semibold))
            Spacer()
            HStack(spacing: 10) {
                ForEach(Accent.allCases) { option in
                    Button { model.setAccent(option) } label: {
                        RoundedRectangle(cornerRadius: 7).fill(option.color).frame(width: 30, height: 30)
                            .overlay {
                                if model.accent == option { Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.onAccent) }
                            }
                    }.buttonStyle(.plain).help(option.title).accessibilityLabel("\(option.title) highlight")
                        .accessibilityAddTraits(model.accent == option ? .isSelected : [])
                }
            }
        }
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Alerts")
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remind me").font(.rowLabel).foregroundStyle(Palette.ink)
                        Text(alertsDetail).font(.taskMeta).foregroundStyle(Palette.secondary)
                    }
                    Spacer()
                    Toggle("Enable Beacon notifications", isOn: Binding(
                        get: { model.alertsEnabled },
                        set: { on in Task { await model.setAlertsEnabled(on) } }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
                .padding(.horizontal, Metrics.gutter)
                .frame(minHeight: 54)

                if model.alertsEnabled, model.authorization != .granted {
                    InsetDivider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.authorization == .denied
                                 ? "macOS is blocking Beacon's alerts"
                                 : "Beacon has not asked yet")
                                .font(.rowLabel).foregroundStyle(Palette.ink)
                            Text(model.authorization == .denied
                                 ? "Turn Beacon on in System Settings > Notifications."
                                 : "Allow alerts so Beacon can remind you.")
                                .font(.taskMeta).foregroundStyle(Palette.secondary)
                        }
                        Spacer()
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
                    .padding(.horizontal, Metrics.gutter)
                    .frame(minHeight: 54)
                }

                InsetDivider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hearing duplicate alerts?")
                            .font(.rowLabel).foregroundStyle(Palette.ink)
                        Text("If you hear duplicate alerts, adjust Apple Reminders in System Settings.")
                            .font(.taskMeta).foregroundStyle(Palette.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, Metrics.gutter)
                .frame(minHeight: 54)
            }
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
        HStack {
            Text("Group reminders").font(.system(size: 13, weight: .semibold))
            Spacer()
            Picker("Group reminders", selection: Binding(get: { model.grouping }, set: { model.setGrouping($0) })) {
                ForEach(Grouping.allCases) { Text($0.title).tag($0) }
            }.labelsHidden().pickerStyle(.menu).fixedSize()
        }.padding(.vertical, 4)
    }

    private var ladderSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Snooze intervals")
            Card {
                ForEach(Array(model.settings.ladder.enumerated()), id: \.offset) { index, interval in
                    HStack {
                        Text("Snooze \(index + 1)")
                            .font(.rowLabel).foregroundStyle(Palette.ink)
                        Spacer()
                        Text(IntervalText.short(interval))
                            .font(.rowLabel).monospacedDigit()
                            .foregroundStyle(Palette.secondary)
                        Stepper("Snooze \(index + 1) interval") {
                            model.adjustLadder(at: index, by: 1)
                        } onDecrement: {
                            model.adjustLadder(at: index, by: -1)
                        }
                        .labelsHidden()
                    }
                    .padding(.horizontal, Metrics.gutter)
                    .frame(height: 42)

                    if index < model.settings.ladder.count - 1 { InsetDivider() }
                }
            }
            Text("Each snooze moves a task one step down this list. The last step repeats.")
                .font(.taskMeta).foregroundStyle(Palette.tertiary)
        }
    }

    private var quietHoursSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Quiet hours")
            Card {
                HStack {
                    Text("From").font(.rowLabel).foregroundStyle(Palette.ink)
                    Spacer()
                    hourPicker(
                        label: "Quiet hours start", value: Binding(
                            get: { model.settings.quietStartHour },
                            set: { model.setQuietHours(start: $0, end: model.settings.quietEndHour) }
                        )
                    )
                }
                .padding(.horizontal, Metrics.gutter)
                .frame(height: 46)

                InsetDivider()

                HStack {
                    Text("Until").font(.rowLabel).foregroundStyle(Palette.ink)
                    Spacer()
                    hourPicker(
                        label: "Quiet hours end", value: Binding(
                            get: { model.settings.quietEndHour },
                            set: { model.setQuietHours(start: model.settings.quietStartHour, end: $0) }
                        )
                    )
                }
                .padding(.horizontal, Metrics.gutter)
                .frame(height: 46)
            }
            Text("Automatic alerts wait until quiet hours end. Manual snoozes keep their chosen time.")
                .font(.taskMeta).foregroundStyle(Palette.tertiary)
        }
    }

    private func hourPicker(label: String, value: Binding<Int>) -> some View {
        Picker(label, selection: value) {
            ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour)).tag(hour)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
    }

    private var siriSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Siri & dictation")
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Say “Add a reminder in Beacon,” then tell Siri what to remember.")
                    Text("Say “Remind me to…” as usual. No date means Someday; “today,” “tomorrow,” or a time keeps that schedule.")
                    Text("Dictate in Beacon: ⌘⇧M. The Mac’s ⌘M shortcut still minimizes the window.")
                    Button("Open Shortcuts") {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.shortcuts") {
                            NSWorkspace.shared.open(url)
                        }
                    }.buttonStyle(.link)
                }.font(.taskMeta).foregroundStyle(Palette.secondary).padding(Metrics.gutter)
            }
        }
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Calendars")
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    CalendarConnection(model: .shared)
                    if CalendarModel.shared.feed.access == .granted {
                        CalendarFilters(model: .shared)
                    }
                    DisclosureGroup("Accounts & sync") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Add Google in Apple Calendar → Add Account. Beacon reads the calendars synced to this Mac. Press ⌘R to refresh; remote changes appear as macOS syncs them.")
                            Text("Colors apply only to Beacon. Event alerts stay in Calendar.")
                            Button("Open Apple Calendar") {
                                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") { NSWorkspace.shared.open(url) }
                            }.buttonStyle(.link)
                        }.font(.taskMeta).foregroundStyle(Palette.secondary).padding(.top, 8)
                    }.font(.taskMeta).foregroundStyle(Palette.secondary)
                }.padding(Metrics.gutter)
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("About")
            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your tasks live in Apple Reminders. Beacon stores your preferences, snooze timing, and muted reminders locally.")
                    Text("Delete Beacon and every task is still there.")
                }
                .font(.taskMeta)
                .foregroundStyle(Palette.secondary)
                .padding(Metrics.gutter)
            }
        }
    }
}
