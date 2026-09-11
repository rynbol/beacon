import SwiftUI
import SwiftUIIntrospect
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

    @MainActor var color: Color {
        if AppearanceStore.shared.theme == .dark {
            switch self {
            case .ocean: return Color(hex: 0x8ABFBA)
            case .terracotta: return Color(hex: 0xDFA889)
            case .olive: return Color(hex: 0xB7C68B)
            case .indigo: return Color(hex: 0xADB9E1)
            case .espresso: return Color(hex: 0xC8B3A0)
            }
        }
        switch self {
        case .ocean: return Color(red: 0.16, green: 0.39, blue: 0.40)
        case .terracotta: return Color(red: 0.65, green: 0.33, blue: 0.17)
        case .olive: return Color(red: 0.40, green: 0.42, blue: 0.22)
        case .indigo: return Color(red: 0.26, green: 0.31, blue: 0.51)
        case .espresso: return Color(red: 0.34, green: 0.26, blue: 0.20)
        }
    }
}

@MainActor @Observable
final class AppearanceStore {
    static let shared = AppearanceStore()
    private let defaults: UserDefaults
    var theme: AppearanceTheme {
        didSet { defaults.set(theme.rawValue, forKey: "appearanceTheme") }
    }
    private init() {
        let preview = ProcessInfo.processInfo.arguments.contains("--preview") || Bundle.main.bundleIdentifier == "dev.dylan.beacon.v2.preview"
        defaults = preview ? UserDefaults(suiteName: "dev.dylan.beacon.v2.design-preview")! : .standard
        theme = AppearanceTheme(rawValue: defaults.string(forKey: "appearanceTheme") ?? "") ?? .paper
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

@MainActor enum Palette {
    private static var colors: ThemePalette { AppearanceStore.shared.theme.palette }
    static var washTop: Color { Color(hex: colors.canvas) }
    static var washBottom: Color { washTop }
    static var card: Color { Color(hex: colors.surface) }
    static var band: Color { Color(hex: colors.sidebar) }
    static var ink: Color { Color(hex: colors.text) }
    static var secondary: Color { Color(hex: colors.secondary) }
    static var tertiary: Color { secondary }
    static var hairline: Color { Color(hex: colors.border) }
    static var chipRest: Color { band }
    static var control: Color { band }
    static var onAccent: Color { AppearanceStore.shared.theme == .dark ? Color(hex: 0x202625) : .white }
    static var wash: LinearGradient {
        LinearGradient(colors: [washTop, washBottom], startPoint: .top, endPoint: .bottom)
    }
}

enum Metrics {
    static let gutter: CGFloat = 16
    static let formIcon: CGFloat = 20
    static let formSpacing: CGFloat = 10
    static let formTextInset: CGFloat = gutter + formIcon + formSpacing
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
        }
        .buttonStyle(SwiftcnButtonStyle(variant: isSelected ? .primary : .outline, accent: accent))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A white rounded panel. Form content sits on these, floating on the wash.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        SwiftcnCard { content }
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
        if AppearanceStore.shared.theme == .dark {
            switch urgency {
            case .none: return Palette.secondary
            case .low: return Color(hex: 0x95B9D8)
            case .medium: return Color(hex: 0xDFC078)
            case .high: return Color(hex: 0xE59C91)
            }
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Urgency").font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Reset") { colors.reset() }.buttonStyle(.plain)
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    .accessibilityLabel("Reset urgency colors")
            }
            ForEach([Urgency.low, .medium, .high], id: \.self) { urgency in
                HStack {
                    Image(systemName: "flag").foregroundStyle(colors.color(for: urgency)).frame(width: 18)
                    Text(urgency.title).foregroundStyle(Palette.secondary)
                    Spacer()
                    ColorPicker(urgency.title, selection: Binding(get: { colors.color(for: urgency) }, set: { colors.set($0, for: urgency) }), supportsOpacity: false)
                        .labelsHidden().frame(width: 46)
                        .accessibilityLabel("\(urgency.title) urgency color")
                        .introspect(.colorPicker, on: .macOS(.v26)) { $0.colorWellStyle = .minimal }
                }.font(.system(size: 12)).frame(height: 28)
            }
        }
    }
}

struct ThemePicker: View {
    private var appearance: AppearanceStore { .shared }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Background").font(.system(size: 13, weight: .semibold))
            HStack(spacing: 10) {
                ForEach(AppearanceTheme.allCases, id: \.self) { theme in
                    Button { appearance.theme = theme } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 0) {
                                Color(hex: theme.palette.sidebar).frame(width: 20)
                                VStack(alignment: .leading, spacing: 6) {
                                    Capsule().fill(Color(hex: theme.palette.text)).frame(width: 28, height: 3)
                                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: theme.palette.surface)).frame(height: 13)
                                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: theme.palette.surface)).frame(height: 13)
                                }.padding(8).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(hex: theme.palette.canvas))
                            }.frame(height: 64).clipShape(RoundedRectangle(cornerRadius: 7))
                                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(appearance.theme == theme ? Palette.ink : Palette.hairline, lineWidth: appearance.theme == theme ? 2 : 1))
                            HStack {
                                Text(theme.title)
                                Spacer(minLength: 0)
                                if appearance.theme == theme { Image(systemName: "checkmark").font(.system(size: 9, weight: .semibold)) }
                            }.font(.system(size: 11)).foregroundStyle(Palette.ink)
                        }.frame(maxWidth: .infinity).contentShape(Rectangle())
                    }.buttonStyle(.plain).frame(maxWidth: .infinity).accessibilityLabel("\(theme.title) theme")
                        .accessibilityAddTraits(appearance.theme == theme ? .isSelected : [])
                }
            }
        }
    }
}

/// Keep a stable content width when scrolling begins, with native scroll behavior.
struct BeaconScrollView<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView { content().frame(maxWidth: .infinity, alignment: .leading) }
            // SwiftUI otherwise reserves a legacy scrollbar gutter when content
            // begins to overflow, even after AppKit is set to overlay style.
            .scrollIndicators(.hidden)
            .introspect(.scrollView, on: .macOS(.v26)) { scrollView in
                scrollView.scrollerStyle = .overlay
                scrollView.autohidesScrollers = true
                scrollView.verticalScroller?.controlSize = .small
                scrollView.horizontalScroller?.controlSize = .small
            }
    }
}

/// Plain-text AppKit editing, with native undo and bounded multiline scrolling.
struct BeaconNotesEditor: View {
    @Binding var text: String
    var autofocus = false
    var editorFont: Font = .taskTitle
    var editorHeight: CGFloat = 108
    var placeholder = "Add a detail, a link, or a little context…"
    var onSubmit: (() -> Void)?
    @State private var submitKeys = NoteSubmitKeys()
    @FocusState private var focused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(editorFont)
            .foregroundStyle(Palette.ink)
            .scrollContentBackground(.hidden)
            .focused($focused)
            .introspect(.textEditor, on: .macOS(.v26)) { editor in
                submitKeys.install(on: editor, submit: onSubmit)
                editor.isRichText = false
                editor.allowsUndo = true
                editor.drawsBackground = false
                editor.textContainerInset = NSSize(width: 9, height: 11)
                if let scrollView = editor.enclosingScrollView {
                    scrollView.drawsBackground = false
                    scrollView.scrollerStyle = .overlay
                    scrollView.autohidesScrollers = true
                    scrollView.verticalScroller?.controlSize = .small
                }
            }
            .frame(height: editorHeight)
            .modifier(SwiftcnInputSurface(focused: focused))
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(editorFont).foregroundStyle(Palette.tertiary)
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .accessibilityLabel("Notes")
            .onDisappear { submitKeys.remove() }
            .task {
                guard autofocus else { return }
                await Task.yield()
                focused = true
            }
    }
}


/// Intercept Return only for the active personal-note text view. Other editors,
/// Shift-Return, and IME composition retain their native behavior.
@MainActor
private final class NoteSubmitKeys {
    private weak var editor: NSTextView?
    private var submit: (() -> Void)?
    private var monitor: Any?

    func install(on editor: NSTextView, submit: (() -> Void)?) {
        self.editor = editor
        self.submit = submit
        guard submit != nil else { remove(); return }
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let editor = self.editor,
                  editor.window?.firstResponder === editor,
                  event.keyCode == 36 || event.keyCode == 76,
                  event.modifierFlags.intersection([.shift, .control, .option, .command]).isEmpty,
                  !editor.hasMarkedText() else { return event }
            self.submit?()
            return nil
        }
    }

    func remove() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        editor = nil
        submit = nil
    }
}

/// A short entrance when navigation changes, without replacing the view's
/// identity or animating subsequent data refreshes and edits.
struct BeaconSectionMotion<Value: Equatable>: ViewModifier {
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.phaseAnimator([false, true], trigger: value) { view, entering in
            view
                .offset(x: !reduceMotion && entering ? 16 : 0)
                .opacity(!reduceMotion && entering ? 0 : 1)
        } animation: { entering in
            reduceMotion || entering ? nil : .easeOut(duration: 0.24)
        }
        .clipped()
    }
}


/// Observe clicks without consuming them, so buttons still perform their action.
struct BeaconClickAwayFocus: NSViewRepresentable {
    func makeNSView(context: Context) -> FocusObserverView { FocusObserverView() }
    func updateNSView(_ nsView: FocusObserverView, context: Context) {}
    static func dismantleNSView(_ nsView: FocusObserverView, coordinator: ()) { nsView.stop() }

    final class FocusObserverView: NSView {
        private var monitor: Any?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let window = self?.window, event.window === window,
                      let editor = window.firstResponder as? NSTextView, editor.isEditable,
                      let content = window.contentView else { return event }
                let point = content.convert(event.locationInWindow, from: nil)
                guard content.bounds.contains(point) else { return event }
                var target = content.hitTest(point)
                while let view = target {
                    if let text = view as? NSTextView, text.isEditable { return event }
                    if let field = view as? NSTextField, field.isEditable { return event }
                    // Padding and scrollbars still belong to the text editor.
                    if let scroll = view as? NSScrollView,
                       let text = scroll.documentView as? NSTextView, text.isEditable { return event }
                    target = view.superview
                }
                window.makeFirstResponder(nil)
                return event
            }
        }
        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
