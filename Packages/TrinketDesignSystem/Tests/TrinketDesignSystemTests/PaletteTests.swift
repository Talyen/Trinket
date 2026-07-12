import SwiftUI
import Testing
import TrinketCore
@testable import TrinketDesignSystem

struct PaletteTests {
    @Test func bundledEncounterAndKeywordColorsResolve() throws {
        try #expect(TrinketDesign.Colors.encounterBattle != .clear)
        try #expect(Keyword.gold.visualStyle.color != .clear)
    }

    @Test func applePaletteHasValidColors() throws {
        let palette = ThemePalette.apple
        try #expect(palette.appBackground != .clear)
        try #expect(palette.secondaryBackground != .clear)
        try #expect(palette.elevatedBackground != .clear)
        try #expect(palette.panelSurface != .clear)
        try #expect(palette.subtleStroke != .clear)
        try #expect(palette.accent != .clear)
    }
}
