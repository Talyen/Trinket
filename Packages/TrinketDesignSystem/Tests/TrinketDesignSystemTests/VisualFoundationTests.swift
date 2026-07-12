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

    @Test func materialRoleStylesMatchLiquidGlassPlan() throws {
        let palette = ThemePalette.apple

        if case .none = MaterialRoleStyle(role: .toolbar) {} else {
            Issue.record("toolbar should pass through without custom chrome")
        }

        if case let .glass(_, solidFill) = MaterialRoleStyle(role: .bottomBar) {
            try #expect(solidFill == palette.panelSurface)
        } else {
            Issue.record("bottomBar should use glass")
        }

        if case let .solid(fill) = MaterialRoleStyle(role: .modal) {
            try #expect(fill == palette.panelSurface)
        } else {
            Issue.record("modal should use solid surface")
        }

        if case let .glass(_, solidFill) = MaterialRoleStyle(role: .popover) {
            try #expect(solidFill == palette.elevatedBackground)
        } else {
            Issue.record("popover should use glass")
        }

        if case let .glass(_, solidFill) = MaterialRoleStyle(role: .rewardReveal) {
            try #expect(solidFill == palette.elevatedBackground)
        } else {
            Issue.record("rewardReveal should use tinted glass")
        }

        if case .ultraThinMaterial = MaterialRoleStyle(role: .subtleOverlay) {} else {
            Issue.record("subtleOverlay should keep ultra-thin material")
        }

        if case let .glass(_, solidFill) = MaterialRoleStyle(role: .homesteadFooter) {
            try #expect(solidFill == HomesteadPalette.walletPanel)
        } else {
            Issue.record("homesteadFooter should use wallet panel glass")
        }
    }

    @Test func glassChromeSolidFillsAreDistinct() throws {
        let palette = ThemePalette.apple
        try #expect(palette.elevatedBackground != palette.panelSurface)
        try #expect(palette.panelSurface != palette.secondaryBackground)
    }

    @Test func homesteadPaletteUsesDarkChrome() throws {
        try #expect(HomesteadPalette.background != .clear)
        try #expect(HomesteadPalette.panel != .clear)
        try #expect(HomesteadPalette.stroke != .clear)
        try #expect(HomesteadPalette.accent != .clear)
        try #expect(HomesteadPalette.walletPanel != .clear)
    }
}
