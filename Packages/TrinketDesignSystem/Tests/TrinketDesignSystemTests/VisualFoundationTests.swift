import SwiftUI
import TrinketDesignSystem
import Testing
@Suite
struct VisualFoundationTests {
    @Test func backgroundModeDisplayNamesAreNonEmpty() {
        for mode in BackgroundMode.allCases {
            #expect(!(mode.displayName.isEmpty))
            #expect(mode.id == mode)
        }
    }

    @Test func themePaletteAppleUsesSemanticColors() {
        let palette = ThemePalette.apple
        #expect(palette.appBackground != .clear)
        #expect(palette.secondaryBackground != .clear)
        #expect(palette.elevatedBackground != .clear)
        #expect(palette.panelSurface != .clear)
        #expect(palette.subtleStroke != .clear)
        #expect(palette.accent != .clear)
    }

    @Test func shadowStylesHaveExpectedRadii() {
        #expect(ShadowStyle.none.radius == 0)
        #expect(ShadowStyle.subtle.radius > 0)
        #expect(ShadowStyle.elevated.radius > ShadowStyle.subtle.radius)
    }

    @Test func typographyRolesProvideFonts() {
        #expect(TypographyRole.screenTitle.font != TypographyRole.caption.font)
        #expect(TypographyRole.button.font != TypographyRole.body.font)
        #expect(TypographyRole.statValue.font != TypographyRole.tooltip.font)
    }
}
