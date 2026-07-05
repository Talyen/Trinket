import TrinketDesignSystem
import XCTest

final class AppThemeTests: XCTestCase {
    func testThemePresetsExposePalettes() {
        XCTAssertEqual(TrinketDesign.AppTheme.allCases.count, 5)

        for theme in TrinketDesign.AppTheme.allCases {
            let palette = theme.palette
            XCTAssertNotEqual(palette.appBackground, .clear, "\(theme.rawValue) should have an app background")
            XCTAssertNotEqual(palette.panelSurface, .clear, "\(theme.rawValue) should have a panel surface")
            XCTAssertNotEqual(palette.subtleStroke, .clear, "\(theme.rawValue) should have a subtle stroke")
            XCTAssertNotEqual(palette.accent, .clear, "\(theme.rawValue) should have an accent")
        }
    }

    func testThemeParsingSupportsLegacyValues() {
        XCTAssertEqual(TrinketDesign.AppTheme(rawValue: "Dark"), .darkTabletop)
        XCTAssertEqual(TrinketDesign.AppTheme(rawValue: "Light"), .warmParchment)
        XCTAssertEqual(TrinketDesign.AppTheme(rawValue: "System"), .systemNative)
    }

    func testThemeParsingSupportsLaunchArgumentNames() {
        XCTAssertEqual(TrinketDesign.AppTheme(rawValue: "dark-tabletop"), .darkTabletop)
        XCTAssertEqual(TrinketDesign.AppTheme(rawValue: "warm_parchment"), .warmParchment)
        XCTAssertEqual(TrinketDesign.AppTheme(rawValue: "Arcane Night"), .arcaneNight)
        XCTAssertEqual(TrinketDesign.AppTheme(rawValue: "forest"), .forestAlchemy)
        XCTAssertEqual(TrinketDesign.AppTheme(rawValue: "System Native"), .systemNative)
    }
}
