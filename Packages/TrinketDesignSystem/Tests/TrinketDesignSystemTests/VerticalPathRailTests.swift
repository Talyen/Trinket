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

    @Test func pathNodeMetricsExposeSharedGeometryAndStrokeWeights() {
        #expect(PathNodeMetrics.size == 48)
        #expect(PathNodeMetrics.railWidth == 54)
        #expect(PathNodeMetrics.standardStrokeWidth == 2)
        #expect(PathNodeMetrics.emphasizedStrokeWidth == 3)
        #expect(PathNodeMetrics.strokeWidth(emphasized: false) == 2)
        #expect(PathNodeMetrics.strokeWidth(emphasized: true) == 3)
    }
}
