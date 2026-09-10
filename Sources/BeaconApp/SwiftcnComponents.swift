// Adapted from Mobilecn-UI/swiftcn-ui (MIT), revision 515a26e0861f28fdaa1808e22789573d46f8c60e.
// See Resources/Licenses/Swiftcn.txt and docs/UI-LIBRARIES.md.
// Mac adaptations: native Button semantics, disabled states, generic content,
// content-sized underlines, and Beacon's existing colors and compact metrics.
import SwiftUI

struct SwiftcnButtonStyle: ButtonStyle {
    enum Variant { case primary, outline, quiet }
    var variant: Variant = .outline
    var accent: Color = Palette.ink
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12).frame(minHeight: 32)
            .foregroundStyle(variant == .primary ? Palette.onAccent : accent)
            .background(variant == .primary ? accent : variant == .outline ? Palette.card : .clear,
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(variant == .outline ? Palette.hairline : .clear, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .opacity(!enabled ? 0.4 : configuration.isPressed ? 0.7 : 1)
    }
}

struct SwiftcnCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.hairline.opacity(0.7), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

struct SwiftcnInputSurface: ViewModifier {
    var focused = false
    func body(content: Content) -> some View {
        content.background(Palette.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(focused ? Palette.secondary : Palette.hairline, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

struct SwiftcnTabs<Value: Hashable>: View {
    @Namespace private var tabUnderline
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selection: Value
    let options: [(value: Value, title: String)]
    var body: some View {
        HStack(spacing: 22) {
            ForEach(options, id: \.value) { option in
                Button { selection = option.value } label: {
                    Text(option.title)
                        .font(.system(size: 13, weight: selection == option.value ? .semibold : .regular))
                        .foregroundStyle(selection == option.value ? Palette.ink : Palette.secondary)
                        .frame(height: 36)
                        .overlay(alignment: .bottom) {
                            if selection == option.value {
                                RoundedRectangle(cornerRadius: 1).fill(Palette.ink).frame(height: 2)
                                    .matchedGeometryEffect(id: "selection", in: tabUnderline)
                                    .allowsHitTesting(false)
                            }
                        }.contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityAddTraits(selection == option.value ? .isSelected : [])
            }
        }.overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairline).frame(height: 0.5).allowsHitTesting(false)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: selection)
    }
}

// Beacon's selection control, composed with the same surfaces as the adapted kit.
// A native popover handles presentation and outside-click dismissal; selecting a
// row is the only operation that changes the bound value.
struct BeaconChoice<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var symbol: String? = nil
    var color: Color? = nil
    var id: Value { value }
}

extension EnvironmentValues {
    @Entry var beaconChoicePresentation: Binding<Set<UUID>> = .constant([])
}

struct BeaconChoicePicker<Value: Hashable>: View {
    let label: String
    @Binding var selection: Value
    let options: [BeaconChoice<Value>]
    var placeholder = "Choose"
    @State private var presentationID = UUID()
    @State private var showing = false
    @State private var releaseTask: Task<Void, Never>?
    @Environment(\.beaconChoicePresentation) private var parentPresentation

    private var selected: BeaconChoice<Value>? { options.first { $0.value == selection } }

    var body: some View {
        Button {
            releaseTask?.cancel()
            showing.toggle()
            if showing { parentPresentation.wrappedValue.insert(presentationID) }
        } label: {
            HStack(spacing: 7) {
                if let symbol = selected?.symbol {
                    Image(systemName: symbol).foregroundStyle(selected?.color ?? Palette.secondary)
                }
                Text(selected?.title ?? placeholder).lineLimit(1).truncationMode(.middle)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.secondary)
            }
        }
        .buttonStyle(SwiftcnButtonStyle(variant: .quiet))
        .background(showing ? Palette.control : .clear, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(label)
        .accessibilityValue(selected?.title ?? placeholder)
        .disabled(options.isEmpty)
        .onChange(of: showing) { _, value in
            releaseTask?.cancel()
            if value {
                parentPresentation.wrappedValue.insert(presentationID)
            } else {
                // Keep parent shortcuts inactive through the native popover's
                // closing transition; its final key event can reach the window.
                releaseTask = Task { @MainActor in
                    do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                    guard !showing else { return }
                    parentPresentation.wrappedValue.remove(presentationID)
                }
            }
        }
        .onDisappear {
            releaseTask?.cancel()
            if showing || releaseTask != nil { parentPresentation.wrappedValue.remove(presentationID) }
        }
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            BeaconChoicePanel(label: label, selection: selection, options: options) { value in
                selection = value
                showing = false
            } dismiss: { showing = false }
            .presentationBackground(Palette.card)
        }
    }
}

private struct BeaconChoicePanel<Value: Hashable>: View {
    let label: String
    let selection: Value
    let options: [BeaconChoice<Value>]
    let choose: (Value) -> Void
    let dismiss: () -> Void
    @FocusState private var focused: Int?
    @State private var hovered: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.secondary)
                .padding(.horizontal, 10).padding(.top, 6)
            ScrollViewReader { proxy in
                BeaconScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                            Button { choose(option.value) } label: {
                                HStack(spacing: 9) {
                                    if let symbol = option.symbol {
                                        Image(systemName: symbol).frame(width: 16)
                                            .foregroundStyle(option.color ?? Palette.secondary)
                                    }
                                    Text(option.title).lineLimit(2).multilineTextAlignment(.leading)
                                    Spacer(minLength: 12)
                                    Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                                        .opacity(selection == option.value ? 1 : 0)
                                }
                                .font(.system(size: 13)).foregroundStyle(Palette.ink)
                                .padding(.horizontal, 10).frame(minHeight: 34)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(focused == index || hovered == index ? Palette.control : .clear,
                                            in: RoundedRectangle(cornerRadius: 6))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).focusable().focused($focused, equals: index).focusEffectDisabled()
                            .onHover { hovered = $0 ? index : nil }
                            .accessibilityAddTraits(selection == option.value ? .isSelected : [])
                            .id(index)
                        }
                    }
                }
                .frame(height: min(max(0, CGFloat(options.count) * 36 - 2), 286))
                .onAppear {
                    focused = options.firstIndex { $0.value == selection } ?? 0
                    if let focused { proxy.scrollTo(focused, anchor: .center) }
                }
                .onChange(of: focused) { _, value in
                    if let value { proxy.scrollTo(value) }
                }
            }
        }
        .padding(8).frame(width: 238)
        .onMoveCommand { direction in
            guard !options.isEmpty else { return }
            if direction == .down { focused = min((focused ?? -1) + 1, options.count - 1) }
            if direction == .up { focused = max((focused ?? 1) - 1, 0) }
        }
        .onKeyPress(.return) {
            guard let focused, options.indices.contains(focused) else { return .ignored }
            choose(options[focused].value)
            return .handled
        }
        .onExitCommand(perform: dismiss)
    }
}

struct BeaconStepper: View {
    let label: String
    var canDecrease = true
    var canIncrease = true
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            step("minus", name: "Decrease", enabled: canDecrease, action: decrease)
            Rectangle().fill(Palette.hairline).frame(width: 1, height: 14)
            step("plus", name: "Increase", enabled: canIncrease, action: increase)
        }
        .background(Palette.control, in: RoundedRectangle(cornerRadius: 7))
        .fixedSize()
    }

    private func step(_ symbol: String, name: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.ink).frame(width: 30, height: 28)
                .contentShape(Rectangle()).opacity(enabled ? 1 : 0.35)
        }.buttonStyle(.plain).disabled(!enabled).accessibilityLabel("\(name) \(label)")
    }
}
