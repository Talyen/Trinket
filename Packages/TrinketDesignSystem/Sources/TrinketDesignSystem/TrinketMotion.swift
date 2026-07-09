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
            CombatFeedbackRecipes.chip(for: feedbackClass)
        }

        public static func cardReaction(for kind: CombatantHitReactionKind) -> CombatantHitReactionRecipe {
            CombatFeedbackRecipes.cardReaction(for: kind)
        }
    }

    /// Wanderer's Labyrinth map motion (R-022c).
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
