import CoreGraphics
import Foundation
import SwiftUI

/// Floating combat-text motion recipe. Production defaults to `.alchemyPop`;
/// `.idealCore` remains implemented for comparison and revert.
public enum CombatFeedbackFloatRecipe: String, CaseIterable, Sendable, Equatable {
    case idealCore
    case alchemyPop
}

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
        /// Particle activation of a played card.
        public static let cardActivationDuration: TimeInterval = 1.0

        /// Enemy combatant Slice death clip length (cut → split → half dissolve).
        public static let combatantSliceDuration: TimeInterval = 2.5

        /// Phase unit for continuous stun/freeze overlays (progress 1.0 == this many seconds).
        public static let combatantStatusEffectPhaseDuration: TimeInterval = 4.0

        /// Minimum hold after battle outcome so death/cast spectacle can play before Victory/Defeat.
        public static let outcomePresentationMinimum: TimeInterval = 2.0

        /// Breathing room after the last activation or feedback frame before an outcome replaces Battle.
        public static let outcomePresentationPadding: TimeInterval = 0.1

        /// Stagger for a small deal without making the turn feel held up.
        public static let cardDrawStagger: TimeInterval = 0.045

        /// Spring used while a freshly dealt hand settles into its fan.
        public static var deal: Animation {
            .spring(response: 0.3, dampingFraction: 0.94)
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

        /// Production float recipe while Alchemy Pop is under evaluation.
        public static let activeFloatRecipe: CombatFeedbackFloatRecipe = .alchemyPop

        /// Presentation lifetime for the active float recipe.
        public static var chipDisplayDuration: TimeInterval {
            displayDuration(for: activeFloatRecipe)
        }

        /// Ideal Core presentation lifetime (retained recipe).
        public static let idealCoreDisplayDuration: TimeInterval = 1.02

        /// Alchemy Pop presentation lifetime (`pop + hold + rise`).
        public static let alchemyPopDisplayDuration: TimeInterval = 0.9

        /// Rapid FIFO cadence for successive chips in one combatant's vertical stream.
        public static let feedbackStreamStagger: TimeInterval = 0.18

        /// Ideal Core: fraction of lifetime that stays fully opaque before fade begins.
        public static let chipOpaqueHoldFraction: Double = 0.64

        /// Ideal Core: fade length after the opaque hold.
        public static let chipFadeOutDuration: TimeInterval = 0.30

        /// Maximum rise as a fraction of the corresponding combatant card height.
        public static let chipTravelFraction: CGFloat = 0.44

        /// Minimum clearance between the final label bounds and the card's top edge.
        public static let chipTopClearance: CGFloat = 8

        /// Spawn scale for the Ideal Core float punch.
        public static let chipStartScale: CGFloat = 1.06

        /// Peak scale shortly after spawn (Ideal Core).
        public static let chipPeakScale: CGFloat = 1.10

        /// End scale as the chip settles while rising (Ideal Core).
        public static let chipEndScale: CGFloat = 0.96

        /// Progress (0...1) at which Ideal Core scale reaches `chipPeakScale`.
        public static let chipPeakProgress: Double = 0.10

        // MARK: Alchemy Pop envelope (ported from Alchemy combat-text.tsx)

        public static let alchemyPopStartScale: CGFloat = 0.5
        public static let alchemyPopOvershootScale: CGFloat = 2.0
        public static let alchemyPopHoldScale: CGFloat = 1.8
        public static let alchemyPopEndScale: CGFloat = 1.0
        public static let alchemyPopDuration: TimeInterval = 0.2
        public static let alchemyPopHoldDuration: TimeInterval = 0.2
        public static let alchemyPopShrinkDuration: TimeInterval = 0.5
        public static let alchemyPopRiseDuration: TimeInterval = 0.5
        public static let alchemyPopFadeDuration: TimeInterval = 0.4

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

        public static func displayDuration(for recipe: CombatFeedbackFloatRecipe) -> TimeInterval {
            switch recipe {
            case .idealCore: idealCoreDisplayDuration
            case .alchemyPop: alchemyPopDisplayDuration
            }
        }

        /// Rise progress 0...1 for the given recipe (default: active production recipe).
        public static func chipMotionProgress(
            elapsed: TimeInterval,
            recipe: CombatFeedbackFloatRecipe = activeFloatRecipe
        ) -> Double {
            switch recipe {
            case .idealCore:
                idealCoreMotionProgress(elapsed: elapsed)
            case .alchemyPop:
                alchemyPopMotionProgress(elapsed: elapsed)
            }
        }

        /// Scale envelope for the given recipe (default: active production recipe).
        public static func chipScale(
            elapsed: TimeInterval,
            recipe: CombatFeedbackFloatRecipe = activeFloatRecipe
        ) -> CGFloat {
            switch recipe {
            case .idealCore:
                idealCoreScale(elapsed: elapsed)
            case .alchemyPop:
                alchemyPopScale(elapsed: elapsed)
            }
        }

        public static func chipOpacity(
            elapsed: TimeInterval,
            recipe: CombatFeedbackFloatRecipe = activeFloatRecipe
        ) -> Double {
            switch recipe {
            case .idealCore:
                idealCoreOpacity(elapsed: elapsed)
            case .alchemyPop:
                alchemyPopOpacity(elapsed: elapsed)
            }
        }

        public static func chipTravelDistance(cardHeight: CGFloat, chipHeight: CGFloat) -> CGFloat {
            let proportionalTravel = cardHeight * chipTravelFraction
            let topSafeTravel = cardHeight / 2 - chipHeight / 2 - chipTopClearance
            return max(0, min(proportionalTravel, topSafeTravel))
        }

        // MARK: Ideal Core sampling

        /// Quadratic ease-out: energetic start that decelerates through the rise.
        private static func idealCoreMotionProgress(elapsed: TimeInterval) -> Double {
            let progress = min(max(elapsed / idealCoreDisplayDuration, 0), 1)
            let inverse = 1 - progress
            return 1 - inverse * inverse
        }

        /// Soft punch to peak, then settle while rising.
        private static func idealCoreScale(elapsed: TimeInterval) -> CGFloat {
            let t = min(max(elapsed / idealCoreDisplayDuration, 0), 1)
            let peakAt = min(max(chipPeakProgress, 0.001), 0.999)
            if t <= peakAt {
                let u = t / peakAt
                return chipStartScale + (chipPeakScale - chipStartScale) * CGFloat(u)
            }
            let u = (t - peakAt) / (1 - peakAt)
            return chipPeakScale + (chipEndScale - chipPeakScale) * CGFloat(u)
        }

        private static func idealCoreOpacity(elapsed: TimeInterval) -> Double {
            let holdEnd = min(
                idealCoreDisplayDuration * chipOpaqueHoldFraction,
                idealCoreDisplayDuration - 0.001
            )
            guard elapsed > holdEnd else { return 1 }
            let fadeLen = max(
                min(chipFadeOutDuration, idealCoreDisplayDuration - holdEnd),
                0.001
            )
            return min(max((holdEnd + fadeLen - elapsed) / fadeLen, 0), 1)
        }

        // MARK: Alchemy Pop sampling

        private static var alchemyPopPeakTime: TimeInterval {
            alchemyPopDuration * 0.75
        }

        private static var alchemyPopEndTime: TimeInterval {
            alchemyPopDuration
        }

        private static var alchemyHoldEndTime: TimeInterval {
            alchemyPopEndTime + alchemyPopHoldDuration
        }

        private static var alchemyFadeStartTime: TimeInterval {
            max(alchemyHoldEndTime, alchemyPopDisplayDuration - alchemyPopFadeDuration)
        }

        /// Parked until hold ends, then cubic ease-in rise.
        private static func alchemyPopMotionProgress(elapsed: TimeInterval) -> Double {
            guard elapsed > alchemyHoldEndTime else { return 0 }
            let riseProg = (elapsed - alchemyHoldEndTime) / alchemyPopRiseDuration
            let clamped = min(max(riseProg, 0), 1)
            return clamped * clamped * clamped
        }

        /// Pop overshoot → hold → shrink to 1.0 during rise.
        private static func alchemyPopScale(elapsed: TimeInterval) -> CGFloat {
            let t = elapsed
            if t <= 0 {
                return alchemyPopStartScale
            }
            if t <= alchemyPopPeakTime {
                let u = t / alchemyPopPeakTime
                return lerp(alchemyPopStartScale, alchemyPopOvershootScale, u)
            }
            if t <= alchemyPopEndTime {
                let u = (t - alchemyPopPeakTime) / (alchemyPopEndTime - alchemyPopPeakTime)
                return lerp(alchemyPopOvershootScale, alchemyPopHoldScale, u)
            }
            if t <= alchemyHoldEndTime {
                return alchemyPopHoldScale
            }
            let shrinkProg = min(1, (t - alchemyHoldEndTime) / alchemyPopShrinkDuration)
            return lerp(alchemyPopHoldScale, alchemyPopEndScale, shrinkProg)
        }

        private static func alchemyPopOpacity(elapsed: TimeInterval) -> Double {
            if elapsed <= alchemyFadeStartTime {
                return 1
            }
            if elapsed >= alchemyPopDisplayDuration {
                return 0
            }
            let fadeProg = (elapsed - alchemyFadeStartTime)
                / (alchemyPopDisplayDuration - alchemyFadeStartTime)
            return lerp(1, 0, fadeProg)
        }

        private static func lerp(_ start: CGFloat, _ end: CGFloat, _ progress: Double) -> CGFloat {
            let p = min(max(progress, 0), 1)
            return start + (end - start) * CGFloat(p)
        }

        private static func lerp(_ start: Double, _ end: Double, _ progress: Double) -> Double {
            let p = min(max(progress, 0), 1)
            return start + (end - start) * p
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
