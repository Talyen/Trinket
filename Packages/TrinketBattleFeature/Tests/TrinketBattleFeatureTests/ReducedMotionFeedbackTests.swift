import CoreGraphics
import Foundation
import QuartzCore
import Testing
import TrinketCore
@testable import TrinketBattleFeature

struct ReducedMotionFeedbackTests {
    @Test @MainActor func `impact feedback stays fixed during its lifetime under Reduce Motion`() throws {
        let start = Date.now
        let view = CombatFeedbackRasterUIView(frame: CGRect(x: 0, y: 0, width: 180, height: 250))
        view.reduceMotion = true
        defer { view.apply(chips: []) }
        let item = CombatFeedbackItem(
            id: 1, sourceEventIDs: [1], actionGroupID: 1, presentationIndex: 0,
            targetID: "enemy", feedbackClass: .directDamage, keyword: .physical, visualRole: .keyword,
            label: .amount(-8), availableAt: start, expiresAt: start.addingTimeInterval(1.05), reactionKind: .damage,
        )
        let raster = try #require(CombatFeedbackRasterPool().prepare(for: item, displayScale: 1))
        view.apply(chips: [(item, raster)])
        let layer = try #require(view.layer.sublayers?.first { !$0.isHidden && $0.contents != nil })
        view.debugTickMotion(at: start.addingTimeInterval(0.1))
        let position = layer.position
        let transform = layer.transform
        view.debugTickMotion(at: start.addingTimeInterval(0.8))
        #expect(layer.position == position)
        #expect(CATransform3DEqualToTransform(layer.transform, transform))
    }
}
