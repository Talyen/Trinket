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

    /// Crit + Death's Door: same path as normal, larger start size and longer hold.
    /// Lateral motion stays tight so long labels stay readable after overflow.
    private static func emphasisChip(
        feedbackClass: CombatFeedbackClass
    ) -> CombatFeedbackMotionRecipe {
        CombatFeedbackMotionRecipe(
            feedbackClass: feedbackClass,
            initialScale: 1.22,
            initialOffsetY: 10,
            scale: [
                .init(value: 1.08, duration: 0.28),
                .init(value: 1.03, duration: 0.3),
                .init(value: 1.0, duration: 0.25)
            ],
            opacity: [
                .init(value: 1.0, duration: 0.08, usesSpring: false),
                .init(value: 1.0, duration: 0.75, usesSpring: false),
                .init(value: 0.0, duration: 0.27, usesSpring: false)
            ],
            offsetY: [
                .init(value: -52, duration: 0.28),
                .init(value: -64, duration: 0.36),
                .init(value: -70, duration: 0.22)
            ],
            lifetime: 1.1,
            // Narrow scatter: hierarchy comes from start size / lifetime / float, not chaos.
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
            initialScale: 1.12,
            initialOffsetY: 8,
            scale: [
                .init(value: 1.04, duration: 0.22),
                .init(value: 1.01, duration: 0.24),
                .init(value: 1.0, duration: 0.2)
            ],
            opacity: [
                .init(value: 1.0, duration: 0.08, usesSpring: false),
                .init(value: 1.0, duration: 0.58, usesSpring: false),
                .init(value: 0.0, duration: 0.2, usesSpring: false)
            ],
            offsetY: [
                .init(value: -38, duration: 0.22),
                .init(value: -48, duration: 0.28),
                .init(value: -50, duration: 0.18)
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
