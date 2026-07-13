import SwiftUI
import Testing
@testable import TrinketDesignSystem

struct VerticalPathRailTests {
    @Test func pathConnectorStyleHomesteadAccentUsesPalette() {
        let style = PathConnectorStyle.homesteadAccent
        #expect(style.progressedColor == HomesteadPalette.accent)
        #expect(style.progressedWidth == 3)
        #expect(style.futureWidth == 2)
    }
}
