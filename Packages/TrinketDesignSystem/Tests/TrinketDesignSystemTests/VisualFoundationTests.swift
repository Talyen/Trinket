import SwiftUI
import TrinketDesignSystem
import XCTest
final class VisualFoundationTests: XCTestCase {
    func testBackgroundModeDisplayNamesAreNonEmpty() {
        for mode in BackgroundMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty)
            XCTAssertEqual(mode.id, mode)
        }
    }

    func testThemePaletteAppleUsesSemanticColors() {
        let palette = ThemePalette.apple
        XCTAssertNotEqual(palette.appBackground, .clear)
        XCTAssertNotEqual(palette.secondaryBackground, .clear)
        XCTAssertNotEqual(palette.elevatedBackground, .clear)
        XCTAssertNotEqual(palette.panelSurface, .clear)
        XCTAssertNotEqual(palette.subtleStroke, .clear)
        XCTAssertNotEqual(palette.accent, .clear)
    }

    func testShadowStylesHaveExpectedRadii() {
        XCTAssertEqual(ShadowStyle.none.radius, 0)
        XCTAssertGreaterThan(ShadowStyle.subtle.radius, 0)
        XCTAssertGreaterThan(ShadowStyle.elevated.radius, ShadowStyle.subtle.radius)
    }

    func testTypographyRolesProvideFonts() {
        XCTAssertNotEqual(TypographyRole.screenTitle.font, TypographyRole.caption.font)
        XCTAssertNotEqual(TypographyRole.button.font, TypographyRole.body.font)
        XCTAssertNotEqual(TypographyRole.statValue.font, TypographyRole.tooltip.font)
    }
}
