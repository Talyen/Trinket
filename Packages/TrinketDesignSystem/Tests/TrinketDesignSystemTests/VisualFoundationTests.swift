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

        if case let .glass(_, solidFill) = MaterialRoleStyle(role: .homesteadFooter, colorScheme: .dark) {
            try #expect(solidFill == HomesteadPalette.elevatedPanel(for: .dark))
        } else {
            Issue.record("homesteadFooter should use tinted glass")
        }
    }

    @Test func glassChromeSolidFillsAreDistinct() throws {
        let palette = ThemePalette.apple
        try #expect(palette.elevatedBackground != palette.panelSurface)
        try #expect(palette.panelSurface != palette.secondaryBackground)
    }

    @Test func homesteadPaletteAdaptsAcrossAppearances() throws {
        try #expect(HomesteadPalette.background(for: .dark) != HomesteadPalette.background(for: .light))
        try #expect(HomesteadPalette.panel(for: .dark) != HomesteadPalette.panel(for: .light))
        try #expect(HomesteadPalette.stroke(for: .dark) != HomesteadPalette.stroke(for: .light))
    }
}
