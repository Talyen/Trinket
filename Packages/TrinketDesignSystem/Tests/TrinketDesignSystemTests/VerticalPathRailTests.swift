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

    @Test func pathNodeMetricsExposeSharedGeometryAndStrokeWeights() {
        #expect(PathNodeMetrics.size == 48)
        #expect(PathNodeMetrics.railWidth == 54)
        #expect(PathNodeMetrics.standardStrokeWidth == 2)
        #expect(PathNodeMetrics.emphasizedStrokeWidth == 3)
        #expect(PathNodeMetrics.strokeWidth(emphasized: false) == 2)
        #expect(PathNodeMetrics.strokeWidth(emphasized: true) == 3)
    }
}
