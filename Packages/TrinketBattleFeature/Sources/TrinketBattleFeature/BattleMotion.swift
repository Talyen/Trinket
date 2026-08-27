import CoreGraphics
import SwiftUI
import TrinketDesignSystem

/// Feature-owned battle motion. New battle UI should use `BattleMotion` directly;
/// `TrinketMotion.Battle` remains for compatibility and forwards here.
public enum BattleMotion: Sendable {
    public static let cardActivationDuration = TrinketMotion.Battle.cardActivationDuration
    public static let cardActivationStuckSlack = TrinketMotion.Battle.cardActivationStuckSlack
    public static let combatantSliceDuration = TrinketMotion.Battle.combatantSliceDuration
    public static let combatantStatusEffectPhaseDuration = TrinketMotion.Battle.combatantStatusEffectPhaseDuration
    public static let combatantFreezeEncroachProgress = TrinketMotion.Battle.combatantFreezeEncroachProgress
    public static var combatantFreezeEncroachDuration: TimeInterval { TrinketMotion.Battle.combatantFreezeEncroachDuration }
    public static let outcomePresentationMinimum = TrinketMotion.Battle.outcomePresentationMinimum
    public static let outcomePresentationPadding = TrinketMotion.Battle.outcomePresentationPadding
    public static let cardDrawStagger = TrinketMotion.Battle.cardDrawStagger
    public static var deal: Animation { TrinketMotion.Battle.deal }
    public static let cardHeldScale = TrinketMotion.Battle.cardHeldScale
    public static let cardHeldShadowRadius = TrinketMotion.Battle.cardHeldShadowRadius
    public static let cardHeldShadowY = TrinketMotion.Battle.cardHeldShadowY
    public static let cardMaximumTiltDegrees = TrinketMotion.Battle.cardMaximumTiltDegrees
    public static let cardTiltLeanMultiplier = TrinketMotion.Battle.cardTiltLeanMultiplier
    public static var cardHeldTiltDegrees: Double { TrinketMotion.Battle.cardHeldTiltDegrees }
    public static let cardVerticalTiltGain = TrinketMotion.Battle.cardVerticalTiltGain
    public static let cardVerticalTiltClamp = TrinketMotion.Battle.cardVerticalTiltClamp
    public static let cardPerspective = TrinketMotion.Battle.cardPerspective
    public static let cardArmedScaleBoost = TrinketMotion.Battle.cardArmedScaleBoost
    public static let cardArmedRingOpacity = TrinketMotion.Battle.cardArmedRingOpacity
    public static let cardArmedRingLineWidth = TrinketMotion.Battle.cardArmedRingLineWidth
    public static let dealInsertOffset = TrinketMotion.Battle.dealInsertOffset
    public static let dealInsertScale = TrinketMotion.Battle.dealInsertScale
    public static let cardInspectHoldDuration = TrinketMotion.Battle.cardInspectHoldDuration
    public static let tapLiftHeightFraction = TrinketMotion.Battle.tapLiftHeightFraction
    public static let tapLiftPlayDelay = TrinketMotion.Battle.tapLiftPlayDelay
    public static var cardPress: Animation { TrinketMotion.Battle.cardPress }
    public static var cardLift: Animation { TrinketMotion.Battle.cardLift }
    public static var cardReturn: Animation { TrinketMotion.Battle.cardReturn }
    public static var tapLift: Animation { TrinketMotion.Battle.tapLift }
    public static var handReflow: Animation { TrinketMotion.Battle.handReflow }
    public static let ultimateVideoWatchdog = TrinketMotion.Battle.ultimateVideoWatchdog
    public static let ultimateCinematicSessionWatchdog = TrinketMotion.Battle.ultimateCinematicSessionWatchdog
    public static let scrimFade = TrinketMotion.Battle.scrimFade
    public static let ultimateSplitOpen = TrinketMotion.Battle.ultimateSplitOpen
    public static let ultimateSplitClose = TrinketMotion.Battle.ultimateSplitClose
    public static let ultimateCinematicPlaybackSpeed = TrinketMotion.Battle.ultimateCinematicPlaybackSpeed
    public static var ultimateSplitOpenAtPlayback: TimeInterval { TrinketMotion.Battle.ultimateSplitOpenAtPlayback }
    public static var ultimateSplitCloseAtPlayback: TimeInterval { TrinketMotion.Battle.ultimateSplitCloseAtPlayback }
    public static var ultimateSplitOpenPlaybackAnimation: Animation { TrinketMotion.Battle.ultimateSplitOpenPlaybackAnimation }
    public static var ultimateSplitClosePlaybackAnimation: Animation { TrinketMotion.Battle.ultimateSplitClosePlaybackAnimation }
    public static let chipDisplayDuration = TrinketMotion.Battle.chipDisplayDuration
    public static let alchemyPopDisplayDuration = TrinketMotion.Battle.alchemyPopDisplayDuration
    public static let feedbackStreamStagger = TrinketMotion.Battle.feedbackStreamStagger
    public static let chipTravelFraction = TrinketMotion.Battle.chipTravelFraction
    public static let chipTopClearance = TrinketMotion.Battle.chipTopClearance
    public static let alchemyPopStartScale = TrinketMotion.Battle.alchemyPopStartScale
    public static let alchemyPopOvershootScale = TrinketMotion.Battle.alchemyPopOvershootScale
    public static let alchemyPopHoldScale = TrinketMotion.Battle.alchemyPopHoldScale
    public static let alchemyPopEndScale = TrinketMotion.Battle.alchemyPopEndScale
    public static let alchemyPopDuration = TrinketMotion.Battle.alchemyPopDuration
    public static let alchemyPopHoldDuration = TrinketMotion.Battle.alchemyPopHoldDuration
    public static let alchemyPopShrinkDuration = TrinketMotion.Battle.alchemyPopShrinkDuration
    public static let alchemyPopRiseDuration = TrinketMotion.Battle.alchemyPopRiseDuration
    public static let alchemyPopFadeDuration = TrinketMotion.Battle.alchemyPopFadeDuration
    public static let maxContinuousChipLifetime = TrinketMotion.Battle.maxContinuousChipLifetime
    public static var maxChipLifetime: TimeInterval { TrinketMotion.Battle.maxChipLifetime }
    public static let cardCastParticleCount = TrinketMotion.Battle.cardCastParticleCount
    public static var scrim: Animation { TrinketMotion.Battle.scrim }
    public static let statusBorderPulseDuration = TrinketMotion.Battle.statusBorderPulseDuration
    public static var statusBorderPulse: Animation { TrinketMotion.Battle.statusBorderPulse }
    public static let statusBorderPulseDimOpacity = TrinketMotion.Battle.statusBorderPulseDimOpacity
    public static func chipMotionProgress(elapsed: TimeInterval) -> Double { TrinketMotion.Battle.chipMotionProgress(elapsed: elapsed) }
    public static func chipScale(elapsed: TimeInterval) -> CGFloat { TrinketMotion.Battle.chipScale(elapsed: elapsed) }
    public static func chipOpacity(elapsed: TimeInterval) -> Double { TrinketMotion.Battle.chipOpacity(elapsed: elapsed) }
    public static func chipTravelDistance(cardHeight: CGFloat, chipHeight: CGFloat) -> CGFloat { TrinketMotion.Battle.chipTravelDistance(cardHeight: cardHeight, chipHeight: chipHeight) }
    public static var alchemyPopPeakTime: TimeInterval { TrinketMotion.Battle.alchemyPopPeakTime }
    public static var alchemyPopEndTime: TimeInterval { TrinketMotion.Battle.alchemyPopEndTime }
    public static var alchemyHoldEndTime: TimeInterval { TrinketMotion.Battle.alchemyHoldEndTime }
    public static var alchemyFadeStartTime: TimeInterval { TrinketMotion.Battle.alchemyFadeStartTime }
}
