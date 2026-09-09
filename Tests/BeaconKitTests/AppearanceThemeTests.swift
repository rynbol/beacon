import XCTest
@testable import BeaconKit

final class AppearanceThemeTests: XCTestCase {
    func testEveryThemeKeepsTextReadableAcrossSurfaces() {
        for theme in AppearanceTheme.allCases {
            let palette = theme.palette
            for background in [palette.canvas, palette.surface, palette.sidebar] {
                XCTAssertGreaterThanOrEqual(contrast(palette.text, background), 7, "\(theme) primary text")
                XCTAssertGreaterThanOrEqual(contrast(palette.secondary, background), 4.5, "\(theme) secondary text")
            }
        }
    }
    func testThemeChoicesHaveDistinctBackgroundsAndStableStorageKeys() {
        XCTAssertEqual(Set(AppearanceTheme.allCases.map(\.palette.canvas)).count, 4)
        for theme in AppearanceTheme.allCases {
            XCTAssertEqual(AppearanceTheme(rawValue: theme.rawValue), theme)
        }
        XCTAssertNil(AppearanceTheme(rawValue: "unknown"))
        XCTAssertEqual(AppearanceTheme.beige.title, "Beige")
    }
    private func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let x = luminance(a), y = luminance(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
    private func luminance(_ rgb: UInt32) -> Double {
        let channels = [16, 8, 0].map { shift -> Double in
            let c = Double((rgb >> shift) & 255) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
    }
}
