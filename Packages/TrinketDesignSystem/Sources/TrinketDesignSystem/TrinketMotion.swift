import CoreGraphics
import Foundation
import SwiftUI

/// Shared motion presets. Battle spectacle (R-008 / R-011) is the first consumer;
/// combat feedback chips extend the same vocabulary (R-001 / R-006).
public enum TrinketMotion: Sendable {
    public enum Reward: Sendable {
        public static let resourceStagger: TimeInterval = 0.12
        public static let itemRevealDelay: TimeInterval = 0.18
        public static let completionDelay: TimeInterval = 0.3

        public static var stateChange: Animation {
            .spring(response: 0.38, dampingFraction: 1.0)
        }

        public static var reveal: Animation {
            .spring(response: 0.45, dampingFraction: 0.88)
        }
    }

    public enum Journey: Sendable {
        /// Immediate, critically damped feedback for the active stage row.
        public static var rowPress: Animation {
            .spring(response: 0.2, dampingFraction: 1.0)
        }

        /// Spatially continuous expansion and collapse for the active stage detail.
        public static var stageExpansion: Animation {
            .spring(response: 0.38, dampingFraction: 1.0)
        }
    }

    public enum Homestead: Sendable {
        /// Completion emphasis for a tier node after a successful build or upgrade.
        public static var tierCompletion: Animation {
            .spring(response: 0.35, dampingFraction: 1.0)
        }

        /// Restrained squash-and-bounce cue for an affordable build or upgrade action.
        public static let purchaseCueSpeed: Double = 0.45
    }

    public enum Battle: Sendable {
        /// Immediate press response before a drag direction is established.
        public static var cardPress: Animation {
            .spring(response: 0.16, dampingFraction: 1.0)
        }

        /// Semantic pickup response for a card leaving the hand.
        ///
        /// Keep this separate from `cardPress` so card-play callers can describe
        /// intent without coupling to the current drag implementation.
        public static var pickup: Animation {
            .spring(response: 0.2, dampingFraction: 1.0)
        }

        /// Semantic readiness response when a card or pane becomes a valid target.
        public static var readiness: Animation {
            .spring(response: 0.24, dampingFraction: 0.94)
        }

        /// Restrained, interruptible motion for directly manipulated ability cards.
        public static var cardLift: Animation {
            .spring(response: 0.2, dampingFraction: 1.0)
        }

        /// Short, purposeful flight from the hand into the battlefield.
        public static var cardCommit: Animation {
            .spring(response: 0.28, dampingFraction: 0.92)
        }

        /// Purposeful cast travel from the hand toward the battlefield.
        public static var cast: Animation {
            cardCommit
        }

        /// Tight, slightly bouncy landing response when a cast resolves.
        public static var impact: Animation {
            .spring(response: 0.18, dampingFraction: 0.82)
        }

        /// Slight overshoot is reserved for returning an object after a drag.
        public static var cardReturn: Animation {
            .spring(response: 0.38, dampingFraction: 0.82)
        }

        /// Name for a return animation when the caller is not modeling a card.
        public static var returning: Animation {
            cardReturn
        }

        /// Time reserved for the card's activation travel before the engine commit.
        public static let cardCommitDelay: TimeInterval = 0.11

        /// Particle activation of a played card.
        public static let cardActivationDuration: TimeInterval = 1.0

        /// Breathing room after the last activation or feedback frame before an outcome replaces Battle.
        public static let outcomePresentationPadding: TimeInterval = 0.1

        /// Stagger for a small deal without making the turn feel held up.
        public static let cardDrawStagger: TimeInterval = 0.045

        /// Short, low-distraction delay between cards entering the hand.
        public static let dealStagger: TimeInterval = cardDrawStagger

        /// Spring used while a freshly dealt hand settles into its fan.
        public static var deal: Animation {
            .spring(response: 0.3, dampingFraction: 0.94)
        }

        /// Spring used when the hand reflows around a draw or played card.
        public static var handReflow: Animation {
            .spring(response: 0.34, dampingFraction: 0.92)
        }

        /// Semantic alias for layout movement after a cast or deal.
        public static var reflow: Animation {
            handReflow
        }

        /// Explicit card-named alias for `pickup`.
        public static var cardPickup: Animation {
            pickup
        }

        /// Explicit card-named alias for `readiness`.
        public static var cardReadiness: Animation {
            readiness
        }

        /// Explicit card-named alias for `cast`.
        public static var cardCast: Animation {
            cast
        }

        /// Explicit card-named alias for `impact`.
        public static var cardImpact: Animation {
            impact
        }

        /// Explicit card-named alias for `deal`.
        public static var cardDeal: Animation {
            deal
        }

        public static let cardHeldScale = 1.035
        /// Softer than a deep drop shadow so held-card drag stays compositor-cheap.
        public static let cardHeldShadowRadius: CGFloat = 6
        public static let cardHeldShadowY: CGFloat = 16
        public static let cardMaximumTiltDegrees = 20.0
        public static let cardMaximumStretch = 0.025

        /// Soft-hold after a Skill cast so caster art is readable.
        public static let skillSoftHold: TimeInterval = 0.5

        /// Typical Ultimate art-fallback hold when no video is present.
        public static let ultimateFallbackHold: TimeInterval = 4.0

        /// Hard ceiling for video Ultimate cinematics when end/failure notifications never fire.
        public static let ultimateVideoWatchdog: TimeInterval = 12.0

        /// Delay before tap-to-skip is armed on an Ultimate cinematic.
        public static let ultimateSkipLockout: TimeInterval = 0.45

        public static let skillCalloutIn: TimeInterval = 0.12
        public static let skillCalloutHold: TimeInterval = 0.25
        public static let skillCalloutOut: TimeInterval = 0.18

        public static var skillCalloutTotal: TimeInterval {
            skillCalloutIn + skillCalloutHold + skillCalloutOut
        }

        public static let scrimFade: TimeInterval = 0.2
        public static let ultimateCollapse: TimeInterval = 0.28

        /// Fixed delay between visual starts in one combatant's feedback queue.
        public static let feedbackQueueStagger: TimeInterval = 0.1

        /// Every floating combat label uses the same presentation lifetime.
        public static let chipDisplayDuration: TimeInterval = 1.0

        /// Labels stay fully opaque until this final portion of their lifetime.
        public static let chipFadeOutDuration: TimeInterval = 0.2

        /// Maximum rise as a fraction of the corresponding combatant card height.
        public static let chipTravelFraction: CGFloat = 0.42

        /// Minimum clearance between the final label bounds and the card's top edge.
        public static let chipTopClearance: CGFloat = 8

        /// Lifetime buffer for delayed raw-event cleanup.
        public static var maxChipLifetime: TimeInterval {
            chipDisplayDuration + 0.05
        }

        /// Max concurrent keyword particle bursts per combatant pane.
        public static let maxKeywordBurstsPerPane = 1

        /// Max simultaneous card cast dissolve overlays on the battlefield.
        public static let maxConcurrentCardCasts = 1

        /// Default particle count for a played-card activation burst.
        public static let cardCastParticleCount = 8

        public static var ultimateExpand: Animation {
            .spring(response: 0.42, dampingFraction: 0.9)
        }

        public static var ultimateCollapseAnimation: Animation {
            .spring(response: 0.32, dampingFraction: 0.92)
        }

        public static var scrim: Animation {
            .easeOut(duration: scrimFade)
        }

        public static func chip(for feedbackClass: CombatFeedbackClass) -> CombatFeedbackChipStyle {
            CombatFeedbackChipRecipes.chip(for: feedbackClass)
        }

        /// Quadratic ease-out: full initial velocity that decelerates smoothly to rest.
        public static func chipMotionProgress(elapsed: TimeInterval) -> Double {
            let progress = min(max(elapsed / chipDisplayDuration, 0), 1)
            return 1 - pow(1 - progress, 2)
        }

        public static func chipOpacity(elapsed: TimeInterval) -> Double {
            let fadeStart = chipDisplayDuration - chipFadeOutDuration
            guard elapsed > fadeStart else { return 1 }
            return min(max((chipDisplayDuration - elapsed) / chipFadeOutDuration, 0), 1)
        }

        public static func chipTravelDistance(cardHeight: CGFloat, chipHeight: CGFloat) -> CGFloat {
            let proportionalTravel = cardHeight * chipTravelFraction
            let topSafeTravel = cardHeight / 2 - chipHeight / 2 - chipTopClearance
            return max(0, min(proportionalTravel, topSafeTravel))
        }

        public static func cardReaction(for kind: CombatantHitReactionKind) -> CombatantHitReactionRecipe {
            CombatFeedbackCardRecipes.cardReaction(for: kind)
        }

        public static func cardAttack(for kind: CombatantAttackReactionKind) -> CombatantAttackReactionRecipe {
            CombatFeedbackAttackRecipes.cardAttack(for: kind)
        }

        /// Party lunges toward the enemy; enemies lunge toward the party.
        public static func attackAim(isPartyMember: Bool) -> CombatantAttackAim {
            CombatantAttackAim.aim(isPartyMember: isPartyMember)
        }

        /// Party combatants recoil toward the hand; enemies recoil upward.
        public static func partyRecoilDirection(isPartyMember: Bool) -> CombatantHitRecoilDirection {
            isPartyMember ? .down : .up
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
    }
}
