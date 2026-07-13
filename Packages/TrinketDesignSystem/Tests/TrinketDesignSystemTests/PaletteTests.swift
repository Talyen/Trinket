import SwiftUI
import Testing
import TrinketCore
@testable import TrinketDesignSystem

struct PaletteTests {
    @Test func bundledEncounterAndKeywordColorsResolve() throws {
        try #expect(TrinketDesign.Colors.encounterBattle != .clear)
        try #expect(Keyword.gold.visualStyle.color != .clear)
        try #expect(Keyword.physical.visualStyle.color != .clear)
        try #expect(Keyword.health.visualStyle.color != .clear)
    }

    @Test func healthAndOverlayTokensResolveFromPalette() throws {
        let palette = ThemePalette.trinket
        try #expect(TrinketDesign.Colors.health == palette.health)
        try #expect(TrinketDesign.Colors.healthRestore == palette.healthRestore)
        try #expect(TrinketDesign.Colors.battleHealthTrack != .clear)
        try #expect(TrinketDesign.Colors.Overlay.ink == palette.overlayInk)
        try #expect(TrinketDesign.Colors.Overlay.paper == palette.overlayPaper)
        try #expect(TrinketDesign.Colors.chapterVerdant != .clear)
    }

    @Test func homesteadResourceAndTintColorsResolve() throws {
        for resource in HomesteadResource.allCases {
            try #expect(resource.tint != .clear, "\(resource.rawValue) tint")
        }
        for tint in HomesteadTint.allCases {
            try #expect(tint.color != .clear, "\(tint.rawValue) color")
        }
        try #expect(HomesteadPalette.background == ThemePalette.trinket.appBackground)
        try #expect(HomesteadPalette.panel == ThemePalette.trinket.panelSurface)
        try #expect(HomesteadPalette.accent == ThemePalette.trinket.accent)
    }
}
