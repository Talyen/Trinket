import SwiftUI
import TrinketFeatureSupport

@MainActor
public enum BattlePresentationWarmup {
    public static func prepareAndWait(displayScale: CGFloat) async {
        await CardDissolveTexture.prepare()
        await CardDissolveTexture.prepare(
            cutAngleDegrees: CombatantSliceGeometry.angleDegrees
        )
        await CombatFeedbackRasterPool.shared.prewarmInfrastructureAndWait(
            displayScale: displayScale
        )
    }
}
