import CoreGraphics
import Foundation
import SwiftUI
import TrinketDesignSystem

enum BattleMotion: Sendable {
    static let cardActivationDuration = TrinketMotion.Content.cardDissolveDuration
    static let cardActivationStuckSlack: TimeInterval = 0.35
    static let combatantSliceDuration: TimeInterval = 1.25
    static let combatantStatusEffectPhaseDuration: TimeInterval = 4.0
    static let combatantFreezeEncroachProgress = 0.35

    static var combatantFreezeEncroachDuration: TimeInterval {
        combatantStatusEffectPhaseDuration * combatantFreezeEncroachProgress
    }

    static let outcomePresentationMinimum: TimeInterval = 1.25
    static let outcomePresentationPadding: TimeInterval = 0.1
    static let cardDrawStagger: TimeInterval = 0.045

    static var deal: Animation {
        .spring(response: 0.3, dampingFraction: 0.94)
    }

    static let cardHeldScale = 1.035
    /// Softer than a deep drop shadow so held-card drag stays compositor-cheap.
    static let cardHeldShadowRadius: CGFloat = 6
    static let cardHeldShadowY: CGFloat = 16
    static let cardMaximumTiltDegrees = 20.0
    static let cardTiltLeanMultiplier = 0.65

    static var cardHeldTiltDegrees: Double {
        cardMaximumTiltDegrees * cardTiltLeanMultiplier
    }

    static let cardVerticalTiltGain = 4.0
    static let cardVerticalTiltClamp = 4.0
    static let cardPerspective: CGFloat = 0.10
    static let cardArmedScaleBoost: CGFloat = 0.01
    static let cardArmedRingOpacity: CGFloat = 0.55
    static let cardArmedRingLineWidth: CGFloat = 2
    static let dealInsertOffset: CGFloat = 120
    static let dealInsertScale: CGFloat = 0.50
    static let cardInspectHoldDuration: TimeInterval = 0.5
    static let tapLiftHeightFraction: CGFloat = 0.20
    static let tapLiftPlayDelay: TimeInterval = 0.18

    static var cardPress: Animation {
        .spring(response: 0.16, dampingFraction: 1.0)
    }

    static var cardLift: Animation {
        .spring(response: 0.2, dampingFraction: 1.0)
    }

    static var cardReturn: Animation {
        .spring(response: 0.38, dampingFraction: 0.82)
    }

    static var tapLift: Animation {
        .spring(response: 0.30, dampingFraction: 0.68)
    }

    static var handReflow: Animation {
        .spring(response: 0.34, dampingFraction: 0.92)
    }

    /// Hard ceilings prevent missing video notifications from trapping the battle overlay.
    static let ultimateVideoWatchdog: TimeInterval = 12.0
    static let ultimateCinematicSessionWatchdog: TimeInterval = 20.0
    static let scrimFade: TimeInterval = 0.2
    static let ultimateSplitOpen: TimeInterval = 0.5
    static let ultimateSplitClose: TimeInterval = 0.38
    /// Code-only multiplier keeps video rate and cover timing synchronized.
    static let ultimateCinematicPlaybackSpeed = 1.2

    static var ultimateSplitOpenAtPlayback: TimeInterval {
        ultimateSplitOpen / ultimateCinematicPlaybackSpeed
    }

    static var ultimateSplitCloseAtPlayback: TimeInterval {
        ultimateSplitClose / ultimateCinematicPlaybackSpeed
    }

    static var ultimateSplitOpenPlaybackAnimation: Animation {
        .easeInOut(duration: ultimateSplitOpenAtPlayback)
    }

    static var ultimateSplitClosePlaybackAnimation: Animation {
        .easeInOut(duration: ultimateSplitCloseAtPlayback)
    }

    static let chipDisplayDuration: TimeInterval = alchemyPopDisplayDuration
    static let alchemyPopDisplayDuration: TimeInterval = 0.73
    static let feedbackStreamStagger: TimeInterval = 0.126
    static let chipTravelFraction: CGFloat = 0.48
    static let chipTopClearance: CGFloat = 4
    static let alchemyPopStartScale: CGFloat = 0.5
    static let alchemyPopOvershootScale: CGFloat = 2.0
    static let alchemyPopHoldScale: CGFloat = 1.8
    static let alchemyPopEndScale: CGFloat = 1.0
    static let alchemyPopDuration: TimeInterval = 0.14
    static let alchemyPopHoldDuration: TimeInterval = 0.14
    static let alchemyPopShrinkDuration: TimeInterval = 0.45
    static let alchemyPopRiseDuration: TimeInterval = 0.45
    static let alchemyPopFadeDuration: TimeInterval = 0.28
    static let maxContinuousChipLifetime: TimeInterval = 1.2

    static var maxChipLifetime: TimeInterval {
        chipDisplayDuration + 0.05
    }

    static let cardCastParticleCount = 8

    static var scrim: Animation {
        .easeOut(duration: scrimFade)
    }

    static let statusBorderPulseDuration: TimeInterval = 0.9

    static var statusBorderPulse: Animation {
        .easeInOut(duration: statusBorderPulseDuration)
    }

    static let statusBorderPulseDimOpacity = 0.45

    /// Holds the chip at its impact point before a cubic rise.
    static func chipMotionProgress(elapsed: TimeInterval) -> Double {
        guard elapsed > alchemyHoldEndTime else { return 0 }
        let riseProgress = (elapsed - alchemyHoldEndTime) / alchemyPopRiseDuration
        let clamped = min(max(riseProgress, 0), 1)
        return clamped * clamped * clamped
    }

    static func chipScale(elapsed: TimeInterval) -> CGFloat {
        if elapsed <= 0 {
            return alchemyPopStartScale
        }
        if elapsed <= alchemyPopPeakTime {
            let progress = elapsed / alchemyPopPeakTime
            return lerp(alchemyPopStartScale, alchemyPopOvershootScale, progress)
        }
        if elapsed <= alchemyPopEndTime {
            let progress = (elapsed - alchemyPopPeakTime) / (alchemyPopEndTime - alchemyPopPeakTime)
            return lerp(alchemyPopOvershootScale, alchemyPopHoldScale, progress)
        }
        if elapsed <= alchemyHoldEndTime {
            return alchemyPopHoldScale
        }
        let shrinkProgress = min(1, (elapsed - alchemyHoldEndTime) / alchemyPopShrinkDuration)
        return lerp(alchemyPopHoldScale, alchemyPopEndScale, shrinkProgress)
    }

    static func chipOpacity(elapsed: TimeInterval) -> Double {
        if elapsed <= alchemyFadeStartTime {
            return 1
        }
        if elapsed >= alchemyPopDisplayDuration {
            return 0
        }
        let fadeProgress = (elapsed - alchemyFadeStartTime)
            / (alchemyPopDisplayDuration - alchemyFadeStartTime)
        return lerp(1, 0, fadeProgress)
    }

    static func chipTravelDistance(cardHeight: CGFloat, chipHeight: CGFloat) -> CGFloat {
        let proportionalTravel = cardHeight * chipTravelFraction
        let topSafeTravel = cardHeight / 2 - chipHeight / 2 - chipTopClearance
        return max(0, min(proportionalTravel, topSafeTravel))
    }

    static var alchemyPopPeakTime: TimeInterval {
        alchemyPopDuration * 0.75
    }

    static var alchemyPopEndTime: TimeInterval {
        alchemyPopDuration
    }

    static var alchemyHoldEndTime: TimeInterval {
        alchemyPopEndTime + alchemyPopHoldDuration
    }

    static var alchemyFadeStartTime: TimeInterval {
        max(alchemyHoldEndTime, alchemyPopDisplayDuration - alchemyPopFadeDuration)
    }

    static func lerp(_ start: CGFloat, _ end: CGFloat, _ progress: Double) -> CGFloat {
        let clamped = min(max(progress, 0), 1)
        return start + (end - start) * CGFloat(clamped)
    }

    static func lerp(_ start: Double, _ end: Double, _ progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        return start + (end - start) * clamped
    }
}
