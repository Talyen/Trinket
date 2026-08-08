import SwiftUI
import TrinketFeatureSupport

@MainActor
public enum BattlePresentationWarmup {
    public static func prepareAndWait(
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) async {
        await CardDissolveTexture.prepare()
        await CardDissolveTexture.prepare(
            cutAngleDegrees: CombatantSliceGeometry.angleDegrees
        )
        await CombatFeedbackRasterPool.shared.prewarmInfrastructureAndWait(
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
    }
}
