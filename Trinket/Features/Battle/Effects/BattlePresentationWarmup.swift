import SwiftUI

@MainActor
enum BattlePresentationWarmup {
    private static var preparedEffectsKey: String?

    static func prepare(
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) {
        Task { @MainActor in
            await prepareAndWait(
                dynamicTypeSize: dynamicTypeSize,
                displayScale: displayScale
            )
        }
    }

    static func prepareAndWait(
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) async {
        let key = "\(dynamicTypeSize)|\(Int((displayScale * 100).rounded()))"
        preparedEffectsKey = key
        await CardDissolveTexture.prepare()
        await CombatFeedbackRasterPool.shared.prewarmInfrastructureAndWait(
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
    }

    static func prepareForLaunch(
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) async {
        let key = "\(dynamicTypeSize)|\(Int((displayScale * 100).rounded()))"
        preparedEffectsKey = key
        await CardDissolveTexture.prepare()
        await CombatFeedbackRasterPool.shared.prewarmInfrastructureAndWait(
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
    }
}
