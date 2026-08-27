import CoreGraphics
import SwiftUI
import TrinketDesignSystem

/// Compatibility shim that forwards to `TrinketMotion.Battle` until battle UI
/// migrates off the design system. Canonical battle motion still lives in
/// `TrinketDesignSystem.TrinketMotion.Battle`; this type exists so new
/// `TrinketBattleFeature` code can import from its own module. All values are
/// computed getters so a future move of ownership does not snapshot stale data.
public enum BattleMotion: Sendable {
    public static var cardActivationDuration: TimeInterval {
        TrinketMotion.Battle.cardActivationDuration
    }

    public static var cardActivationStuckSlack: TimeInterval {
        TrinketMotion.Battle.cardActivationStuckSlack
    }

    public static var combatantSliceDuration: TimeInterval {
        TrinketMotion.Battle.combatantSliceDuration
    }

    public static var combatantStatusEffectPhaseDuration: TimeInterval {
        TrinketMotion.Battle.combatantStatusEffectPhaseDuration
    }

    public static var combatantFreezeEncroachProgress: Double {
        TrinketMotion.Battle.combatantFreezeEncroachProgress
    }

    public static var combatantFreezeEncroachDuration: TimeInterval {
        TrinketMotion.Battle.combatantFreezeEncroachDuration
    }

    public static var outcomePresentationMinimum: TimeInterval {
        TrinketMotion.Battle.outcomePresentationMinimum
    }

    public static var outcomePresentationPadding: TimeInterval {
        TrinketMotion.Battle.outcomePresentationPadding
    }

    public static var cardDrawStagger: TimeInterval {
        TrinketMotion.Battle.cardDrawStagger
    }

    public static var deal: Animation {
        TrinketMotion.Battle.deal
    }

    public static var cardHeldScale: Double {
        TrinketMotion.Battle.cardHeldScale
    }

    public static var cardHeldShadowRadius: CGFloat {
        TrinketMotion.Battle.cardHeldShadowRadius
    }

    public static var cardHeldShadowY: CGFloat {
        TrinketMotion.Battle.cardHeldShadowY
    }

    public static var cardMaximumTiltDegrees: Double {
        TrinketMotion.Battle.cardMaximumTiltDegrees
    }

    public static var cardTiltLeanMultiplier: Double {
        TrinketMotion.Battle.cardTiltLeanMultiplier
    }

    public static var cardHeldTiltDegrees: Double {
        TrinketMotion.Battle.cardHeldTiltDegrees
    }

    public static var cardVerticalTiltGain: Double {
        TrinketMotion.Battle.cardVerticalTiltGain
    }

    public static var cardVerticalTiltClamp: Double {
        TrinketMotion.Battle.cardVerticalTiltClamp
    }

    public static var cardPerspective: CGFloat {
        TrinketMotion.Battle.cardPerspective
    }

    public static var cardArmedScaleBoost: CGFloat {
        TrinketMotion.Battle.cardArmedScaleBoost
    }

    public static var cardArmedRingOpacity: CGFloat {
        TrinketMotion.Battle.cardArmedRingOpacity
    }

    public static var cardArmedRingLineWidth: CGFloat {
        TrinketMotion.Battle.cardArmedRingLineWidth
    }

    public static var dealInsertOffset: CGFloat {
        TrinketMotion.Battle.dealInsertOffset
    }

    public static var dealInsertScale: CGFloat {
        TrinketMotion.Battle.dealInsertScale
    }

    public static var cardInspectHoldDuration: TimeInterval {
        TrinketMotion.Battle.cardInspectHoldDuration
    }

    public static var tapLiftHeightFraction: CGFloat {
        TrinketMotion.Battle.tapLiftHeightFraction
    }

    public static var tapLiftPlayDelay: TimeInterval {
        TrinketMotion.Battle.tapLiftPlayDelay
    }

    public static var cardPress: Animation {
        TrinketMotion.Battle.cardPress
    }

    public static var cardLift: Animation {
        TrinketMotion.Battle.cardLift
    }

    public static var cardReturn: Animation {
        TrinketMotion.Battle.cardReturn
    }

    public static var tapLift: Animation {
        TrinketMotion.Battle.tapLift
    }

    public static var handReflow: Animation {
        TrinketMotion.Battle.handReflow
    }

    public static var ultimateVideoWatchdog: TimeInterval {
        TrinketMotion.Battle.ultimateVideoWatchdog
    }

    public static var ultimateCinematicSessionWatchdog: TimeInterval {
        TrinketMotion.Battle.ultimateCinematicSessionWatchdog
    }

    public static var scrimFade: TimeInterval {
        TrinketMotion.Battle.scrimFade
    }

    public static var ultimateSplitOpen: TimeInterval {
        TrinketMotion.Battle.ultimateSplitOpen
    }

    public static var ultimateSplitClose: TimeInterval {
        TrinketMotion.Battle.ultimateSplitClose
    }

    public static var ultimateCinematicPlaybackSpeed: Double {
        TrinketMotion.Battle.ultimateCinematicPlaybackSpeed
    }

    public static var ultimateSplitOpenAtPlayback: TimeInterval {
        TrinketMotion.Battle.ultimateSplitOpenAtPlayback
    }

    public static var ultimateSplitCloseAtPlayback: TimeInterval {
        TrinketMotion.Battle.ultimateSplitCloseAtPlayback
    }

    public static var ultimateSplitOpenPlaybackAnimation: Animation {
        TrinketMotion.Battle.ultimateSplitOpenPlaybackAnimation
    }

    public static var ultimateSplitClosePlaybackAnimation: Animation {
        TrinketMotion.Battle.ultimateSplitClosePlaybackAnimation
    }

    public static var chipDisplayDuration: TimeInterval {
        TrinketMotion.Battle.chipDisplayDuration
    }

    public static var alchemyPopDisplayDuration: TimeInterval {
        TrinketMotion.Battle.alchemyPopDisplayDuration
    }

    public static var feedbackStreamStagger: TimeInterval {
        TrinketMotion.Battle.feedbackStreamStagger
    }

    public static var chipTravelFraction: CGFloat {
        TrinketMotion.Battle.chipTravelFraction
    }

    public static var chipTopClearance: CGFloat {
        TrinketMotion.Battle.chipTopClearance
    }

    public static var alchemyPopStartScale: CGFloat {
        TrinketMotion.Battle.alchemyPopStartScale
    }

    public static var alchemyPopOvershootScale: CGFloat {
        TrinketMotion.Battle.alchemyPopOvershootScale
    }

    public static var alchemyPopHoldScale: CGFloat {
        TrinketMotion.Battle.alchemyPopHoldScale
    }

    public static var alchemyPopEndScale: CGFloat {
        TrinketMotion.Battle.alchemyPopEndScale
    }

    public static var alchemyPopDuration: TimeInterval {
        TrinketMotion.Battle.alchemyPopDuration
    }

    public static var alchemyPopHoldDuration: TimeInterval {
        TrinketMotion.Battle.alchemyPopHoldDuration
    }

    public static var alchemyPopShrinkDuration: TimeInterval {
        TrinketMotion.Battle.alchemyPopShrinkDuration
    }

    public static var alchemyPopRiseDuration: TimeInterval {
        TrinketMotion.Battle.alchemyPopRiseDuration
    }

    public static var alchemyPopFadeDuration: TimeInterval {
        TrinketMotion.Battle.alchemyPopFadeDuration
    }

    public static var maxContinuousChipLifetime: TimeInterval {
        TrinketMotion.Battle.maxContinuousChipLifetime
    }

    public static var maxChipLifetime: TimeInterval {
        TrinketMotion.Battle.maxChipLifetime
    }

    public static var cardCastParticleCount: Int {
        TrinketMotion.Battle.cardCastParticleCount
    }

    public static var scrim: Animation {
        TrinketMotion.Battle.scrim
    }

    public static var statusBorderPulseDuration: TimeInterval {
        TrinketMotion.Battle.statusBorderPulseDuration
    }

    public static var statusBorderPulse: Animation {
        TrinketMotion.Battle.statusBorderPulse
    }

    public static var statusBorderPulseDimOpacity: Double {
        TrinketMotion.Battle.statusBorderPulseDimOpacity
    }

    public static func chipMotionProgress(elapsed: TimeInterval) -> Double {
        TrinketMotion.Battle.chipMotionProgress(elapsed: elapsed)
    }

    public static func chipScale(elapsed: TimeInterval) -> CGFloat {
        TrinketMotion.Battle.chipScale(elapsed: elapsed)
    }

    public static func chipOpacity(elapsed: TimeInterval) -> Double {
        TrinketMotion.Battle.chipOpacity(elapsed: elapsed)
    }

    public static func chipTravelDistance(cardHeight: CGFloat, chipHeight: CGFloat) -> CGFloat {
        TrinketMotion.Battle.chipTravelDistance(
            cardHeight: cardHeight,
            chipHeight: chipHeight
        )
    }

    public static var alchemyPopPeakTime: TimeInterval {
        TrinketMotion.Battle.alchemyPopPeakTime
    }

    public static var alchemyPopEndTime: TimeInterval {
        TrinketMotion.Battle.alchemyPopEndTime
    }

    public static var alchemyHoldEndTime: TimeInterval {
        TrinketMotion.Battle.alchemyHoldEndTime
    }

    public static var alchemyFadeStartTime: TimeInterval {
        TrinketMotion.Battle.alchemyFadeStartTime
    }
}
