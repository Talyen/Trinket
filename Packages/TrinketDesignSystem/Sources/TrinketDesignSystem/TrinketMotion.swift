import CoreGraphics
import Foundation
import SwiftUI

/// Shared motion presets. Battle spectacle (R-008 / R-011) is the first consumer;
/// combat feedback chips extend the same vocabulary (R-001 / R-006).
public enum TrinketMotion: Sendable {
    public enum Reward: Sendable {
        public static let resourceStagger: TimeInterval = 0.06
        public static let itemRevealDelay: TimeInterval = 0.08
        public static let completionDelay: TimeInterval = 0.10

        public static var stateChange: Animation {
            .spring(response: 0.22, dampingFraction: 1.0)
        }

        public static var reveal: Animation {
            .spring(response: 0.28, dampingFraction: 0.88)
        }
    }

    /// Shared fades and staged entrances for ordinary screen content.
    public enum Content: Sendable {
        public static let fadeDuration: TimeInterval = 0.20
        public static let entranceDuration: TimeInterval = 0.35
        public static let entranceStagger: TimeInterval = 0.08
        public static let secondEntranceDelay: TimeInterval = 0.16

        public static var fade: Animation {
            .easeOut(duration: fadeDuration)
        }

        public static var entrance: Animation {
            .easeOut(duration: entranceDuration)
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

        /// Particle activation of a played card.
        public static let cardActivationDuration: TimeInterval = 1.0

        /// Breathing room after the last activation or feedback frame before an outcome replaces Battle.
        public static let outcomePresentationPadding: TimeInterval = 0.1

        /// Stagger for a small deal without making the turn feel held up.
        public static let cardDrawStagger: TimeInterval = 0.045

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

        /// Explicit card-named alias for `cast`.
        public static var cardCast: Animation {
            cast
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

        public static let skillCalloutIn: TimeInterval = 0.12
        public static let skillCalloutHold: TimeInterval = 0.25
        public static let skillCalloutOut: TimeInterval = 0.18

        public static var skillCalloutTotal: TimeInterval {
            skillCalloutIn + skillCalloutHold + skillCalloutOut
        }

        public static let scrimFade: TimeInterval = 0.2
        public static let ultimateCollapse: TimeInterval = 0.28

        /// Every floating combat label uses the same presentation lifetime.
        public static let chipDisplayDuration: TimeInterval = 1.02

        /// Rapid FIFO cadence for successive chips in one combatant's vertical stream.
        public static let feedbackStreamStagger: TimeInterval = 0.18

        /// Fraction of lifetime that stays fully opaque before fade begins.
        public static let chipOpaqueHoldFraction: Double = 0.64

        /// Fade length after the opaque hold (may finish slightly before lifetime end).
        public static let chipFadeOutDuration: TimeInterval = 0.30

        /// Maximum rise as a fraction of the corresponding combatant card height.
        public static let chipTravelFraction: CGFloat = 0.44

        /// Minimum clearance between the final label bounds and the card's top edge.
        public static let chipTopClearance: CGFloat = 8

        /// Spawn scale for the Ideal Core float punch.
        public static let chipStartScale: CGFloat = 1.06

        /// Peak scale shortly after spawn.
        public static let chipPeakScale: CGFloat = 1.10

        /// End scale as the chip settles while rising.
        public static let chipEndScale: CGFloat = 0.96

        /// Progress (0...1) at which scale reaches `chipPeakScale`.
        public static let chipPeakProgress: Double = 0.10

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

        /// Gentle opacity cycle for a combatant card status border accent.
        public static let statusBorderPulseDuration: TimeInterval = 0.9

        public static var statusBorderPulse: Animation {
            .easeInOut(duration: statusBorderPulseDuration)
        }

        /// Dim end of the status border pulse (full keyword color is `1`).
        public static let statusBorderPulseDimOpacity = 0.45

        /// Quadratic ease-out: energetic start that decelerates through the rise.
        public static func chipMotionProgress(elapsed: TimeInterval) -> Double {
            let progress = min(max(elapsed / chipDisplayDuration, 0), 1)
            let inverse = 1 - progress
            return 1 - inverse * inverse
        }

        /// Scale envelope: soft punch to peak, then settle while rising.
        public static func chipScale(elapsed: TimeInterval) -> CGFloat {
            let t = min(max(elapsed / chipDisplayDuration, 0), 1)
            let peakAt = min(max(chipPeakProgress, 0.001), 0.999)
            if t <= peakAt {
                let u = t / peakAt
                return chipStartScale + (chipPeakScale - chipStartScale) * CGFloat(u)
            }
            let u = (t - peakAt) / (1 - peakAt)
            return chipPeakScale + (chipEndScale - chipPeakScale) * CGFloat(u)
        }

        public static func chipOpacity(elapsed: TimeInterval) -> Double {
            let holdEnd = min(
                chipDisplayDuration * chipOpaqueHoldFraction,
                chipDisplayDuration - 0.001
            )
            guard elapsed > holdEnd else { return 1 }
            let fadeLen = max(min(chipFadeOutDuration, chipDisplayDuration - holdEnd), 0.001)
            return min(max((holdEnd + fadeLen - elapsed) / fadeLen, 0), 1)
        }

        public static func chipTravelDistance(cardHeight: CGFloat, chipHeight: CGFloat) -> CGFloat {
            let proportionalTravel = cardHeight * chipTravelFraction
            let topSafeTravel = cardHeight / 2 - chipHeight / 2 - chipTopClearance
            return max(0, min(proportionalTravel, topSafeTravel))
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
        public static var selection: Animation {
            .spring(response: 0.22, dampingFraction: 1)
        }

        public static var inspector: Animation {
            .spring(response: 0.32, dampingFraction: 0.9)
        }

        public static var floorChange: Animation {
            .spring(response: 0.38, dampingFraction: 1)
        }
    }

    /// Short opacity crossfades for full-screen content swaps (battle shell, outcomes).
    public enum Screen: Sendable {
        public static let crossfadeDuration: TimeInterval = 0.20

        public static var crossfade: Animation {
            .easeOut(duration: crossfadeDuration)
        }
    }
}
