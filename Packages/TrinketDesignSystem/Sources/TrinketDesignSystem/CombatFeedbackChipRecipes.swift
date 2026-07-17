import CoreGraphics
import Foundation
import SwiftUI

enum CombatFeedbackChipRecipes {
    static func chip(for feedbackClass: CombatFeedbackClass) -> CombatFeedbackMotionRecipe {
        switch feedbackClass {
        case .critical, .deathsDoor:
            emphasisChip(feedbackClass: feedbackClass)
        case .directDamage, .heal, .dot, .block, .dodge, .control, .buff, .resource:
            normalChip(feedbackClass: feedbackClass)
        }
    }

    // MARK: - Emphasis (~34pt largeTitle / heavy)

    /// Crit + Death's Door: same path as normal, larger amplitude and longer hold.
    /// Lateral motion stays tight so long labels stay readable after overflow.
    private static func emphasisChip(
        feedbackClass: CombatFeedbackClass
    ) -> CombatFeedbackMotionRecipe {
        CombatFeedbackMotionRecipe(
            feedbackClass: feedbackClass,
            initialScale: 0.78,
            initialOffsetY: 10,
            scale: [
                .init(value: 1.22, duration: 0.12),
                .init(value: 1.04, duration: 0.16),
                .init(value: 1.0, duration: 0.55)
            ],
            opacity: [
                .init(value: 1.0, duration: 0.08, usesSpring: false),
                .init(value: 1.0, duration: 0.75, usesSpring: false),
                .init(value: 0.0, duration: 0.27, usesSpring: false)
            ],
            offsetY: [
                .init(value: -10, duration: 0.12),
                .init(value: -44, duration: 0.52),
                .init(value: -70, duration: 0.36)
            ],
            lifetime: 1.1,
            // Narrow scatter: hierarchy comes from size/pop, not chaos.
            horizontalJitter: -4 ... 4,
            floatAngleRange: -8 ... 8,
            stackSpacing: CombatFeedbackLayout.presentationLaneSpacing,
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
    ) -> CombatFeedbackMotionRecipe {
        CombatFeedbackMotionRecipe(
            feedbackClass: feedbackClass,
            initialScale: 0.86,
            initialOffsetY: 8,
            scale: [
                .init(value: 1.1, duration: 0.1),
                .init(value: 1.0, duration: 0.14),
                .init(value: 0.98, duration: 0.42)
            ],
            opacity: [
                .init(value: 1.0, duration: 0.08, usesSpring: false),
                .init(value: 1.0, duration: 0.58, usesSpring: false),
                .init(value: 0.0, duration: 0.2, usesSpring: false)
            ],
            offsetY: [
                .init(value: -6, duration: 0.1),
                .init(value: -28, duration: 0.4),
                .init(value: -50, duration: 0.28)
            ],
            lifetime: 0.86,
            horizontalJitter: -5 ... 5,
            floatAngleRange: -10 ... 10,
            stackSpacing: CombatFeedbackLayout.presentationLaneSpacing,
            chrome: .standard,
            fontWeight: .bold,
            textStyle: .title,
            bouncesSymbol: true,
            showsSecondaryCaption: false
        )
    }
}
