import Foundation
import TrinketDesignSystem

enum CombatFeedbackAttackRecipes {
    static func cardAttack(for kind: CombatantAttackReactionKind) -> CombatantAttackReactionRecipe {
        switch kind {
        case .none: noneCardAttack
        case .attack: lungeCardAttack
        }
    }

    static let noneCardAttack = CombatantAttackReactionRecipe(
        kind: .none,
        scaleX: [.init(value: 1.0, duration: 0.01)],
        scaleY: [.init(value: 1.0, duration: 0.01)],
        offsetX: [.init(value: 0, duration: 0.01)],
        offsetY: [.init(value: 0, duration: 0.01)],
        rotation: [.init(value: 0, duration: 0.01, usesSpring: false)],
        impactDelay: 0,
        duration: 0.01
    )

    /// Pull up / compress → snap toward party → bouncy settle.
    /// Impact at end of swing (0.40 + 0.15); recovery overlaps damage feedback.
    static let lungeCardAttack = CombatantAttackReactionRecipe(
        kind: .attack,
        scaleX: [
            .init(value: 0.98, duration: 0.40),
            .init(value: 1.05, duration: 0.15),
            .init(value: 1.0, duration: 0.45)
        ],
        scaleY: [
            .init(value: 1.02, duration: 0.40),
            .init(value: 0.94, duration: 0.15),
            .init(value: 1.0, duration: 0.45)
        ],
        offsetX: [
            .init(value: 0, duration: 0.40),
            .init(value: 0, duration: 0.15),
            .init(value: 0, duration: 0.45)
        ],
        offsetY: [
            .init(value: -12, duration: 0.40),
            .init(value: 28, duration: 0.15),
            .init(value: 0, duration: 0.45)
        ],
        rotation: [
            .init(value: -4, duration: 0.40, usesSpring: false),
            .init(value: 3, duration: 0.15, usesSpring: false),
            .init(value: 0, duration: 0.45, usesSpring: false)
        ],
        impactDelay: 0.55,
        duration: 1.0
    )
}
