import TrinketDesignSystem
import XCTest

final class AppThemeTests: XCTestCase {
    func testStandardThemeUsesApplePalette() {
        let palette = TrinketDesign.AppTheme.default.palette
        XCTAssertNotEqual(palette.appBackground, .clear)
        XCTAssertNotEqual(palette.panelSurface, .clear)
        XCTAssertNotEqual(palette.subtleStroke, .clear)
        XCTAssertNotEqual(palette.accent, .clear)
    }

    func testApplePaletteHasValidColors() {
        let palette = ThemePalette.apple
        XCTAssertNotEqual(palette.appBackground, .clear)
        XCTAssertNotEqual(palette.secondaryBackground, .clear)
        XCTAssertNotEqual(palette.elevatedBackground, .clear)
        XCTAssertNotEqual(palette.panelSurface, .clear)
        XCTAssertNotEqual(palette.subtleStroke, .clear)
        XCTAssertNotEqual(palette.accent, .clear)
    }

    func testAppearanceParsingSupportsDisplayNames() {
        XCTAssertEqual(TrinketDesign.AppAppearance(rawValue: "system"), .system)
        XCTAssertEqual(TrinketDesign.AppAppearance(rawValue: "Light"), .light)
        XCTAssertEqual(TrinketDesign.AppAppearance(rawValue: "dark"), .dark)
        XCTAssertNil(TrinketDesign.AppAppearance(rawValue: "unknown"))
    }
}
