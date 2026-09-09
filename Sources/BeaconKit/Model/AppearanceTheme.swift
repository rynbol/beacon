import Foundation

public struct ThemePalette: Sendable {
    public let canvas, surface, sidebar, text, secondary, border: UInt32
}

public enum AppearanceTheme: String, CaseIterable, Sendable {
    case paper, mist, beige, dark
    public var title: String { rawValue.capitalized }
    public var palette: ThemePalette {
        switch self {
        case .paper: ThemePalette(canvas: 0xF8F7F3, surface: 0xFEFDFC, sidebar: 0xEFF0EC, text: 0x293638, secondary: 0x626D6C, border: 0xDADFDA)
        case .mist: ThemePalette(canvas: 0xF1F4F6, surface: 0xFBFCFD, sidebar: 0xE6EBEF, text: 0x26333E, secondary: 0x596773, border: 0xD2DBE2)
        case .beige: ThemePalette(canvas: 0xF0E6D6, surface: 0xFAF4E9, sidebar: 0xE5D8C3, text: 0x3F352B, secondary: 0x6C5C4B, border: 0xD4C4AD)
        case .dark: ThemePalette(canvas: 0x202625, surface: 0x2A3230, sidebar: 0x1A201F, text: 0xEDF1EB, secondary: 0xABB8B1, border: 0x44504A)
        }
    }
}
