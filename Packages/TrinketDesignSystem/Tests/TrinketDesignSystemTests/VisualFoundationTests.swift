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
}
