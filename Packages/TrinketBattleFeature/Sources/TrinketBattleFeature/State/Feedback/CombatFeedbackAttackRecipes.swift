import Foundation
import TrinketDesignSystem
import TrinketFeatureSupport

enum CombatFeedbackAttackRecipes {
    static let manualPreparation: TimeInterval = 0.025
    static let manualSwing: TimeInterval = 0.075
    static let manualRecovery: TimeInterval = 0.300

    struct Timing {
        let preparation: TimeInterval
        let swing: TimeInterval
        let recovery: TimeInterval
        let preparationCap: TimeInterval
    }

    static let manualTiming = Timing(
        preparation: manualPreparation, swing: manualSwing, recovery: manualRecovery, preparationCap: manualPreparation,
    )
    static let automaticTiming = Timing(
        preparation: lungeCardAttack.windUpDuration, swing: lungeCardAttack.swingDuration,
        recovery: lungeCardAttack.recoverDuration, preparationCap: 0.08,
    )

    static let lungeCardAttack = CombatantAttackReactionRecipe(
        scaleX: [
            .init(value: 0.98, duration: 0.40),
            .init(value: 1.05, duration: 0.15),
            .init(value: 1.0, duration: 0.45),
        ],
        scaleY: [
            .init(value: 1.02, duration: 0.40),
            .init(value: 0.94, duration: 0.15),
            .init(value: 1.0, duration: 0.45),
        ],
        offsetX: [
            .init(value: 0, duration: 0.40),
            .init(value: 0, duration: 0.15),
            .init(value: 0, duration: 0.45),
        ],
        offsetY: [
            .init(value: -12, duration: 0.40),
            .init(value: 28, duration: 0.15),
            .init(value: 0, duration: 0.45),
        ],
        rotation: [
            .init(value: -4, duration: 0.40, usesSpring: false),
            .init(value: 3, duration: 0.15, usesSpring: false),
            .init(value: 0, duration: 0.45, usesSpring: false),
        ],
    )
}
