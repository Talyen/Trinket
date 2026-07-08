import SwiftUI
import TrinketDesignSystem
import Testing

@Suite
struct VisualFoundationTests {
    @Test func backgroundModeDisplayNamesAreNonEmpty() {
        for mode in BackgroundMode.allCases {
            #expect(!(mode.displayName.isEmpty))
            #expect(mode.id == mode)
        }
    }

    @Test func typographyRolesProvideFonts() {
        #expect(TypographyRole.button.font != TypographyRole.body.font)
        #expect(TypographyRole.statValue.font != TypographyRole.tooltip.font)
    }

    @Test func materialRoleStylesMatchLiquidGlassPlan() {
        let palette = ThemePalette.apple

        if case .none = MaterialRoleStyle(role: .toolbar) {} else {
            Issue.record("toolbar should pass through without custom chrome")
        }

        if case let .glass(_, solidFill) = MaterialRoleStyle(role: .bottomBar) {
            #expect(solidFill == palette.panelSurface)
        } else {
            Issue.record("bottomBar should use glass")
        }

        if case let .solid(fill) = MaterialRoleStyle(role: .modal) {
            #expect(fill == palette.panelSurface)
        } else {
            Issue.record("modal should use solid surface")
        }

        if case let .glass(_, solidFill) = MaterialRoleStyle(role: .popover) {
            #expect(solidFill == palette.elevatedBackground)
        } else {
            Issue.record("popover should use glass")
        }

        if case let .glass(_, solidFill) = MaterialRoleStyle(role: .rewardReveal) {
            #expect(solidFill == palette.elevatedBackground)
        } else {
            Issue.record("rewardReveal should use tinted glass")
        }

        if case .ultraThinMaterial = MaterialRoleStyle(role: .subtleOverlay) {} else {
            Issue.record("subtleOverlay should keep ultra-thin material")
        }
    }

    @Test func glassChromeSolidFillsAreDistinct() {
        let palette = ThemePalette.apple
        #expect(palette.elevatedBackground != palette.panelSurface)
        #expect(palette.panelSurface != palette.secondaryBackground)
    }
}
