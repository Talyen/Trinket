import SwiftUI
import Testing
import TrinketDesignSystem

struct ThemePaletteTests {
    @Test func themePaletteAppleUsesSemanticColors() throws {
        let palette = ThemePalette.apple
        try #expect(palette.appBackground != .clear)
        try #expect(palette.secondaryBackground != .clear)
        try #expect(palette.elevatedBackground != .clear)
        try #expect(palette.panelSurface != .clear)
        try #expect(palette.subtleStroke != .clear)
        try #expect(palette.accent != .clear)
    }

    @Test func shadowStylesHaveExpectedRadii() throws {
        try #expect(ShadowStyle.none.radius == 0)
        try #expect(ShadowStyle.subtle.radius > 0)
        try #expect(ShadowStyle.elevated.radius > ShadowStyle.subtle.radius)
    }
}
