import CoreGraphics
import Foundation
import SwiftUI

/// Shared motion presets. Battle spectacle (R-008 / R-011) is the first consumer;
/// combat feedback chips extend the same vocabulary (R-001 / R-006).
public enum TrinketMotion: Sendable {
    /// Restrained feedback for ordinary controls and committed state changes.
    public enum Interaction: Sendable {
        public static let artworkCardPressedScale: CGFloat = 0.99
        public static let selectionCardPressedScale: CGFloat = 0.995
        public static let walletIncreaseScale: CGFloat = 1.025
        public static let walletIncreaseDelayStep: TimeInterval = 0.055
        public static let walletIncreaseMaximumDelay: TimeInterval = 0.30
        public static let manaSpendDuration: TimeInterval = 0.16
        public static let manaRestoreDuration: TimeInterval = 0.22

        public static var press: Animation {
            .spring(response: 0.18, dampingFraction: 1)
        }

        public static var selection: Animation {
            .spring(response: 0.22, dampingFraction: 1)
        }

        public static var stateChange: Animation {
            .easeOut(duration: 0.18)
        }

        public static var progressArrival: Animation {
            .spring(response: 0.28, dampingFraction: 1)
        }
    }

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

    /// Traveling keyword-affinity text gradient.
    public enum Shine: Sendable {
        /// One full loop of the keyword shine gradient.
        public static let keywordAffinityPeriod: TimeInterval = 4.8
    }

    /// Mystery recruit unveil and seal. Keep `Reward` snappy for loot.
    public enum Mystery: Sendable {
        public static let veilHold: TimeInterval = 0.35
        public static let unmaskResponse: TimeInterval = 0.48
        public static let chromeAfterUnmask: TimeInterval = 0.12
        public static let chromeStagger: TimeInterval = 0.10
        public static let recruitButtonDelay: TimeInterval = 0.16
        public static let sealResponse: TimeInterval = 0.32
        public static let sealHoldBeforeDismiss: TimeInterval = 0.22
        public static let sealArtPeakDelay: TimeInterval = 0.12
        public static let bloomPeakOpacity: Double = 0.40
        public static let bloomPeakFraction: Double = 0.40
        public static let veiledBrightness: Double = -0.18
        public static let veiledOverlayOpacity: Double = 0.55
        public static let veiledArtScale: CGFloat = 0.97
        public static let sealBadgeStartScale: CGFloat = 0.78
        public static let sealArtPeakScale: CGFloat = 1.04

        public static var unmask: Animation {
            .spring(response: unmaskResponse, dampingFraction: 0.92)
        }

        public static var chrome: Animation {
            .spring(response: 0.36, dampingFraction: 0.95)
        }

        public static var seal: Animation {
            .spring(response: sealResponse, dampingFraction: 0.82)
        }

        public static var bloomIn: Animation {
            .easeOut(duration: unmaskResponse * bloomPeakFraction)
        }

        public static var bloomOut: Animation {
            .easeOut(duration: unmaskResponse * (1 - bloomPeakFraction))
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

        /// Top-down fill of one incoming connector segment into a newly completed node.
        public static let connectorFillDuration: TimeInterval = 0.20

        /// Gap between the upper and lower halves of the incoming stroke.
        public static let connectorFillStagger: TimeInterval = 0.08

        public static var connectorFill: Animation {
            .easeOut(duration: connectorFillDuration)
        }

        /// Wait after fill starts before the node settles. Matches `connectorFillDuration`.
        public static var nodeSettleDelay: TimeInterval {
            connectorFillDuration
        }

        public static let nodeSettleResponse: TimeInterval = 0.32

        public static var nodeSettle: Animation {
            .spring(response: nodeSettleResponse, dampingFraction: 0.85)
        }

        public static let nodeSettlePeakScale: CGFloat = 1.06
    }

    public enum Battle: Sendable {
        /// Particle activation of a played card.
        public static let cardActivationDuration: TimeInterval = 1.0

        /// Extra hold after the cast animation before a stuck overlay request is cleared.
        public static let cardActivationStuckSlack: TimeInterval = 0.35

        /// Enemy combatant Slice death clip length (cut → split → half dissolve).
        public static let combatantSliceDuration: TimeInterval = 1.25

        /// Phase unit for continuous stun/freeze overlays (progress 1.0 == this many seconds).
        public static let combatantStatusEffectPhaseDuration: TimeInterval = 4.0

        /// Freeze frost finishes encroaching at this fraction of the status phase.
        public static let combatantFreezeEncroachProgress: Double = 0.35

        /// Timeline duration until freeze overlay can pause on a static saturated veil.
        public static var combatantFreezeEncroachDuration: TimeInterval {
            combatantStatusEffectPhaseDuration * combatantFreezeEncroachProgress
        }

        /// Minimum hold after battle outcome so death/cast spectacle can play before Victory/Defeat.
        public static let outcomePresentationMinimum: TimeInterval = 1.25

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

        /// Hard ceiling for video Ultimate cinematics when end/failure notifications never fire.
        public static let ultimateVideoWatchdog: TimeInterval = 12.0

        /// Session-level ceiling if the Ultimate overlay never finishes (ready wait + video watchdog).
        public static let ultimateCinematicSessionWatchdog: TimeInterval = 20.0

        public static let scrimFade: TimeInterval = 0.2

        /// Diagonal split open for Ultimate cinematic cover panels.
        public static let ultimateSplitOpen: TimeInterval = 0.5

        /// Diagonal split close for Ultimate cinematic cover panels.
        public static let ultimateSplitClose: TimeInterval = 0.38

        /// Code-only playback multiplier for the whole Ultimate cinematic (video
        /// rate + open/close cover durations). Not exposed in the UI; tweak here.
        public static let ultimateCinematicPlaybackSpeed: Double = 1.2

        /// Open/close durations scaled by `ultimateCinematicPlaybackSpeed`.
        public static var ultimateSplitOpenAtPlayback: TimeInterval {
            ultimateSplitOpen / ultimateCinematicPlaybackSpeed
        }

        public static var ultimateSplitCloseAtPlayback: TimeInterval {
            ultimateSplitClose / ultimateCinematicPlaybackSpeed
        }

        public static var ultimateSplitOpenPlaybackAnimation: Animation {
            .easeInOut(duration: ultimateSplitOpenAtPlayback)
        }

        public static var ultimateSplitClosePlaybackAnimation: Animation {
            .easeInOut(duration: ultimateSplitCloseAtPlayback)
        }

        /// Presentation lifetime for the Alchemy Pop float recipe.
        public static let chipDisplayDuration: TimeInterval = alchemyPopDisplayDuration

        /// Alchemy Pop presentation lifetime (`pop + hold + rise`).
        public static let alchemyPopDisplayDuration: TimeInterval = 0.63

        /// Rapid FIFO cadence for successive chips in one combatant's vertical stream.
        public static let feedbackStreamStagger: TimeInterval = 0.126

        /// Maximum rise as a fraction of the corresponding combatant card height.
        public static let chipTravelFraction: CGFloat = 0.44

        /// Minimum clearance between the final label bounds and the card's top edge.
        public static let chipTopClearance: CGFloat = 8

        // MARK: Alchemy Pop envelope (ported from Alchemy combat-text.tsx)

        public static let alchemyPopStartScale: CGFloat = 0.5
        public static let alchemyPopOvershootScale: CGFloat = 2.0
        public static let alchemyPopHoldScale: CGFloat = 1.8
        public static let alchemyPopEndScale: CGFloat = 1.0
        public static let alchemyPopDuration: TimeInterval = 0.14
        public static let alchemyPopHoldDuration: TimeInterval = 0.14
        public static let alchemyPopShrinkDuration: TimeInterval = 0.35
        public static let alchemyPopRiseDuration: TimeInterval = 0.35
        public static let alchemyPopFadeDuration: TimeInterval = 0.28

        /// Maximum continuous accumulation lifetime for an active floating chip.
        public static let maxContinuousChipLifetime: TimeInterval = 1.2

        /// Lifetime buffer for delayed raw-event cleanup.
        public static var maxChipLifetime: TimeInterval {
            chipDisplayDuration + 0.05
        }

        /// Max simultaneous card cast dissolve overlays on the battlefield.
        public static let maxConcurrentCardCasts = 1

        /// Default particle count for a played-card activation burst.
        public static let cardCastParticleCount = 8

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

        /// One full lap of a traveling buff-aura border shimmer (Shadowstep, etc.).
        public static let buffAuraShimmerPeriod: TimeInterval = 1.6

        /// Parked until hold ends, then cubic ease-in rise.
        public static func chipMotionProgress(elapsed: TimeInterval) -> Double {
            guard elapsed > alchemyHoldEndTime else { return 0 }
            let riseProg = (elapsed - alchemyHoldEndTime) / alchemyPopRiseDuration
            let clamped = min(max(riseProg, 0), 1)
            return clamped * clamped * clamped
        }

        /// Scale envelope for the Alchemy Pop float recipe. Pop overshoot -> hold -> shrink to 1.0 during rise.
        public static func chipScale(elapsed: TimeInterval) -> CGFloat {
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

        public static func chipOpacity(elapsed: TimeInterval) -> Double {
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

        public static func chipTravelDistance(cardHeight: CGFloat, chipHeight: CGFloat) -> CGFloat {
            let proportionalTravel = cardHeight * chipTravelFraction
            let topSafeTravel = cardHeight / 2 - chipHeight / 2 - chipTopClearance
            return max(0, min(proportionalTravel, topSafeTravel))
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

        private static func lerp(_ start: CGFloat, _ end: CGFloat, _ progress: Double) -> CGFloat {
            let p = min(max(progress, 0), 1)
            return start + (end - start) * CGFloat(p)
        }

        private static func lerp(_ start: Double, _ end: Double, _ progress: Double) -> Double {
            let p = min(max(progress, 0), 1)
            return start + (end - start) * p
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
