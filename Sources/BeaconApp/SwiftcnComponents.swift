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
                            RoundedRectangle(cornerRadius: 1)
                                .fill(selection == option.value ? Palette.ink : .clear).frame(height: 2)
                        }.contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityAddTraits(selection == option.value ? .isSelected : [])
            }
        }.overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairline).frame(height: 0.5).allowsHitTesting(false)
        }
    }
}
