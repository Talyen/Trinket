import TrinketCore
import TrinketDesignSystem
import Testing

@Suite
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

    @Test func appearanceParsingSupportsDisplayNames() throws {
        try #expect(TrinketDesign.AppAppearance(rawValue: "system") == .system)
        try #expect(TrinketDesign.AppAppearance(rawValue: "Light") == .light)
        try #expect(TrinketDesign.AppAppearance(rawValue: "dark") == .dark)
        try #expect(TrinketDesign.AppAppearance(rawValue: "unknown") == nil)
    }
}
