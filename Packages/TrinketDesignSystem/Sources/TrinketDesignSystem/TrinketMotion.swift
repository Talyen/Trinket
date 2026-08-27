import CoreGraphics
import Foundation
import SwiftUI

/// Shared motion presets. Prefer feature-owned motion where only one feature
/// consumes the token; this enum keeps only tokens shared across features
/// (`Interaction`, `Content`, `Screen`, `Shine`, `Reward`). `Battle`,
/// `Homestead`, `Mystery`, `Onboarding`, and `Labyrinth` remain here as the
/// canonical owners until their consuming features extract them.
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

    /// Traveling keyword-affinity shine.
    public enum Shine: Sendable {
        /// One full loop shared by text and border shine.
        public static let loopPeriod: TimeInterval = 4.8
        /// Loop period for fast text gradient sweeps.
        public static let textShineDuration: TimeInterval = 2.4

        public static var textAnimation: Animation {
            .linear(duration: textShineDuration).repeatForever(autoreverses: false)
        }

        /// Normalized position within the shared loop for a nonnegative clock value.
        @inlinable
        public static func phase(at elapsed: TimeInterval) -> Double {
            elapsed.truncatingRemainder(dividingBy: loopPeriod) / loopPeriod
        }
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

    /// Starter picker wheel: first-launch hero/companion onboarding roll.
    /// Card emphasis at the carousel edges is local to the screen's layout.
    public enum Onboarding: Sendable {
        /// Quiet beat before the roll so the resting strip registers first.
        public static let rollStartDelay: TimeInterval = 0.45
        /// Full programmatic roll duration; the long ease-out tail is the suspense.
        public static let rollDuration: TimeInterval = 2.6

        /// Slow start into a long decelerating glide.
        public static var roll: Animation {
            .timingCurve(0.28, 0.02, 0.16, 1, duration: rollDuration)
        }

        /// Name-plate text arrival and swap while browsing.
        public static var plateSwap: Animation {
            .spring(response: 0.30, dampingFraction: 0.9)
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

        /// Timeline duration until freeze frost finishes encroaching before sustained particle shimmer.
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
        /// Multiplier applied to `cardMaximumTiltDegrees` for horizontal lean while held.
        public static let cardTiltLeanMultiplier = 0.65

        public static var cardHeldTiltDegrees: Double {
            cardMaximumTiltDegrees * cardTiltLeanMultiplier
        }

        /// Vertical drag tilt gain and clamp while a held card is dragged.
        public static let cardVerticalTiltGain = 4.0
        public static let cardVerticalTiltClamp = 4.0
        /// Perspective used by hand-card and cast-overlay 3D rotations.
        public static let cardPerspective: CGFloat = 0.10

        // MARK: Hand card armed / deal visuals

        /// Extra uniform scale while play-armed.
        public static let cardArmedScaleBoost: CGFloat = 0.01
        public static let cardArmedRingOpacity: CGFloat = 0.55
        public static let cardArmedRingLineWidth: CGFloat = 2

        /// Deal insertion travel (offset in points) and starting scale.
        public static let dealInsertOffset: CGFloat = 120
        public static let dealInsertScale: CGFloat = 0.50

        /// Hold duration required to inspect a card without moving it.
        public static let cardInspectHoldDuration: TimeInterval = 0.5
        /// How far a tap-play card pops up as a fraction of card height before dissolving.
        public static let tapLiftHeightFraction: CGFloat = 0.20
        /// Pause after the pop before the tap-play dissolve begins (so the lift reads).
        public static let tapLiftPlayDelay: TimeInterval = 0.18

        public static var cardPress: Animation {
            .spring(response: 0.16, dampingFraction: 1.0)
        }

        public static var cardLift: Animation {
            .spring(response: 0.2, dampingFraction: 1.0)
        }

        public static var cardReturn: Animation {
            .spring(response: 0.38, dampingFraction: 0.82)
        }

        public static var tapLift: Animation {
            .spring(response: 0.30, dampingFraction: 0.68)
        }

        public static var handReflow: Animation {
            .spring(response: 0.34, dampingFraction: 0.92)
        }

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
        public static let alchemyPopDisplayDuration: TimeInterval = 0.73

        /// Rapid FIFO cadence for successive chips in one combatant's vertical stream.
        public static let feedbackStreamStagger: TimeInterval = 0.126

        /// Maximum rise as a fraction of the corresponding combatant card height.
        public static let chipTravelFraction: CGFloat = 0.48

        /// Minimum clearance between the final label bounds and the card's top edge.
        public static let chipTopClearance: CGFloat = 4

        // MARK: Alchemy Pop envelope (ported from Alchemy combat-text.tsx)

        public static let alchemyPopStartScale: CGFloat = 0.5
        public static let alchemyPopOvershootScale: CGFloat = 2.0
        public static let alchemyPopHoldScale: CGFloat = 1.8
        public static let alchemyPopEndScale: CGFloat = 1.0
        public static let alchemyPopDuration: TimeInterval = 0.14
        public static let alchemyPopHoldDuration: TimeInterval = 0.14
        public static let alchemyPopShrinkDuration: TimeInterval = 0.45
        public static let alchemyPopRiseDuration: TimeInterval = 0.45
        public static let alchemyPopFadeDuration: TimeInterval = 0.28

        /// Maximum continuous accumulation lifetime for an active floating chip.
        public static let maxContinuousChipLifetime: TimeInterval = 1.2

        /// Lifetime buffer for delayed raw-event cleanup.
        public static var maxChipLifetime: TimeInterval {
            chipDisplayDuration + 0.05
        }

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

        /// Parked until hold ends, then cubic ease-in rise.
        @inlinable
        public static func chipMotionProgress(elapsed: TimeInterval) -> Double {
            guard elapsed > alchemyHoldEndTime else { return 0 }
            let riseProg = (elapsed - alchemyHoldEndTime) / alchemyPopRiseDuration
            let clamped = min(max(riseProg, 0), 1)
            return clamped * clamped * clamped
        }

        /// Scale envelope for the Alchemy Pop float recipe. Pop overshoot -> hold -> shrink to 1.0 during rise.
        @inlinable
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

        @inlinable
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

        @inlinable
        public static func chipTravelDistance(cardHeight: CGFloat, chipHeight: CGFloat) -> CGFloat {
            let proportionalTravel = cardHeight * chipTravelFraction
            let topSafeTravel = cardHeight / 2 - chipHeight / 2 - chipTopClearance
            return max(0, min(proportionalTravel, topSafeTravel))
        }

        // MARK: Alchemy Pop sampling

        @inlinable
        public static var alchemyPopPeakTime: TimeInterval {
            alchemyPopDuration * 0.75
        }

        @inlinable
        public static var alchemyPopEndTime: TimeInterval {
            alchemyPopDuration
        }

        @inlinable
        public static var alchemyHoldEndTime: TimeInterval {
            alchemyPopEndTime + alchemyPopHoldDuration
        }

        @inlinable
        public static var alchemyFadeStartTime: TimeInterval {
            max(alchemyHoldEndTime, alchemyPopDisplayDuration - alchemyPopFadeDuration)
        }

        @inlinable
        public static func lerp(_ start: CGFloat, _ end: CGFloat, _ progress: Double) -> CGFloat {
            let p = min(max(progress, 0), 1)
            return start + (end - start) * CGFloat(p)
        }

        @inlinable
        public static func lerp(_ start: Double, _ end: Double, _ progress: Double) -> Double {
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
