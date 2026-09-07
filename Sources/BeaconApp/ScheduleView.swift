import SwiftUI
import BeaconKit

/// A diagnostic: what the planner decided, against the real database.
///
/// It sends nothing. Notification delivery arrives in a later milestone; this
/// exists so the scheduling rules can be checked against real reminders before
/// anything is allowed to fire.
struct ScheduleView: View {
    let plan: Plan
    let accent: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Slots used", value: "\(plan.notifications.count) of 50")
                        .monospacedDigit()
                    if !plan.beaconOverflow.isEmpty {
                        LabeledContent("Without a daily task alert",
                                       value: "\(plan.beaconOverflow.count)")
                            .monospacedDigit()
                    }
                    if !plan.spacingDropped.isEmpty {
                        LabeledContent("Dropped to keep alerts apart",
                                       value: "\(plan.spacingDropped.count)")
                            .monospacedDigit()
                    }
                } header: {
                    Text("Budget")
                } footer: {
                    Text("This is the current plan. Delivery depends on the Alerts setting and macOS notification permissions.")
                }

                ForEach(Array(kinds), id: \.self) { kind in
                    let entries = plan.notifications.filter { $0.kind == kind }
                    if !entries.isEmpty {
                        Section(title(for: kind)) {
                            ForEach(entries) { entry in
                                HStack {
                                    Text(entry.title).lineLimit(1)
                                    Spacer(minLength: 12)
                                    Text(when(entry.trigger))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Schedule")
            .scrollContentBackground(.hidden)
            .background(Palette.wash)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(accent)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 520)
    }

    private var kinds: [PlannedNotification.Kind] { [.digest, .taskBeacon, .ladder] }

    private func title(for kind: PlannedNotification.Kind) -> String {
        switch kind {
        case .digest: return "Daily check-in"
        case .taskBeacon: return "Daily reminder per task"
        case .ladder: return "Today"
        }
    }

    private func when(_ trigger: PlannedTrigger) -> String {
        switch trigger {
        case let .repeatingDaily(hour, minute):
            return String(format: "every day %02d:%02d", hour, minute)
        case let .oneShot(date):
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE HH:mm"
            return formatter.string(from: date)
        }
    }
}
