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
    }

    @Test func publicSemanticPaletteHasValidColors() throws {
        let palette = ThemePalette.trinket
        try #expect(palette.appBackground != .clear)
        try #expect(palette.secondaryBackground != .clear)
        try #expect(palette.elevatedBackground != .clear)
        try #expect(palette.panelSurface != .clear)
        try #expect(palette.subtleStroke != .clear)
        try #expect(palette.accent != .clear)
        try #expect(TrinketDesign.Colors.canvas == palette.appBackground)
        try #expect(TrinketDesign.Colors.panel == palette.panelSurface)
        try #expect(TrinketDesign.Colors.accent == palette.accent)
        try #expect(TrinketDesign.Colors.progression == palette.accentEmphasized)
    }
}
