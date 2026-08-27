import SwiftUI
import Testing
@testable import TrinketDesignSystem

struct VerticalPathRailTests {
    @Test func pathConnectorStatePairSingleNode() {
        let pair = PathConnectorState.pair(at: 0, count: 1) { _ in false }
        #expect(pair.before == nil)
        #expect(pair.after == nil)
    }

    @Test func pathConnectorStatePairStartNode() {
        let pair = PathConnectorState.pair(at: 0, count: 4) { $0 >= 2 }
        #expect(pair.before == nil)
        #expect(pair.after == .progressed)
    }

    @Test func pathConnectorStatePairMiddleNode() {
        let pair = PathConnectorState.pair(at: 1, count: 4) { $0 >= 2 }
        #expect(pair.before == .progressed)
        #expect(pair.after == .future)
    }

    @Test func pathConnectorStatePairEndNode() {
        let pair = PathConnectorState.pair(at: 3, count: 4) { _ in true }
        #expect(pair.before == .future)
        #expect(pair.after == nil)
    }

    @Test func pathConnectorStatePairExplicitStateFunction() {
        let pair = PathConnectorState.pair(at: 2, count: 5) { index in
            switch index {
            case 0, 1: .completed
            case 2: .progressed
            default: .future
            }
        }
        #expect(pair.before == .progressed)
        #expect(pair.after == .future)
    }

    @Test func pathNodeMetricsStrokeAndFont() {
        #expect(PathNodeMetrics.strokeWidth(emphasized: true) == PathNodeMetrics.emphasizedStrokeWidth)
        #expect(PathNodeMetrics.strokeWidth(emphasized: false) == PathNodeMetrics.standardStrokeWidth)
    }
}
