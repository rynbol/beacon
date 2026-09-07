import SwiftUI

/// Accent choices. The app this copies added a colour setting in 1.0.3 for the
/// same reason it is here: a permanently red interface reads as an alarm, and
/// this app is built not to nag in that register.
enum Accent: String, CaseIterable, Identifiable, Sendable {
    case ocean, terracotta, olive, indigo, espresso

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ocean: return "Ocean"
        case .terracotta: return "Terracotta"
        case .olive: return "Olive"
        case .indigo: return "Indigo"
        case .espresso: return "Espresso"
        }
    }

    var color: Color {
        switch self {
        case .ocean: return Color(red: 0.16, green: 0.39, blue: 0.40)
        case .terracotta: return Color(red: 0.65, green: 0.33, blue: 0.17)
        case .olive: return Color(red: 0.40, green: 0.42, blue: 0.22)
        case .indigo: return Color(red: 0.26, green: 0.31, blue: 0.51)
        case .espresso: return Color(red: 0.34, green: 0.26, blue: 0.20)
        }
    }
}

/// A warm, paper-like surface. Beige rather than white so the tinted section
/// bands and the white task rows can separate from the ground without a single
/// hard line.
enum Palette {
    static let washTop = Color(red: 0.973, green: 0.969, blue: 0.953)
    static let washBottom = washTop
    static let card = Color(red: 0.998, green: 0.996, blue: 0.986)
    static let band = Color(red: 0.941, green: 0.943, blue: 0.925)
    static let ink = Color(red: 0.16, green: 0.21, blue: 0.22)
    static let secondary = Color(red: 0.39, green: 0.44, blue: 0.44)
    static let tertiary = Color(red: 0.49, green: 0.53, blue: 0.52)
    static let hairline = Color(red: 0.87, green: 0.89, blue: 0.87)
    static let chipRest = Color(red: 0.92, green: 0.94, blue: 0.91)
    static let control = band
    static var wash: LinearGradient {
        LinearGradient(colors: [washTop, washBottom], startPoint: .top, endPoint: .bottom)
    }
}

enum Metrics {
    static let gutter: CGFloat = 16
    static let rowHeight: CGFloat = 76
    static let circle: CGFloat = 21
    static let radius: CGFloat = 14
    static let chipRadius: CGFloat = 15
    /// Apple's comfortable minimum for anything tappable.
    static let target: CGFloat = 44
}

extension Font {
    static let taskTitle = Font.system(size: 15, weight: .regular)
    static let taskMeta = Font.system(size: 12.5, weight: .regular)
    static let sectionHeader = Font.system(size: 14, weight: .medium)
    static let fieldLabel = Font.system(size: 13, weight: .regular)
    static let captureField = Font.system(size: 16, weight: .regular)
    static let chip = Font.system(size: 13.5, weight: .regular)
    static let rowLabel = Font.system(size: 14, weight: .regular)
}

// MARK: - Shared controls

/// A due-time or weekday pill. Filled with the accent when chosen, tinted paper
/// when not — the same two states the app this copies uses.
struct Chip: View {
    let label: String
    var systemImage: String?
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
                }
            }
            .font(.chip)
            .foregroundStyle(isSelected ? Color.white : accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Metrics.chipRadius, style: .continuous)
                    .fill(isSelected ? accent : Palette.chipRest)
            )
        }
        .buttonStyle(.plain)
    }
}

/// A white rounded panel. Form content sits on these, floating on the wash.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .background(
                RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                    .fill(Palette.card)
            )
    }
}

/// A hairline that starts where the text starts, never under the control to
/// its left.
struct InsetDivider: View {
    var leading: CGFloat = Metrics.gutter

    var body: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(height: 1)
            .padding(.leading, leading)
    }
}

/// A round toolbar button on the wash.
struct WashButton: View {
    let systemImage: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.ink)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Palette.card.opacity(0.75)))
        }
        .buttonStyle(.plain)
    }
}
