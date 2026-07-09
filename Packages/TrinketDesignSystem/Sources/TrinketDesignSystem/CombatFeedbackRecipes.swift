import Foundation

/// Facade over chip and card-hit recipe tables.
enum CombatFeedbackRecipes {
    static func chip(for feedbackClass: CombatFeedbackClass) -> CombatFeedbackMotionRecipe {
        CombatFeedbackChipRecipes.chip(for: feedbackClass)
    }

    static func cardReaction(for kind: CombatantHitReactionKind) -> CombatantHitReactionRecipe {
        CombatFeedbackCardRecipes.cardReaction(for: kind)
    }
}
