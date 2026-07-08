import SwiftUI
import TrinketDesignSystem
import Testing

@Suite
struct ThemePaletteTests {
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
}
