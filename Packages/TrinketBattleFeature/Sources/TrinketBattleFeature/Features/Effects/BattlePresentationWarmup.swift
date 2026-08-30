import SwiftUI
import TrinketFeatureSupport

@MainActor
public enum BattlePresentationWarmup {
    public static func prepareAndWait(displayScale: CGFloat) async {
        async let standardDissolve: Void = CardDissolveTexture.prepare()
        async let slicedDissolve: Void = CardDissolveTexture.prepare(
            cutAngleDegrees: CombatantSliceGeometry.angleDegrees,
        )
        async let feedbackRasters: Void = CombatFeedbackRasterPool.shared.prewarmInfrastructureAndWait(
            displayScale: displayScale,
        )
        _ = await (standardDissolve, slicedDissolve, feedbackRasters)
    }
}
