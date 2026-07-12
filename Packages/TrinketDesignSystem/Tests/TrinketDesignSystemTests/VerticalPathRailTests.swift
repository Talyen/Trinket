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

    @Test func pathConnectorStyleAcceptsCustomColorsAndWidths() {
        let style = PathConnectorStyle(
            progressedColor: .orange,
            futureColor: .gray,
            progressedWidth: 2.5,
            futureWidth: 1.5
        )
        #expect(style.progressedColor == .orange)
        #expect(style.futureColor == .gray)
        #expect(style.progressedWidth == 2.5)
        #expect(style.futureWidth == 1.5)
    }
}
