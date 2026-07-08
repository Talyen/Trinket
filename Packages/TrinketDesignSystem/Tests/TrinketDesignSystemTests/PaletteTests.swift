import TrinketCore
import TrinketDesignSystem
import Testing

@Suite
struct PaletteTests {
    @Test func bundledEncounterAndKeywordColorsResolve() {
        #expect(TrinketDesign.Colors.encounterBattle != .clear)
        #expect(Keyword.gold.visualStyle.color != .clear)
    }

    @Test func applePaletteHasValidColors() {
        let palette = ThemePalette.apple
        #expect(palette.appBackground != .clear)
        #expect(palette.secondaryBackground != .clear)
        #expect(palette.elevatedBackground != .clear)
        #expect(palette.panelSurface != .clear)
        #expect(palette.subtleStroke != .clear)
        #expect(palette.accent != .clear)
    }

    @Test func appearanceParsingSupportsDisplayNames() {
        #expect(TrinketDesign.AppAppearance(rawValue: "system") == .system)
        #expect(TrinketDesign.AppAppearance(rawValue: "Light") == .light)
        #expect(TrinketDesign.AppAppearance(rawValue: "dark") == .dark)
        #expect(TrinketDesign.AppAppearance(rawValue: "unknown") == nil)
    }
}
