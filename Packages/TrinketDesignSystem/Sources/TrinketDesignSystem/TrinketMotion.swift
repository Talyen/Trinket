import CoreGraphics
import Foundation
import SwiftUI

/// Shared motion presets. Battle spectacle (R-008 / R-011) is the first consumer;
/// combat feedback chips extend the same vocabulary (R-001 / R-006).
public enum TrinketMotion: Sendable {
    public enum Journey: Sendable {
        public static let reduceMotionFade: TimeInterval = 0.18

        /// Immediate, critically damped feedback for the active stage row.
        public static var rowPress: Animation {
            .spring(response: 0.2, dampingFraction: 1.0)
        }

        /// Spatially continuous expansion and collapse for the active stage detail.
        public static var stageExpansion: Animation {
            .spring(response: 0.38, dampingFraction: 1.0)
        }

        public static var reduceMotion: Animation {
            .easeOut(duration: reduceMotionFade)
        }
    }

    public enum Homestead: Sendable {
        public static let reduceMotionFade: TimeInterval = 0.18

        /// Press feedback for dense navigation rows: fast, critically damped, and interruptible.
        public static var rowPress: Animation {
            .spring(response: 0.2, dampingFraction: 1.0)
        }

        /// Completion emphasis for a tier node after a successful build or upgrade.
        public static var tierCompletion: Animation {
            .spring(response: 0.35, dampingFraction: 1.0)
        }

        /// Restrained squash-and-bounce cue for an affordable build or upgrade action.
        public static let purchaseCueSpeed: Double = 0.45

        public static var reduceMotion: Animation {
            .easeOut(duration: reduceMotionFade)
        }
    }

    public enum Battle: Sendable {
        /// Immediate press response before a drag direction is established.
        public static var cardPress: Animation {
            .spring(response: 0.16, dampingFraction: 1.0)
        }

        /// Restrained, interruptible motion for directly manipulated ability cards.
        public static var cardLift: Animation {
            .spring(response: 0.2, dampingFraction: 1.0)
        }

        /// Short, purposeful flight from the hand into the battlefield.
        public static var cardCommit: Animation {
            .spring(response: 0.28, dampingFraction: 0.92)
        }

        /// Slight overshoot is reserved for returning an object after a drag.
        public static var cardReturn: Animation {
            .spring(response: 0.38, dampingFraction: 0.82)
        }

        public static var cardReturnReducedMotion: Animation {
            .spring(response: 0.22, dampingFraction: 1.0)
        }

        /// Time reserved for the card's activation travel before the engine commit.
        public static let cardCommitDelay: TimeInterval = 0.11

        /// Stagger for a small deal without making the turn feel held up.
        public static let cardDrawStagger: TimeInterval = 0.045

        /// Spring used when the hand reflows around a draw or played card.
        public static var handReflow: Animation {
            .spring(response: 0.34, dampingFraction: 0.92)
        }

        public static let cardHeldScale = 1.035
        public static let cardHeldShadowRadius: CGFloat = 18
        public static let cardHeldShadowY: CGFloat = 10
        public static let cardMaximumTiltDegrees = 7.0
        public static let cardMaximumStretch = 0.025

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

        /// Small stagger that lets compound results read as a sequence.
        public static let feedbackStagger: TimeInterval = 0.035

        /// Default chip display duration (direct damage). Prefer per-class recipes.
        public static let chipDisplayDuration: TimeInterval = 0.7

        /// Longest chip lifetime (+ buffer) for delayed memory prune after recording.
        public static var maxChipLifetime: TimeInterval {
            chip(for: .critical).lifetime + 0.05
        }

        public static let reduceMotionChipFadeIn: TimeInterval = 0.12
        public static let reduceMotionChipHold: TimeInterval = 0.4
        public static let reduceMotionChipFadeOut: TimeInterval = 0.12

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
            CombatFeedbackChipRecipes.chip(for: feedbackClass)
        }

        public static func cardReaction(for kind: CombatantHitReactionKind) -> CombatantHitReactionRecipe {
            CombatFeedbackCardRecipes.cardReaction(for: kind)
        }
    }

    /// The Labyrinth map motion (R-022c).
    public enum Labyrinth: Sendable {
        public static let modifierStagger: TimeInterval = 0.05

        public static var clusterReveal: Animation {
            .easeOut(duration: 0.28)
        }

        public static var modifierIn: Animation {
            .easeOut(duration: 0.22)
        }

        public static var reduceMotion: Animation {
            .easeOut(duration: 0.15)
        }
    }
}
