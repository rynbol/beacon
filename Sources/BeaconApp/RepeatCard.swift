import SwiftUI
import BeaconKit

/// The repeat editor: the controls, then the rule written out as a sentence,
/// then the next three dates it actually produces.
///
/// The sentence and the date list are not decoration. A repeat rule is easy to
/// misread — "every 2 weeks on Tuesday" and "every Tuesday" look alike in a row
/// of steppers — and three real dates are the only unambiguous proof of what
/// was configured.
struct RepeatCard: View {
    @Binding var recurrence: Recurrence
    let due: Date?
    let accent: Color
    let remove: () -> Void

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Card {
                frequencyRow
                InsetDivider()
                intervalRow
                if recurrence.frequency == .weekly {
                    InsetDivider()
                    weekdayRow
                }
                InsetDivider()
                endRow
            }

            if case let .on(end) = recurrence.end {
                DatePicker("End date", selection: Binding(get: {
                    if case let .on(date) = recurrence.end { return date }
                    return end
                }, set: { recurrence.end = .on($0) }), displayedComponents: .date)
                    .font(.taskMeta)
            }

            Text(recurrence.sentence(calendar: calendar))
                .font(.taskMeta)
                .foregroundStyle(Palette.secondary)

            if !occurrences.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Next:").font(.taskMeta).foregroundStyle(Palette.secondary)
                    ForEach(occurrences, id: \.self) { date in
                        Text("• " + longDate(date))
                            .font(.taskMeta)
                            .monospacedDigit()
                            .foregroundStyle(Palette.tertiary)
                    }
                }
            }

            Button("Remove repeat", action: remove)
                .buttonStyle(.plain)
                .font(.taskMeta)
                .foregroundStyle(Palette.tertiary)
                .accessibilityLabel("Remove repeat")
        }
    }

    private var occurrences: [Date] {
        recurrence.nextOccurrences(after: due ?? .now, count: 3, calendar: calendar)
    }

    private func longDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Rows

    private var frequencyRow: some View {
        HStack {
            Text("Repeat").font(.rowLabel).foregroundStyle(Palette.ink)
            Spacer()
            Picker("Repeat frequency", selection: $recurrence.frequency) {
                ForEach(Recurrence.Frequency.allCases, id: \.self) { frequency in
                    Text(frequency.title).tag(frequency)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
        .padding(.horizontal, Metrics.gutter)
        .frame(height: 46)
    }

    private var intervalRow: some View {
        HStack {
            Text(intervalLabel).font(.rowLabel).foregroundStyle(Palette.ink)
            Spacer()
            HStack(spacing: 0) {
                stepperButton("minus") {
                    recurrence.interval = max(1, recurrence.interval - 1)
                }
                Rectangle().fill(Palette.hairline).frame(width: 1, height: 16)
                stepperButton("plus") {
                    recurrence.interval = min(99, recurrence.interval + 1)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Palette.control)
            )
        }
        .padding(.horizontal, Metrics.gutter)
        .frame(height: 46)
    }

    private var intervalLabel: String {
        recurrence.interval == 1
            ? "Every \(recurrence.frequency.singular)"
            : "Every \(recurrence.interval) \(recurrence.frequency.plural)"
    }

    private func stepperButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 34, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "minus" ? "Decrease repeat interval" : "Increase repeat interval")
    }

    private var weekdayRow: some View {
        FlowRow(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                Chip(
                    label: calendar.shortWeekdaySymbols[day - 1],
                    isSelected: recurrence.daysOfWeek.contains(day),
                    accent: accent
                ) {
                    if recurrence.daysOfWeek.contains(day) {
                        // Never leave zero days selected: a weekly rule with no
                        // day cannot say what it means.
                        if recurrence.daysOfWeek.count > 1 {
                            recurrence.daysOfWeek.remove(day)
                        }
                    } else {
                        recurrence.daysOfWeek.insert(day)
                    }
                }
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 10)
    }

    private var endRow: some View {
        HStack {
            Text("End Repeat").font(.rowLabel).foregroundStyle(Palette.ink)
            Spacer()
            Picker("End repeat", selection: endSelection) {
                Text("Never").tag(0)
                Text("After a count").tag(1)
                Text("On a date").tag(2)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()

            if case let .after(count) = recurrence.end {
                Text("\(count)")
                    .font(.rowLabel)
                    .monospacedDigit()
                    .foregroundStyle(Palette.secondary)
                Stepper("Repeat count") {
                    recurrence.end = .after(min(99, count + 1))
                } onDecrement: {
                    recurrence.end = .after(max(1, count - 1))
                }
                .labelsHidden()
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .frame(height: 46)
    }

    private var endSelection: Binding<Int> {
        Binding(
            get: {
                switch recurrence.end {
                case .never: return 0
                case .after: return 1
                case .on: return 2
                }
            },
            set: { choice in
                switch choice {
                case 1: recurrence.end = .after(10)
                case 2:
                    let year = calendar.date(byAdding: .year, value: 1, to: .now) ?? .now
                    recurrence.end = .on(year)
                default: recurrence.end = .never
                }
            }
        )
    }
}
