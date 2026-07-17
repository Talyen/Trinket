import CoreGraphics
import Foundation
import SwiftUI

enum CombatFeedbackChipRecipes {
    static func chip(for feedbackClass: CombatFeedbackClass) -> CombatFeedbackMotionRecipe {
        switch feedbackClass {
        case .critical: criticalChip
        case .deathsDoor: deathsDoorChip
        case .directDamage: directDamageChip
        case .heal: healChip
        case .dot: dotChip
        case .block: blockChip
        case .dodge: dodgeChip
        case .control: controlChip
        case .buff: buffChip
        case .resource: resourceChip
        }
    }

    // MARK: - Emphasis tier (big moments)

    private static func emphasisChip(
        feedbackClass: CombatFeedbackClass,
        rotation: [CombatFeedbackKeyframeSample] = []
    ) -> CombatFeedbackMotionRecipe {
        CombatFeedbackMotionRecipe(
            feedbackClass: feedbackClass,
            initialScale: 0.68,
            initialOffsetY: 14,
            scale: [
                .init(value: 1.55, duration: 0.1),
                .init(value: 1.18, duration: 0.2),
                .init(value: 1.06, duration: 0.58)
            ],
            opacity: [
                .init(value: 1.0, duration: 0.1, usesSpring: false),
                .init(value: 1.0, duration: 0.86, usesSpring: false),
                .init(value: 0.0, duration: 0.24, usesSpring: false)
            ],
            offsetY: [
                .init(value: -18, duration: 0.1),
                .init(value: -52, duration: 0.6),
                .init(value: -74, duration: 0.34)
            ],
            rotation: rotation,
            lifetime: 1.2,
            horizontalJitter: -6 ... 6,
            stackSpacing: 32,
            chrome: .emphasis,
            fontWeight: .black,
            textStyle: .largeTitle,
            bouncesSymbol: true,
            showsSecondaryCaption: false
        )
    }

    // MARK: - Notable tier (significant events)

    private static func notableChip(
        feedbackClass: CombatFeedbackClass,
        fontWeight: Font.Weight,
        textStyle: Font.TextStyle
    ) -> CombatFeedbackMotionRecipe {
        CombatFeedbackMotionRecipe(
            feedbackClass: feedbackClass,
            initialScale: 0.78,
            scale: [
                .init(value: 1.24, duration: 0.1),
                .init(value: 1.04, duration: 0.18),
                .init(value: 0.97, duration: 0.5)
            ],
            opacity: [
                .init(value: 1.0, duration: 0.1, usesSpring: false),
                .init(value: 1.0, duration: 0.7, usesSpring: false),
                .init(value: 0.0, duration: 0.2, usesSpring: false)
            ],
            offsetY: [
                .init(value: -12, duration: 0.1),
                .init(value: -38, duration: 0.48),
                .init(value: -56, duration: 0.3)
            ],
            lifetime: 1.0,
            horizontalJitter: -10 ... 10,
            stackSpacing: 28,
            chrome: .standard,
            fontWeight: fontWeight,
            textStyle: textStyle,
            bouncesSymbol: true,
            showsSecondaryCaption: false
        )
    }

    // MARK: - Subtle tier (minor events)

    private static func subtleChip(
        feedbackClass: CombatFeedbackClass,
        chrome: ChipChromeRole,
        bouncesSymbol: Bool,
        fontWeight: Font.Weight,
        textStyle: Font.TextStyle,
        horizontalJitter: ClosedRange<CGFloat>,
        offsetX: [CombatFeedbackKeyframeSample] = [],
        opacityFadeIn: TimeInterval = 0.1
    ) -> CombatFeedbackMotionRecipe {
        CombatFeedbackMotionRecipe(
            feedbackClass: feedbackClass,
            initialScale: 0.84,
            scale: [
                .init(value: 1.12, duration: 0.1),
                .init(value: 1.0, duration: 0.16),
                .init(value: 0.97, duration: 0.4)
            ],
            opacity: [
                .init(value: 1.0, duration: opacityFadeIn, usesSpring: false),
                .init(value: 1.0, duration: 0.72 - opacityFadeIn, usesSpring: false),
                .init(value: 0.0, duration: 0.18, usesSpring: false)
            ],
            offsetY: [
                .init(value: -6, duration: 0.1),
                .init(value: -22, duration: 0.4),
                .init(value: -44, duration: 0.28)
            ],
            offsetX: offsetX,
            lifetime: 0.9,
            horizontalJitter: horizontalJitter,
            stackSpacing: 22,
            chrome: chrome,
            fontWeight: fontWeight,
            textStyle: textStyle,
            bouncesSymbol: bouncesSymbol,
            showsSecondaryCaption: false
        )
    }

    // MARK: - Per-class recipes

    static let criticalChip = emphasisChip(
        feedbackClass: .critical,
        rotation: [
            .init(value: -7, duration: 0.08),
            .init(value: 4, duration: 0.1),
            .init(value: 0, duration: 0.16)
        ]
    )

    static let deathsDoorChip = emphasisChip(feedbackClass: .deathsDoor)

    static let directDamageChip = notableChip(
        feedbackClass: .directDamage,
        fontWeight: .heavy,
        textStyle: .largeTitle
    )

    static let healChip = notableChip(
        feedbackClass: .heal,
        fontWeight: .bold,
        textStyle: .title
    )

    static let dotChip = subtleChip(
        feedbackClass: .dot,
        chrome: .compact,
        bouncesSymbol: false,
        fontWeight: .bold,
        textStyle: .title2,
        horizontalJitter: -8 ... 8,
        opacityFadeIn: 0.08
    )

    static let blockChip = subtleChip(
        feedbackClass: .block,
        chrome: .compact,
        bouncesSymbol: true,
        fontWeight: .bold,
        textStyle: .title3,
        horizontalJitter: -5 ... 5
    )

    static let dodgeChip = subtleChip(
        feedbackClass: .dodge,
        chrome: .utility,
        bouncesSymbol: true,
        fontWeight: .bold,
        textStyle: .title3,
        horizontalJitter: -2 ... 2,
        offsetX: [
            .init(value: 10, duration: 0.1),
            .init(value: 18, duration: 0.3),
            .init(value: 22, duration: 0.22)
        ]
    )

    static let controlChip = subtleChip(
        feedbackClass: .control,
        chrome: .utility,
        bouncesSymbol: true,
        fontWeight: .bold,
        textStyle: .title3,
        horizontalJitter: -6 ... 6
    )

    static let buffChip = subtleChip(
        feedbackClass: .buff,
        chrome: .standard,
        bouncesSymbol: false,
        fontWeight: .semibold,
        textStyle: .title3,
        horizontalJitter: -7 ... 7
    )

    static let resourceChip = subtleChip(
        feedbackClass: .resource,
        chrome: .standard,
        bouncesSymbol: true,
        fontWeight: .bold,
        textStyle: .title3,
        horizontalJitter: -7 ... 7
    )
}
