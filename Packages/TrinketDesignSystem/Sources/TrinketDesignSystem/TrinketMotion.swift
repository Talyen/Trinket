import CoreGraphics
import Foundation
import SwiftUI

/// Shared motion presets. Battle spectacle (R-008 / R-011) is the first consumer;
/// combat feedback chips extend the same vocabulary (R-001 / R-006).
public enum TrinketMotion: Sendable {
    public enum Battle: Sendable {
        /// Soft-hold after a Skill cast so caster art is readable.
        public static let skillSoftHold: TimeInterval = 0.5

        /// Typical Ultimate art-fallback hold when no video is present.
        public static let ultimateFallbackHold: TimeInterval = 4.0

        /// Delay before tap-to-skip is armed on an Ultimate cinematic.
        public static let ultimateSkipLockout: TimeInterval = 0.45

        public static let skillCalloutIn: TimeInterval = 0.12
        public static let skillCalloutHold: TimeInterval = 0.25
        public static let skillCalloutOut: TimeInterval = 0.18

        public static var skillCalloutTotal: TimeInterval {
            skillCalloutIn + skillCalloutHold + skillCalloutOut
        }

        public static let reduceMotionFade: TimeInterval = 0.18
        public static let scrimFade: TimeInterval = 0.2
        public static let ultimateCollapse: TimeInterval = 0.28

        /// Stagger between deferred Ultimate chips when the cinematic lands.
        public static let ultimateChipStagger: TimeInterval = 0.055

        /// Default chip display duration (direct damage). Prefer per-class recipes.
        public static let chipDisplayDuration: TimeInterval = 1.0

        public static let reduceMotionChipFadeIn: TimeInterval = 0.15
        public static let reduceMotionChipHold: TimeInterval = 0.7
        public static let reduceMotionChipFadeOut: TimeInterval = 0.15

        /// Max concurrent keyword particle bursts per combatant pane.
        public static let maxKeywordBurstsPerPane = 2

        public static var ultimateExpand: Animation {
            .spring(response: 0.42, dampingFraction: 0.9)
        }

        public static var ultimateCollapseAnimation: Animation {
            .spring(response: 0.32, dampingFraction: 0.92)
        }

        public static var scrim: Animation {
            .easeOut(duration: scrimFade)
        }

        public static var reduceMotion: Animation {
            .easeOut(duration: reduceMotionFade)
        }

        public static func chip(for feedbackClass: CombatFeedbackClass) -> CombatFeedbackMotionRecipe {
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

        public static func cardReaction(for kind: CombatantHitReactionKind) -> CombatantHitReactionRecipe {
            switch kind {
            case .none: return noneCardReaction
            case .damage: return damageCardReaction
            case .critical: return criticalCardReaction
            case .heal: return healCardReaction
            case .dodge: return dodgeCardReaction
            }
        }

        // MARK: - Chip recipes

        private static let directDamageChip = CombatFeedbackMotionRecipe(
            feedbackClass: .directDamage,
            scale: [
                .init(value: 1.12, duration: 0.14),
                .init(value: 1.0, duration: 0.22),
                .init(value: 0.98, duration: 0.55),
            ],
            opacity: [
                .init(value: 1.0, duration: 0.16, usesSpring: false),
                .init(value: 1.0, duration: 0.52, usesSpring: false),
                .init(value: 0.0, duration: 0.25, usesSpring: false),
            ],
            offsetY: [
                .init(value: -10, duration: 0.14),
                .init(value: -36, duration: 0.55),
                .init(value: -48, duration: 0.24),
            ],
            lifetime: 1.0,
            horizontalJitter: -10 ... 10,
            stackSpacing: 22,
            chrome: .standard,
            fontWeight: .semibold,
            fontSize: 17,
            bouncesSymbol: true,
            showsSecondaryCaption: false
        )

        private static let criticalChip = CombatFeedbackMotionRecipe(
            feedbackClass: .critical,
            scale: [
                .init(value: 1.34, duration: 0.12),
                .init(value: 1.08, duration: 0.2),
                .init(value: 1.0, duration: 0.55),
            ],
            opacity: [
                .init(value: 1.0, duration: 0.14, usesSpring: false),
                .init(value: 1.0, duration: 0.62, usesSpring: false),
                .init(value: 0.0, duration: 0.28, usesSpring: false),
            ],
            offsetY: [
                .init(value: -12, duration: 0.12),
                .init(value: -42, duration: 0.55),
                .init(value: -56, duration: 0.28),
            ],
            rotation: [
                .init(value: -6, duration: 0.1),
                .init(value: 4, duration: 0.12),
                .init(value: 0, duration: 0.2),
            ],
            lifetime: 1.15,
            horizontalJitter: -4 ... 4,
            stackSpacing: 26,
            chrome: .emphasis,
            fontWeight: .bold,
            fontSize: 20,
            bouncesSymbol: true,
            showsSecondaryCaption: true
        )

        private static let dotChip = CombatFeedbackMotionRecipe(
            feedbackClass: .dot,
            scale: [
                .init(value: 1.04, duration: 0.12),
                .init(value: 1.0, duration: 0.2),
                .init(value: 0.97, duration: 0.35),
            ],
            opacity: [
                .init(value: 1.0, duration: 0.12, usesSpring: false),
                .init(value: 1.0, duration: 0.32, usesSpring: false),
                .init(value: 0.0, duration: 0.22, usesSpring: false),
            ],
            offsetY: [
                .init(value: -6, duration: 0.12),
                .init(value: -20, duration: 0.35),
                .init(value: -28, duration: 0.2),
            ],
            lifetime: 0.7,
            horizontalJitter: -6 ... 6,
            stackSpacing: 16,
            chrome: .compact,
            fontWeight: .medium,
            fontSize: 14,
            bouncesSymbol: false,
            showsSecondaryCaption: false
        )

        private static let healChip = CombatFeedbackMotionRecipe(
            feedbackClass: .heal,
            scale: [
                .init(value: 1.08, duration: 0.16),
                .init(value: 1.0, duration: 0.24),
                .init(value: 0.99, duration: 0.5),
            ],
            opacity: [
                .init(value: 1.0, duration: 0.16, usesSpring: false),
                .init(value: 1.0, duration: 0.5, usesSpring: false),
                .init(value: 0.0, duration: 0.26, usesSpring: false),
            ],
            offsetY: [
                .init(value: -8, duration: 0.16),
                .init(value: -30, duration: 0.5),
                .init(value: -40, duration: 0.26),
            ],
            lifetime: 1.0,
            horizontalJitter: -8 ... 8,
            stackSpacing: 20,
            chrome: .standard,
            fontWeight: .semibold,
            fontSize: 17,
            bouncesSymbol: true,
            showsSecondaryCaption: false
        )

        private static let blockChip = CombatFeedbackMotionRecipe(
            feedbackClass: .block,
            scale: [
                .init(value: 1.06, duration: 0.12),
                .init(value: 1.0, duration: 0.2),
                .init(value: 0.98, duration: 0.4),
            ],
            opacity: [
                .init(value: 1.0, duration: 0.12, usesSpring: false),
                .init(value: 1.0, duration: 0.42, usesSpring: false),
                .init(value: 0.0, duration: 0.22, usesSpring: false),
            ],
            offsetY: [
                .init(value: -4, duration: 0.12),
                .init(value: -16, duration: 0.4),
                .init(value: -24, duration: 0.22),
            ],
            lifetime: 0.85,
            horizontalJitter: -5 ... 5,
            stackSpacing: 18,
            chrome: .compact,
            fontWeight: .semibold,
            fontSize: 15,
            bouncesSymbol: true,
            showsSecondaryCaption: false
        )

        private static let dodgeChip = CombatFeedbackMotionRecipe(
            feedbackClass: .dodge,
            scale: [
                .init(value: 1.05, duration: 0.12),
                .init(value: 1.0, duration: 0.22),
                .init(value: 0.98, duration: 0.4),
            ],
            opacity: [
                .init(value: 1.0, duration: 0.12, usesSpring: false),
                .init(value: 1.0, duration: 0.45, usesSpring: false),
                .init(value: 0.0, duration: 0.24, usesSpring: false),
            ],
            offsetY: [
                .init(value: -4, duration: 0.12),
                .init(value: -14, duration: 0.4),
                .init(value: -20, duration: 0.24),
            ],
            offsetX: [
                .init(value: 10, duration: 0.14),
                .init(value: 16, duration: 0.4),
                .init(value: 18, duration: 0.24),
            ],
            lifetime: 0.9,
            horizontalJitter: -2 ... 2,
            stackSpacing: 18,
            chrome: .utility,
            fontWeight: .semibold,
            fontSize: 15,
            bouncesSymbol: true,
            showsSecondaryCaption: false
        )

        private static let controlChip = CombatFeedbackMotionRecipe(
            feedbackClass: .control,
            scale: [
                .init(value: 1.06, duration: 0.14),
                .init(value: 1.0, duration: 0.22),
                .init(value: 0.98, duration: 0.42),
            ],
            opacity: [
                .init(value: 1.0, duration: 0.14, usesSpring: false),
                .init(value: 1.0, duration: 0.45, usesSpring: false),
                .init(value: 0.0, duration: 0.24, usesSpring: false),
            ],
            offsetY: [
                .init(value: -6, duration: 0.14),
                .init(value: -18, duration: 0.42),
                .init(value: -24, duration: 0.24),
            ],
            lifetime: 0.9,
            horizontalJitter: -6 ... 6,
            stackSpacing: 18,
            chrome: .utility,
            fontWeight: .semibold,
            fontSize: 15,
            bouncesSymbol: true,
            showsSecondaryCaption: false
        )

        private static let buffChip = CombatFeedbackMotionRecipe(
            feedbackClass: .buff,
            scale: [
                .init(value: 1.06, duration: 0.14),
                .init(value: 1.0, duration: 0.22),
                .init(value: 0.98, duration: 0.42),
            ],
            opacity: [
                .init(value: 1.0, duration: 0.14, usesSpring: false),
                .init(value: 1.0, duration: 0.45, usesSpring: false),
                .init(value: 0.0, duration: 0.24, usesSpring: false),
            ],
            offsetY: [
                .init(value: -6, duration: 0.14),
                .init(value: -24, duration: 0.42),
                .init(value: -32, duration: 0.24),
            ],
            lifetime: 0.9,
            horizontalJitter: -7 ... 7,
            stackSpacing: 18,
            chrome: .standard,
            fontWeight: .medium,
            fontSize: 15,
            bouncesSymbol: false,
            showsSecondaryCaption: false
        )

        private static let resourceChip = CombatFeedbackMotionRecipe(
            feedbackClass: .resource,
            scale: [
                .init(value: 1.06, duration: 0.14),
                .init(value: 1.0, duration: 0.22),
                .init(value: 0.98, duration: 0.42),
            ],
            opacity: [
                .init(value: 1.0, duration: 0.14, usesSpring: false),
                .init(value: 1.0, duration: 0.45, usesSpring: false),
                .init(value: 0.0, duration: 0.24, usesSpring: false),
            ],
            offsetY: [
                .init(value: -6, duration: 0.14),
                .init(value: -24, duration: 0.42),
                .init(value: -32, duration: 0.24),
            ],
            lifetime: 0.9,
            horizontalJitter: -7 ... 7,
            stackSpacing: 18,
            chrome: .standard,
            fontWeight: .semibold,
            fontSize: 15,
            bouncesSymbol: true,
            showsSecondaryCaption: false
        )

        private static let deathsDoorChip = CombatFeedbackMotionRecipe(
            feedbackClass: .deathsDoor,
            scale: [
                .init(value: 1.1, duration: 0.14),
                .init(value: 1.0, duration: 0.24),
                .init(value: 0.98, duration: 0.5),
            ],
            opacity: [
                .init(value: 1.0, duration: 0.14, usesSpring: false),
                .init(value: 1.0, duration: 0.55, usesSpring: false),
                .init(value: 0.0, duration: 0.28, usesSpring: false),
            ],
            offsetY: [
                .init(value: -8, duration: 0.14),
                .init(value: -28, duration: 0.5),
                .init(value: -36, duration: 0.28),
            ],
            lifetime: 1.1,
            horizontalJitter: -5 ... 5,
            stackSpacing: 22,
            chrome: .emphasis,
            fontWeight: .bold,
            fontSize: 17,
            bouncesSymbol: true,
            showsSecondaryCaption: false
        )

        // MARK: - Card reactions

        private static let noneCardReaction = CombatantHitReactionRecipe(
            kind: .none,
            scale: [.init(value: 1.0, duration: 0.01)],
            offsetX: [.init(value: 0, duration: 0.01)],
            flashOpacity: [.init(value: 0, duration: 0.01, usesSpring: false)],
            duration: 0.01
        )

        private static let damageCardReaction = CombatantHitReactionRecipe(
            kind: .damage,
            scale: [
                .init(value: 0.97, duration: 0.08),
                .init(value: 1.0, duration: 0.16),
            ],
            offsetX: [
                .init(value: -4, duration: 0.08),
                .init(value: 0, duration: 0.16),
            ],
            flashOpacity: [
                .init(value: 0.35, duration: 0.06, usesSpring: false),
                .init(value: 0.0, duration: 0.16, usesSpring: false),
            ],
            duration: 0.24
        )

        private static let criticalCardReaction = CombatantHitReactionRecipe(
            kind: .critical,
            scale: [
                .init(value: 0.95, duration: 0.08),
                .init(value: 1.0, duration: 0.18),
            ],
            offsetX: [
                .init(value: -7, duration: 0.08),
                .init(value: 0, duration: 0.18),
            ],
            flashOpacity: [
                .init(value: 0.5, duration: 0.06, usesSpring: false),
                .init(value: 0.0, duration: 0.18, usesSpring: false),
            ],
            duration: 0.26
        )

        private static let healCardReaction = CombatantHitReactionRecipe(
            kind: .heal,
            scale: [
                .init(value: 1.02, duration: 0.1),
                .init(value: 1.0, duration: 0.16),
            ],
            offsetX: [
                .init(value: 0, duration: 0.1),
                .init(value: 0, duration: 0.16),
            ],
            flashOpacity: [
                .init(value: 0.28, duration: 0.08, usesSpring: false),
                .init(value: 0.0, duration: 0.18, usesSpring: false),
            ],
            duration: 0.26
        )

        private static let dodgeCardReaction = CombatantHitReactionRecipe(
            kind: .dodge,
            scale: [
                .init(value: 1.0, duration: 0.08),
                .init(value: 1.0, duration: 0.16),
            ],
            offsetX: [
                .init(value: 6, duration: 0.08),
                .init(value: 0, duration: 0.16),
            ],
            flashOpacity: [
                .init(value: 0.12, duration: 0.06, usesSpring: false),
                .init(value: 0.0, duration: 0.14, usesSpring: false),
            ],
            duration: 0.24
        )
    }
}
