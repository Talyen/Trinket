import SwiftUI
import Testing
@testable import TrinketDesignSystem

struct VisualFoundationTests {
    @Test func backgroundModeDisplayNamesAreNonEmpty() throws {
        for mode in BackgroundMode.allCases {
            try #expect(!(mode.displayName.isEmpty))
            try #expect(mode.id == mode)
        }
    }

    @Test func typographyRolesProvideFonts() throws {
        try #expect(TypographyRole.button.font != TypographyRole.body.font)
        try #expect(TypographyRole.statValue.font != TypographyRole.tooltip.font)
        try #expect(TypographyRole.eyebrow.font != TypographyRole.caption.font)
        try #expect(TypographyRole.screenDisplay.font != TypographyRole.screenTitle.font)
        try #expect(TypographyRole.sectionDisplay.font != TypographyRole.sectionTitle.font)
        try #expect(TypographyRole.cardLabel.font != TypographyRole.secondaryBody.font)
        try #expect(TypographyRole.footnote.font != TypographyRole.caption.font)
    }

    @Test func homesteadPaletteUsesDarkChrome() throws {
        try #expect(HomesteadPalette.background != .clear)
        try #expect(HomesteadPalette.panel != .clear)
        try #expect(HomesteadPalette.stroke != .clear)
        try #expect(HomesteadPalette.accent != .clear)
        try #expect(HomesteadPalette.walletPanel != .clear)
        try #expect(HomesteadPalette.background == ThemePalette.trinket.appBackground)
        try #expect(HomesteadPalette.panel == ThemePalette.trinket.panelSurface)
        try #expect(HomesteadPalette.accent == ThemePalette.trinket.accent)
    }
}
