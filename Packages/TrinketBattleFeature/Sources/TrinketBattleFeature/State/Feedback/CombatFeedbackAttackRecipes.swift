import Foundation
import TrinketDesignSystem
import TrinketFeatureSupport

enum CombatFeedbackAttackRecipes {
    struct Timing {
        let preparation: TimeInterval
        let swing: TimeInterval
        let recovery: TimeInterval
        let preparationCap: TimeInterval
    }

    static func timing(isPartyMember: Bool) -> Timing {
        Timing(
            preparation: isPartyMember ? 0.10 : lungeCardAttack.windUp.duration,
            swing: lungeCardAttack.swing.duration,
            recovery: lungeCardAttack.recovery.duration, preparationCap: 0.08,
        )
    }

    static let lungeCardAttack = CombatantAttackReactionRecipe(
        windUp: .init(pose: .init(scaleX: 0.98, scaleY: 1.02, offsetY: -12, rotation: -4), duration: 0.40),
        swing: .init(pose: .init(scaleX: 1.05, scaleY: 0.94, offsetY: 28, rotation: 3), duration: 0.15),
        recovery: .init(pose: .rest, duration: 0.45),
    )
}
