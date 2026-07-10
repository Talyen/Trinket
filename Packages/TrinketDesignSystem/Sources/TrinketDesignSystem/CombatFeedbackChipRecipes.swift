import CoreGraphics
import Foundation
import SwiftUI

enum CombatFeedbackChipRecipes {
    static func chip(for feedbackClass: CombatFeedbackClass) -> CombatFeedbackMotionRecipe {
        switch feedbackClass {
        case .directDamage: return directDamageChip
        case .critical: return criticalChip
        case .dot: return dotChip
        case .heal: return healChip
        case .block: return blockChip
        case .dodge: return dodgeChip
        case .control: return controlChip
        case .buff: return buffChip
        case .resource: return resourceChip
        case .deathsDoor: return deathsDoorChip
        }
    }

    /// Pop & rise — spring overshoot, float up, fade.
    static let directDamageChip = CombatFeedbackMotionRecipe(
        feedbackClass: .directDamage,
        scale: [
            .init(value: 1.28, duration: 0.1),
            .init(value: 1.02, duration: 0.16),
            .init(value: 0.96, duration: 0.42)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.08, usesSpring: false),
            .init(value: 1.0, duration: 0.32, usesSpring: false),
            .init(value: 0.0, duration: 0.28, usesSpring: false)
        ],
        offsetY: [
            .init(value: -14, duration: 0.1),
            .init(value: -42, duration: 0.36),
            .init(value: -62, duration: 0.22)
        ],
        lifetime: 0.7,
        horizontalJitter: -12 ... 12,
        stackSpacing: 28,
        chrome: .standard,
        fontWeight: .bold,
        textStyle: .title2,
        bouncesSymbol: true,
        showsSecondaryCaption: false
    )

    /// Pop & rise with punchier overshoot and slight rotation.
    static let criticalChip = CombatFeedbackMotionRecipe(
        feedbackClass: .critical,
        scale: [
            .init(value: 1.48, duration: 0.09),
            .init(value: 1.12, duration: 0.14),
            .init(value: 1.0, duration: 0.48)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.08, usesSpring: false),
            .init(value: 1.0, duration: 0.42, usesSpring: false),
            .init(value: 0.0, duration: 0.3, usesSpring: false)
        ],
        offsetY: [
            .init(value: -16, duration: 0.09),
            .init(value: -52, duration: 0.4),
            .init(value: -74, duration: 0.26)
        ],
        rotation: [
            .init(value: -7, duration: 0.08),
            .init(value: 4, duration: 0.1),
            .init(value: 0, duration: 0.16)
        ],
        lifetime: 0.9,
        horizontalJitter: -6 ... 6,
        stackSpacing: 32,
        chrome: .emphasis,
        fontWeight: .heavy,
        textStyle: .title,
        bouncesSymbol: true,
        showsSecondaryCaption: true
    )

    /// Compact pop & rise for DoT ticks.
    static let dotChip = CombatFeedbackMotionRecipe(
        feedbackClass: .dot,
        scale: [
            .init(value: 1.16, duration: 0.08),
            .init(value: 1.0, duration: 0.12),
            .init(value: 0.94, duration: 0.28)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.06, usesSpring: false),
            .init(value: 1.0, duration: 0.22, usesSpring: false),
            .init(value: 0.0, duration: 0.22, usesSpring: false)
        ],
        offsetY: [
            .init(value: -8, duration: 0.08),
            .init(value: -28, duration: 0.26),
            .init(value: -40, duration: 0.18)
        ],
        lifetime: 0.55,
        horizontalJitter: -8 ... 8,
        stackSpacing: 22,
        chrome: .compact,
        fontWeight: .semibold,
        textStyle: .footnote,
        bouncesSymbol: false,
        showsSecondaryCaption: false
    )

    /// Soft float — gentler scale, smoother rise.
    static let healChip = CombatFeedbackMotionRecipe(
        feedbackClass: .heal,
        scale: [
            .init(value: 1.14, duration: 0.12),
            .init(value: 1.02, duration: 0.18),
            .init(value: 0.98, duration: 0.4)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.1, usesSpring: false),
            .init(value: 1.0, duration: 0.34, usesSpring: false),
            .init(value: 0.0, duration: 0.26, usesSpring: false)
        ],
        offsetY: [
            .init(value: -10, duration: 0.12),
            .init(value: -36, duration: 0.38),
            .init(value: -52, duration: 0.22)
        ],
        lifetime: 0.72,
        horizontalJitter: -8 ... 8,
        stackSpacing: 26,
        chrome: .standard,
        fontWeight: .bold,
        textStyle: .title3,
        bouncesSymbol: true,
        showsSecondaryCaption: false
    )

    /// Soft settle — smaller travel.
    static let blockChip = CombatFeedbackMotionRecipe(
        feedbackClass: .block,
        scale: [
            .init(value: 1.1, duration: 0.1),
            .init(value: 1.0, duration: 0.14),
            .init(value: 0.97, duration: 0.32)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.08, usesSpring: false),
            .init(value: 1.0, duration: 0.28, usesSpring: false),
            .init(value: 0.0, duration: 0.22, usesSpring: false)
        ],
        offsetY: [
            .init(value: -4, duration: 0.1),
            .init(value: -18, duration: 0.3),
            .init(value: -28, duration: 0.2)
        ],
        lifetime: 0.6,
        horizontalJitter: -5 ... 5,
        stackSpacing: 22,
        chrome: .compact,
        fontWeight: .bold,
        textStyle: .callout,
        bouncesSymbol: true,
        showsSecondaryCaption: false
    )

    /// Soft settle with lateral drift.
    static let dodgeChip = CombatFeedbackMotionRecipe(
        feedbackClass: .dodge,
        scale: [
            .init(value: 1.08, duration: 0.1),
            .init(value: 1.0, duration: 0.14),
            .init(value: 0.97, duration: 0.34)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.08, usesSpring: false),
            .init(value: 1.0, duration: 0.3, usesSpring: false),
            .init(value: 0.0, duration: 0.24, usesSpring: false)
        ],
        offsetY: [
            .init(value: -4, duration: 0.1),
            .init(value: -16, duration: 0.3),
            .init(value: -24, duration: 0.22)
        ],
        offsetX: [
            .init(value: 12, duration: 0.12),
            .init(value: 20, duration: 0.3),
            .init(value: 24, duration: 0.22)
        ],
        lifetime: 0.65,
        horizontalJitter: -2 ... 2,
        stackSpacing: 22,
        chrome: .utility,
        fontWeight: .bold,
        textStyle: .callout,
        bouncesSymbol: true,
        showsSecondaryCaption: false
    )

    /// Soft settle.
    static let controlChip = CombatFeedbackMotionRecipe(
        feedbackClass: .control,
        scale: [
            .init(value: 1.1, duration: 0.1),
            .init(value: 1.0, duration: 0.14),
            .init(value: 0.97, duration: 0.34)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.08, usesSpring: false),
            .init(value: 1.0, duration: 0.3, usesSpring: false),
            .init(value: 0.0, duration: 0.24, usesSpring: false)
        ],
        offsetY: [
            .init(value: -6, duration: 0.1),
            .init(value: -20, duration: 0.32),
            .init(value: -30, duration: 0.22)
        ],
        lifetime: 0.65,
        horizontalJitter: -6 ... 6,
        stackSpacing: 22,
        chrome: .utility,
        fontWeight: .bold,
        textStyle: .callout,
        bouncesSymbol: true,
        showsSecondaryCaption: false
    )

    /// Soft float.
    static let buffChip = CombatFeedbackMotionRecipe(
        feedbackClass: .buff,
        scale: [
            .init(value: 1.1, duration: 0.11),
            .init(value: 1.02, duration: 0.16),
            .init(value: 0.98, duration: 0.34)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.08, usesSpring: false),
            .init(value: 1.0, duration: 0.3, usesSpring: false),
            .init(value: 0.0, duration: 0.24, usesSpring: false)
        ],
        offsetY: [
            .init(value: -8, duration: 0.11),
            .init(value: -28, duration: 0.32),
            .init(value: -40, duration: 0.22)
        ],
        lifetime: 0.65,
        horizontalJitter: -7 ... 7,
        stackSpacing: 22,
        chrome: .standard,
        fontWeight: .semibold,
        textStyle: .callout,
        bouncesSymbol: false,
        showsSecondaryCaption: false
    )

    /// Soft float.
    static let resourceChip = CombatFeedbackMotionRecipe(
        feedbackClass: .resource,
        scale: [
            .init(value: 1.1, duration: 0.11),
            .init(value: 1.02, duration: 0.16),
            .init(value: 0.98, duration: 0.34)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.08, usesSpring: false),
            .init(value: 1.0, duration: 0.3, usesSpring: false),
            .init(value: 0.0, duration: 0.24, usesSpring: false)
        ],
        offsetY: [
            .init(value: -8, duration: 0.11),
            .init(value: -28, duration: 0.32),
            .init(value: -40, duration: 0.22)
        ],
        lifetime: 0.65,
        horizontalJitter: -7 ... 7,
        stackSpacing: 22,
        chrome: .standard,
        fontWeight: .bold,
        textStyle: .callout,
        bouncesSymbol: true,
        showsSecondaryCaption: false
    )

    /// Soft float with a bit more presence.
    static let deathsDoorChip = CombatFeedbackMotionRecipe(
        feedbackClass: .deathsDoor,
        scale: [
            .init(value: 1.18, duration: 0.11),
            .init(value: 1.04, duration: 0.16),
            .init(value: 0.98, duration: 0.4)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.1, usesSpring: false),
            .init(value: 1.0, duration: 0.36, usesSpring: false),
            .init(value: 0.0, duration: 0.26, usesSpring: false)
        ],
        offsetY: [
            .init(value: -10, duration: 0.11),
            .init(value: -34, duration: 0.36),
            .init(value: -48, duration: 0.24)
        ],
        lifetime: 0.8,
        horizontalJitter: -5 ... 5,
        stackSpacing: 26,
        chrome: .emphasis,
        fontWeight: .heavy,
        textStyle: .title3,
        bouncesSymbol: true,
        showsSecondaryCaption: false
    )
}
