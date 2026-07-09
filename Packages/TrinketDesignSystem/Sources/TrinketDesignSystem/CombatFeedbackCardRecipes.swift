import Foundation
import SwiftUI

enum CombatFeedbackCardRecipes {
    static func cardReaction(for kind: CombatantHitReactionKind) -> CombatantHitReactionRecipe {
        switch kind {
        case .none: return noneCardReaction
        case .damage: return damageCardReaction
        case .critical: return criticalCardReaction
        case .heal: return healCardReaction
        case .dodge: return dodgeCardReaction
        }
    }

    static let noneCardReaction = CombatantHitReactionRecipe(
        kind: .none,
        scale: [.init(value: 1.0, duration: 0.01)],
        offsetX: [.init(value: 0, duration: 0.01)],
        flashOpacity: [.init(value: 0, duration: 0.01, usesSpring: false)],
        duration: 0.01
    )

    static let damageCardReaction = CombatantHitReactionRecipe(
        kind: .damage,
        scale: [
            .init(value: 0.97, duration: 0.08),
            .init(value: 1.0, duration: 0.16)
        ],
        offsetX: [
            .init(value: -4, duration: 0.08),
            .init(value: 0, duration: 0.16)
        ],
        flashOpacity: [
            .init(value: 0.35, duration: 0.06, usesSpring: false),
            .init(value: 0.0, duration: 0.16, usesSpring: false)
        ],
        duration: 0.24
    )

    static let criticalCardReaction = CombatantHitReactionRecipe(
        kind: .critical,
        scale: [
            .init(value: 0.95, duration: 0.08),
            .init(value: 1.0, duration: 0.18)
        ],
        offsetX: [
            .init(value: -7, duration: 0.08),
            .init(value: 0, duration: 0.18)
        ],
        flashOpacity: [
            .init(value: 0.5, duration: 0.06, usesSpring: false),
            .init(value: 0.0, duration: 0.18, usesSpring: false)
        ],
        duration: 0.26
    )

    static let healCardReaction = CombatantHitReactionRecipe(
        kind: .heal,
        scale: [
            .init(value: 1.02, duration: 0.1),
            .init(value: 1.0, duration: 0.16)
        ],
        offsetX: [
            .init(value: 0, duration: 0.1),
            .init(value: 0, duration: 0.16)
        ],
        flashOpacity: [
            .init(value: 0.28, duration: 0.08, usesSpring: false),
            .init(value: 0.0, duration: 0.18, usesSpring: false)
        ],
        duration: 0.26
    )

    static let dodgeCardReaction = CombatantHitReactionRecipe(
        kind: .dodge,
        scale: [
            .init(value: 1.0, duration: 0.08),
            .init(value: 1.0, duration: 0.16)
        ],
        offsetX: [
            .init(value: 6, duration: 0.08),
            .init(value: 0, duration: 0.16)
        ],
        flashOpacity: [
            .init(value: 0.12, duration: 0.06, usesSpring: false),
            .init(value: 0.0, duration: 0.14, usesSpring: false)
        ],
        duration: 0.24
    )
}
