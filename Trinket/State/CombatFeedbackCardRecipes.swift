import Foundation
import SwiftUI
import TrinketDesignSystem

enum CombatFeedbackCardRecipes {
    static func cardReaction(for kind: CombatantHitReactionKind) -> CombatantHitReactionRecipe {
        switch kind {
        case .none: noneCardReaction
        case .damage: damageCardReaction
        case .critical: criticalCardReaction
        case .block: blockCardReaction
        case .heal: healCardReaction
        case .dodge: dodgeCardReaction
        case .celebrate: celebrateCardReaction
        }
    }

    static let noneCardReaction = CombatantHitReactionRecipe(
        kind: .none,
        scaleX: [.init(value: 1.0, duration: 0.01)],
        scaleY: [.init(value: 1.0, duration: 0.01)],
        offsetX: [.init(value: 0, duration: 0.01)],
        offsetY: [.init(value: 0, duration: 0.01)],
        duration: 0.01
    )

    static let damageCardReaction = CombatantHitReactionRecipe(
        kind: .damage,
        scaleX: [
            .init(value: 0.96, duration: 0.08),
            .init(value: 1.0, duration: 0.16),
        ],
        scaleY: [
            .init(value: 1.025, duration: 0.08),
            .init(value: 1.0, duration: 0.16),
        ],
        offsetX: [
            .init(value: -4, duration: 0.08),
            .init(value: 0, duration: 0.16),
        ],
        offsetY: [
            .init(value: 0, duration: 0.08),
            .init(value: 0, duration: 0.16),
        ],
        duration: 0.24
    )

    static let criticalCardReaction = CombatantHitReactionRecipe(
        kind: .critical,
        scaleX: [
            .init(value: 0.93, duration: 0.08),
            .init(value: 1.0, duration: 0.18),
        ],
        scaleY: [
            .init(value: 1.04, duration: 0.08),
            .init(value: 1.0, duration: 0.18),
        ],
        offsetX: [
            .init(value: -7, duration: 0.08),
            .init(value: 0, duration: 0.18),
        ],
        offsetY: [
            .init(value: 0, duration: 0.08),
            .init(value: 0, duration: 0.18),
        ],
        duration: 0.26
    )

    static let blockCardReaction = CombatantHitReactionRecipe(
        kind: .block,
        scaleX: [
            .init(value: 0.985, duration: 0.08),
            .init(value: 1.0, duration: 0.18),
        ],
        scaleY: [
            .init(value: 0.985, duration: 0.08),
            .init(value: 1.0, duration: 0.18),
        ],
        offsetX: [
            .init(value: 0, duration: 0.08),
            .init(value: 0, duration: 0.18),
        ],
        offsetY: [
            .init(value: 0, duration: 0.08),
            .init(value: 0, duration: 0.18),
        ],
        duration: 0.28
    )

    static let healCardReaction = CombatantHitReactionRecipe(
        kind: .heal,
        scaleX: [
            .init(value: 1.02, duration: 0.1),
            .init(value: 1.0, duration: 0.16),
        ],
        scaleY: [
            .init(value: 1.02, duration: 0.1),
            .init(value: 1.0, duration: 0.16),
        ],
        offsetX: [
            .init(value: 0, duration: 0.1),
            .init(value: 0, duration: 0.16),
        ],
        offsetY: [
            .init(value: 0, duration: 0.1),
            .init(value: 0, duration: 0.16),
        ],
        duration: 0.26
    )

    static let dodgeCardReaction = CombatantHitReactionRecipe(
        kind: .dodge,
        scaleX: [
            .init(value: 1.0, duration: 0.08),
            .init(value: 1.0, duration: 0.16),
        ],
        scaleY: [
            .init(value: 1.0, duration: 0.08),
            .init(value: 1.0, duration: 0.16),
        ],
        offsetX: [
            .init(value: 6, duration: 0.08),
            .init(value: 0, duration: 0.16),
        ],
        offsetY: [
            .init(value: 0, duration: 0.08),
            .init(value: 0, duration: 0.16),
        ],
        duration: 0.24
    )

    /// Soft vertical squish + hop with a 1s left-right dance tilt.
    static let celebrateCardReaction = CombatantHitReactionRecipe(
        kind: .celebrate,
        scaleX: [
            .init(value: 1.1, duration: 0.1),
            .init(value: 1.0, duration: 0.22),
        ],
        scaleY: [
            .init(value: 0.86, duration: 0.1),
            .init(value: 1.0, duration: 0.22),
        ],
        offsetX: [
            .init(value: 0, duration: 0.1),
            .init(value: 0, duration: 0.22),
        ],
        offsetY: [
            .init(value: -8, duration: 0.1),
            .init(value: 0, duration: 0.22),
        ],
        rotation: [
            .init(value: -6, duration: 0.1, usesSpring: false),
            .init(value: 6, duration: 0.1, usesSpring: false),
            .init(value: -6, duration: 0.1, usesSpring: false),
            .init(value: 6, duration: 0.1, usesSpring: false),
            .init(value: -5, duration: 0.1, usesSpring: false),
            .init(value: 5, duration: 0.1, usesSpring: false),
            .init(value: -4, duration: 0.1, usesSpring: false),
            .init(value: 4, duration: 0.1, usesSpring: false),
            .init(value: -2, duration: 0.1, usesSpring: false),
            .init(value: 0, duration: 0.1, usesSpring: false),
        ],
        duration: 1.0
    )
}
