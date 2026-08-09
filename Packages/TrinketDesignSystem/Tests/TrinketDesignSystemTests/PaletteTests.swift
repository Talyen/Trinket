import SwiftUI
import Testing
import TrinketCore
@testable import TrinketDesignSystem

struct PaletteTests {
    @Test func bundledEncounterAndKeywordColorsResolve() throws {
        try #expect(TrinketDesign.Colors.encounterBattle != .clear)
        try #expect(TrinketDesign.Colors.battleHealthTrack != .clear)
        try #expect(TrinketDesign.Colors.chapterForest != .clear)
        try #expect(TrinketDesign.Colors.chapterDungeon != .clear)
        try #expect(TrinketDesign.Colors.chapterDesert != .clear)
        try #expect(TrinketDesign.Colors.chapterTundra != .clear)
        try #expect(Keyword.gold.visualStyle.color != .clear)
        try #expect(Keyword.physical.visualStyle.color != .clear)
        try #expect(Keyword.health.visualStyle.color != .clear)
    }

    @Test func homesteadResourceColorsResolve() throws {
        for resource in HomesteadResource.allCases {
            try #expect(resource.tint != .clear, "\(resource.rawValue) tint")
        }
        try #expect(HomesteadPalette.background == ThemePalette.trinket.appBackground)
        try #expect(HomesteadPalette.panel == ThemePalette.trinket.panelSurface)
        try #expect(HomesteadPalette.accent == ThemePalette.trinket.accent)
    }
}
