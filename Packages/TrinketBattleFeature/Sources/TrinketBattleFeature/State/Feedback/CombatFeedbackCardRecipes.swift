import Foundation
import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

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
        impact: .init(pose: .rest, duration: 0.01),
        recovery: .init(pose: .rest, duration: 0.16),
        duration: 0.01,
    )

    static let damageCardReaction = CombatantHitReactionRecipe(
        kind: .damage,
        impact: .init(pose: .init(scaleX: 0.945, scaleY: 1.035, offsetX: -6), duration: 0.08),
        recovery: .init(pose: .rest, duration: 0.16),
        duration: 0.24,
    )

    static let criticalCardReaction = CombatantHitReactionRecipe(
        kind: .critical,
        impact: .init(pose: .init(scaleX: 0.91, scaleY: 1.055, offsetX: -9), duration: 0.08),
        recovery: .init(pose: .rest, duration: 0.18),
        duration: 0.26,
    )

    static let blockCardReaction = CombatantHitReactionRecipe(
        kind: .block,
        impact: damageCardReaction.impact,
        recovery: damageCardReaction.recovery,
        duration: damageCardReaction.duration,
    )

    static let healCardReaction = CombatantHitReactionRecipe(
        kind: .heal,
        impact: .init(pose: .init(scaleX: 1.02, scaleY: 1.02), duration: 0.1),
        recovery: .init(pose: .rest, duration: 0.16),
        duration: 0.26,
    )

    static let dodgeCardReaction = CombatantHitReactionRecipe(
        kind: .dodge,
        impact: .init(
            pose: .init(scaleX: 0.985, scaleY: 0.985, offsetX: -8, offsetY: 10, rotation: -3, rotationX: 6),
            duration: 0.16,
        ),
        recovery: .init(pose: .rest, duration: 0.24),
        duration: 0.40,
    )

    static let celebrateCardReaction = CombatantHitReactionRecipe(
        kind: .celebrate,
        impact: .init(pose: .init(scaleX: 1.1, scaleY: 0.86, offsetY: -8), duration: 0.1),
        recovery: .init(pose: .rest, duration: 0.22),
        rotation: [
            .init(value: -6, duration: 0.1),
            .init(value: 6, duration: 0.1),
            .init(value: -6, duration: 0.1),
            .init(value: 6, duration: 0.1),
            .init(value: -5, duration: 0.1),
            .init(value: 5, duration: 0.1),
            .init(value: -4, duration: 0.1),
            .init(value: 4, duration: 0.1),
            .init(value: -2, duration: 0.1),
            .init(value: 0, duration: 0.1),
        ],
        duration: 1.0,
    )
}
