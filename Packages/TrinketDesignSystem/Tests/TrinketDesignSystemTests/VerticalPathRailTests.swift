import SwiftUI
import Testing
@testable import TrinketDesignSystem

struct VerticalPathRailTests {
    @Test func pathConnectorStyleHomesteadAccentUsesPalette() {
        let style = PathConnectorStyle.homesteadAccent
        #expect(style.progressedColor == TrinketDesign.Colors.accent)
        #expect(style.completedColor == TrinketDesign.Colors.success)
        #expect(style.progressedWidth == 3)
        #expect(style.futureWidth == 2)
    }
}
