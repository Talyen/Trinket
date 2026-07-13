import CoreGraphics
import Foundation
import SwiftUI

enum CombatFeedbackChipRecipes {
    static func chip(for feedbackClass: CombatFeedbackClass) -> CombatFeedbackMotionRecipe {
        switch feedbackClass {
        case .directDamage: directDamageChip
        case .critical: criticalChip
        case .dot: dotChip
        case .heal: healChip
        case .block: blockChip
        case .dodge: dodgeChip
        case .control: controlChip
        case .buff: buffChip
        case .resource: resourceChip
        case .deathsDoor: deathsDoorChip
        }
    }

    /// Pop & rise — spring overshoot, float up, fade.
    static let directDamageChip = CombatFeedbackMotionRecipe(
        feedbackClass: .directDamage,
        scale: [
            .init(value: 1.28, duration: 0.11),
            .init(value: 1.02, duration: 0.2),
            .init(value: 0.96, duration: 0.55)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.1, usesSpring: false),
            .init(value: 1.0, duration: 0.48, usesSpring: false),
            .init(value: 0.0, duration: 0.32, usesSpring: false)
        ],
        offsetY: [
            .init(value: -14, duration: 0.11),
            .init(value: -42, duration: 0.48),
            .init(value: -62, duration: 0.31)
        ],
        lifetime: 1.0,
        horizontalJitter: -12 ... 12,
        stackSpacing: 28,
        chrome: .standard,
        fontWeight: .heavy,
        textStyle: .largeTitle,
        bouncesSymbol: true,
        showsSecondaryCaption: false
    )

    /// Pop & rise with punchier overshoot and slight rotation.
    static let criticalChip = CombatFeedbackMotionRecipe(
        feedbackClass: .critical,
        initialScale: 0.68,
        initialOffsetY: 14,
        initialRotation: -5,
        scale: [
            .init(value: 1.62, duration: 0.1),
            .init(value: 1.22, duration: 0.2),
            .init(value: 1.1, duration: 0.6)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.1, usesSpring: false),
            .init(value: 1.0, duration: 0.58, usesSpring: false),
            .init(value: 0.0, duration: 0.38, usesSpring: false)
        ],
        offsetY: [
            .init(value: -16, duration: 0.1),
            .init(value: -52, duration: 0.58),
            .init(value: -74, duration: 0.38)
        ],
        rotation: [
            .init(value: -7, duration: 0.08),
            .init(value: 4, duration: 0.1),
            .init(value: 0, duration: 0.16)
        ],
        lifetime: 1.18,
        horizontalJitter: -6 ... 6,
        stackSpacing: 32,
        chrome: .emphasis,
        fontWeight: .black,
        textStyle: .largeTitle,
        bouncesSymbol: true,
        showsSecondaryCaption: false
    )

    /// Compact pop & rise for DoT ticks.
    static let dotChip = CombatFeedbackMotionRecipe(
        feedbackClass: .dot,
        initialScale: 0.82,
        scale: [
            .init(value: 1.16, duration: 0.09),
            .init(value: 1.0, duration: 0.18),
            .init(value: 0.94, duration: 0.46)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.08, usesSpring: false),
            .init(value: 1.0, duration: 0.42, usesSpring: false),
            .init(value: 0.0, duration: 0.3, usesSpring: false)
        ],
        offsetY: [
            .init(value: -8, duration: 0.09),
            .init(value: -28, duration: 0.42),
            .init(value: -52, duration: 0.3)
        ],
        lifetime: 0.9,
        horizontalJitter: -8 ... 8,
        stackSpacing: 22,
        chrome: .compact,
        fontWeight: .bold,
        textStyle: .title2,
        bouncesSymbol: false,
        showsSecondaryCaption: false
    )

    /// Soft float — gentler scale, smoother rise.
    static let healChip = CombatFeedbackMotionRecipe(
        feedbackClass: .heal,
        initialScale: 0.8,
        scale: [
            .init(value: 1.14, duration: 0.13),
            .init(value: 1.02, duration: 0.22),
            .init(value: 0.98, duration: 0.55)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.12, usesSpring: false),
            .init(value: 1.0, duration: 0.48, usesSpring: false),
            .init(value: 0.0, duration: 0.34, usesSpring: false)
        ],
        offsetY: [
            .init(value: -10, duration: 0.13),
            .init(value: -36, duration: 0.52),
            .init(value: -52, duration: 0.3)
        ],
        lifetime: 1.04,
        horizontalJitter: -8 ... 8,
        stackSpacing: 26,
        chrome: .standard,
        fontWeight: .bold,
        textStyle: .title,
        bouncesSymbol: true,
        showsSecondaryCaption: false
    )

    /// Soft settle — smaller travel.
    static let blockChip = CombatFeedbackMotionRecipe(
        feedbackClass: .block,
        initialScale: 0.84,
        scale: [
            .init(value: 1.1, duration: 0.11),
            .init(value: 1.0, duration: 0.18),
            .init(value: 0.97, duration: 0.46)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.1, usesSpring: false),
            .init(value: 1.0, duration: 0.42, usesSpring: false),
            .init(value: 0.0, duration: 0.3, usesSpring: false)
        ],
        offsetY: [
            .init(value: -4, duration: 0.11),
            .init(value: -18, duration: 0.42),
            .init(value: -48, duration: 0.3)
        ],
        lifetime: 0.9,
        horizontalJitter: -5 ... 5,
        stackSpacing: 22,
        chrome: .compact,
        fontWeight: .bold,
        textStyle: .title3,
        bouncesSymbol: true,
        showsSecondaryCaption: false
    )

    /// Soft settle with lateral drift.
    static let dodgeChip = CombatFeedbackMotionRecipe(
        feedbackClass: .dodge,
        initialScale: 0.84,
        scale: [
            .init(value: 1.08, duration: 0.11),
            .init(value: 1.0, duration: 0.18),
            .init(value: 0.97, duration: 0.48)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.1, usesSpring: false),
            .init(value: 1.0, duration: 0.44, usesSpring: false),
            .init(value: 0.0, duration: 0.32, usesSpring: false)
        ],
        offsetY: [
            .init(value: -4, duration: 0.11),
            .init(value: -16, duration: 0.44),
            .init(value: -46, duration: 0.32)
        ],
        offsetX: [
            .init(value: 12, duration: 0.12),
            .init(value: 20, duration: 0.3),
            .init(value: 24, duration: 0.22)
        ],
        lifetime: 0.94,
        horizontalJitter: -2 ... 2,
        stackSpacing: 22,
        chrome: .utility,
        fontWeight: .bold,
        textStyle: .title3,
        bouncesSymbol: true,
        showsSecondaryCaption: false
    )

    /// Soft settle.
    static let controlChip = CombatFeedbackMotionRecipe(
        feedbackClass: .control,
        initialScale: 0.82,
        scale: [
            .init(value: 1.1, duration: 0.11),
            .init(value: 1.0, duration: 0.18),
            .init(value: 0.97, duration: 0.48)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.1, usesSpring: false),
            .init(value: 1.0, duration: 0.44, usesSpring: false),
            .init(value: 0.0, duration: 0.32, usesSpring: false)
        ],
        offsetY: [
            .init(value: -6, duration: 0.11),
            .init(value: -20, duration: 0.44),
            .init(value: -50, duration: 0.32)
        ],
        lifetime: 0.98,
        horizontalJitter: -6 ... 6,
        stackSpacing: 22,
        chrome: .utility,
        fontWeight: .bold,
        textStyle: .title3,
        bouncesSymbol: true,
        showsSecondaryCaption: false
    )

    /// Soft float.
    static let buffChip = CombatFeedbackMotionRecipe(
        feedbackClass: .buff,
        initialScale: 0.84,
        scale: [
            .init(value: 1.1, duration: 0.12),
            .init(value: 1.02, duration: 0.2),
            .init(value: 0.98, duration: 0.48)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.1, usesSpring: false),
            .init(value: 1.0, duration: 0.44, usesSpring: false),
            .init(value: 0.0, duration: 0.32, usesSpring: false)
        ],
        offsetY: [
            .init(value: -8, duration: 0.12),
            .init(value: -28, duration: 0.44),
            .init(value: -50, duration: 0.32)
        ],
        lifetime: 0.98,
        horizontalJitter: -7 ... 7,
        stackSpacing: 22,
        chrome: .standard,
        fontWeight: .semibold,
        textStyle: .title3,
        bouncesSymbol: false,
        showsSecondaryCaption: false
    )

    /// Soft float.
    static let resourceChip = CombatFeedbackMotionRecipe(
        feedbackClass: .resource,
        initialScale: 0.84,
        scale: [
            .init(value: 1.1, duration: 0.12),
            .init(value: 1.02, duration: 0.2),
            .init(value: 0.98, duration: 0.48)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.1, usesSpring: false),
            .init(value: 1.0, duration: 0.44, usesSpring: false),
            .init(value: 0.0, duration: 0.32, usesSpring: false)
        ],
        offsetY: [
            .init(value: -8, duration: 0.12),
            .init(value: -28, duration: 0.44),
            .init(value: -50, duration: 0.32)
        ],
        lifetime: 0.98,
        horizontalJitter: -7 ... 7,
        stackSpacing: 22,
        chrome: .standard,
        fontWeight: .bold,
        textStyle: .title3,
        bouncesSymbol: true,
        showsSecondaryCaption: false
    )

    /// Soft float with a bit more presence.
    static let deathsDoorChip = CombatFeedbackMotionRecipe(
        feedbackClass: .deathsDoor,
        initialScale: 0.74,
        scale: [
            .init(value: 1.18, duration: 0.12),
            .init(value: 1.04, duration: 0.22),
            .init(value: 0.98, duration: 0.54)
        ],
        opacity: [
            .init(value: 1.0, duration: 0.12, usesSpring: false),
            .init(value: 1.0, duration: 0.5, usesSpring: false),
            .init(value: 0.0, duration: 0.34, usesSpring: false)
        ],
        offsetY: [
            .init(value: -10, duration: 0.12),
            .init(value: -34, duration: 0.5),
            .init(value: -48, duration: 0.34)
        ],
        lifetime: 1.1,
        horizontalJitter: -5 ... 5,
        stackSpacing: 26,
        chrome: .emphasis,
        fontWeight: .heavy,
        textStyle: .title,
        bouncesSymbol: true,
        showsSecondaryCaption: false
    )
}
