import SwiftUI
import Observation
import BeaconKit

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
    static let rowHeight: CGFloat = 72
    static let circle: CGFloat = 21
    static let radius: CGFloat = 10
    static let chipRadius: CGFloat = 7
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


/// Beacon's small navigation vocabulary. Drawn on one 24-point grid with
/// rounded joins; system symbols remain for standard macOS actions.
struct BeaconGlyph: View {
    enum Kind { case beacon, inbox, today, calendar, upcoming, someday, completed }
    let kind: Kind

    var body: some View {
        GeometryReader { geometry in
            drawing
                .stroke(style: StrokeStyle(lineWidth: 1.65, lineCap: .round, lineJoin: .round))
                .scaleEffect(x: geometry.size.width / 24, y: geometry.size.height / 24, anchor: .topLeading)
        }.accessibilityHidden(true)
    }

    private var drawing: Path {
        Path { p in
            func line(_ points: [(CGFloat, CGFloat)]) {
                guard let first = points.first else { return }
                p.move(to: CGPoint(x: first.0, y: first.1))
                for point in points.dropFirst() { p.addLine(to: CGPoint(x: point.0, y: point.1)) }
            }
            switch kind {
            case .beacon:
                line([(8,21),(10,10),(14,10),(16,21)])
                line([(6,21),(18,21)])
                p.addRoundedRect(in: CGRect(x:9,y:5,width:6,height:5), cornerSize: CGSize(width:1,height:1))
                line([(12,2),(12,3)])
                line([(3,5),(6,7)]); line([(18,7),(21,5)])
                line([(3,11),(6,10)]); line([(18,10),(21,11)])
                line([(10,16),(14,16)])
            case .inbox:
                line([(3,13),(6,5),(18,5),(21,13),(21,20),(3,20),(3,13),(8,13),(9,16),(15,16),(16,13),(21,13)])
                line([(9,8),(15,8)])
            case .today:
                p.addEllipse(in: CGRect(x:7,y:7,width:10,height:10))
                for i in 0..<8 {
                    let angle = Double(i) * .pi / 4
                    line([(12+CGFloat(cos(angle))*8,12+CGFloat(sin(angle))*8),
                          (12+CGFloat(cos(angle))*10,12+CGFloat(sin(angle))*10)])
                }
            case .calendar:
                p.addRoundedRect(in: CGRect(x:4,y:5,width:16,height:16), cornerSize: CGSize(width:2,height:2))
                line([(4,10),(20,10)]); line([(8,3),(8,7)]); line([(16,3),(16,7)])
                p.addRoundedRect(in: CGRect(x:8,y:14,width:3,height:3), cornerSize: CGSize(width:0.5,height:0.5))
            case .upcoming:
                line([(3,7),(14,7)]); line([(3,12),(20,12),(16,8)])
                line([(20,12),(16,16)]); line([(3,17),(10,17)])
            case .someday:
                line([(4,19),(20,19)])
                p.move(to: CGPoint(x:6,y:14))
                p.addCurve(to: CGPoint(x:18,y:14), control1: CGPoint(x:6,y:5), control2: CGPoint(x:18,y:5))
                line([(12,3),(12,5)]); line([(3,8),(5,9)]); line([(19,9),(21,8)])
            case .completed:
                p.addRoundedRect(in: CGRect(x:4,y:4,width:16,height:16), cornerSize: CGSize(width:4,height:4))
                line([(8,12),(11,15),(16,9)])
            }
        }
    }
}


@MainActor @Observable
final class UrgencyColors {
    static let shared = UrgencyColors()
    private let defaults: UserDefaults
    private var overrides: [String: [Double]]

    private init() {
        let preview = ProcessInfo.processInfo.arguments.contains("--preview") || Bundle.main.bundleIdentifier == "dev.dylan.beacon.v2.preview"
        defaults = preview ? UserDefaults(suiteName: "dev.dylan.beacon.v2.design-preview")! : .standard
        overrides = defaults.dictionary(forKey: "urgencyColors") as? [String: [Double]] ?? [:]
    }
    func color(for urgency: Urgency) -> Color {
        if let rgb = overrides[urgency.rawValue], rgb.count == 3,
           rgb.allSatisfy({ $0.isFinite && (0...1).contains($0) }) {
            return Color(red: rgb[0], green: rgb[1], blue: rgb[2])
        }
        switch urgency {
        case .none: return Palette.secondary
        case .low: return Color(red: 0.35, green: 0.49, blue: 0.62)
        case .medium: return Color(red: 0.67, green: 0.47, blue: 0.18)
        case .high: return Color(red: 0.72, green: 0.35, blue: 0.32)
        }
    }
    func set(_ color: Color, for urgency: Urgency) {
        guard urgency != .none, let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
        overrides[urgency.rawValue] = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
        defaults.set(overrides, forKey: "urgencyColors")
    }
    func reset() {
        overrides = [:]
        defaults.removeObject(forKey: "urgencyColors")
    }
}

struct UrgencyColorSettings: View {
    private var colors: UrgencyColors { .shared }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Urgency colors").font(.fieldLabel).foregroundStyle(Palette.secondary)
            ForEach([Urgency.low, .medium, .high], id: \.self) { urgency in
                ColorPicker(selection: Binding(get: { colors.color(for: urgency) }, set: { colors.set($0, for: urgency) }), supportsOpacity: false) {
                    Label(urgency.title, systemImage: "flag").foregroundStyle(colors.color(for: urgency))
                }.font(.taskMeta)
            }
            Button("Reset colors") { colors.reset() }.buttonStyle(.plain)
                .font(.system(size: 11)).foregroundStyle(Palette.secondary)
        }
    }
}
