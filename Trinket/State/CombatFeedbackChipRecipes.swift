import CoreGraphics
import Foundation
import SwiftUI
import TrinketDesignSystem

enum CombatFeedbackChipRecipes {
    static func chip(for feedbackClass: CombatFeedbackClass) -> CombatFeedbackChipStyle {
        switch feedbackClass {
        case .critical, .deathsDoor:
            emphasisChip(feedbackClass: feedbackClass)
        case .directDamage, .heal, .dot, .block, .dodge, .control, .buff, .resource:
            normalChip(feedbackClass: feedbackClass)
        }
    }

    // MARK: - Emphasis (~34pt largeTitle / heavy)

    private static func emphasisChip(
        feedbackClass: CombatFeedbackClass
    ) -> CombatFeedbackChipStyle {
        CombatFeedbackChipStyle(
            feedbackClass: feedbackClass,
            chrome: .emphasis,
            fontWeight: .heavy,
            textStyle: .largeTitle,
            bouncesSymbol: true,
            showsSecondaryCaption: false
        )
    }

    // MARK: - Normal (~28pt title / bold)

    /// Shared float for damage, heal, DoT, and utility chips. Color + symbol
    /// carry meaning; motion stays consistent so stacks read as one system.
    private static func normalChip(
        feedbackClass: CombatFeedbackClass
    ) -> CombatFeedbackChipStyle {
        CombatFeedbackChipStyle(
            feedbackClass: feedbackClass,
            chrome: .standard,
            fontWeight: .bold,
            textStyle: .title,
            bouncesSymbol: true,
            showsSecondaryCaption: false
        )
    }
}
