import CoreGraphics
import Foundation
import SwiftUI
import TrinketDesignSystem

enum BattleMotion {
    static let cardActivationDuration = TrinketMotion.Content.cardDissolveDuration
    static let cardActivationStuckSlack: TimeInterval = 0.35
    static let combatantSliceDuration: TimeInterval = 1.25
    static let combatantStatusEffectPhaseDuration: TimeInterval = 4.0
    static let combatantFreezeEncroachProgress = 0.35
    static let combatantFreezeOnsetProgress = 0.12

    static var combatantFreezeEncroachDuration: TimeInterval {
        combatantStatusEffectPhaseDuration * combatantFreezeEncroachProgress
    }

    static let outcomePresentationMinimum: TimeInterval = 1.25
    static let outcomePresentationPadding: TimeInterval = 0.1
    static let cardDrawStagger: TimeInterval = 0.045
    static let cardDealDuration: TimeInterval = 0.3
    static let automaticCardRevealDuration: TimeInterval = 0.48

    static var deal: Animation {
        .spring(response: cardDealDuration, dampingFraction: 0.94)
    }

    static let cardHeldScale = 1.035
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
    static let cardArmedRingLineWidth: CGFloat = 2
    static let cardReadyRingOpacity = 0.18
    static let cardReadyPulseOpacity = 0.38
    static let cardReadyRingLineWidth: CGFloat = 1
    static let dealInsertOffset: CGFloat = 120
    static let dealInsertScale: CGFloat = 0.50
    static let cardInspectHoldDuration: TimeInterval = 0.36
    static let cardPressedScale: CGFloat = 0.95
    static let cardPlayRiseHeightFraction: CGFloat = 0.55

    static var cardPress: Animation {
        .spring(response: 0.16, dampingFraction: 1.0)
    }

    static var cardLift: Animation {
        .spring(response: 0.2, dampingFraction: 1.0)
    }

    static var cardReturn: Animation {
        .spring(response: 0.38, dampingFraction: 0.82)
    }

    static var handReflow: Animation {
        .spring(response: 0.34, dampingFraction: 0.92)
    }

    static let scrimFade: TimeInterval = 0.2
    static let ultimateInFrameDuration: TimeInterval = 3.0
    static let ultimateInFrameFadeDuration: TimeInterval = 0.25
    static let ultimateCinematicPlaybackSpeed = 1.2

    static let chipDisplayDuration: TimeInterval = 0.95
    static let feedbackHandoffDuration: TimeInterval = 0.15
    static let chipPopStartScale: CGFloat = 0.5
    static let chipPopOvershootScale: CGFloat = 2.0
    static let chipPopHoldScale: CGFloat = 1.8
    static let chipUpdateOvershootScale: CGFloat = 1.08
    static let chipMaximumScale = chipPopOvershootScale * chipUpdateOvershootScale
    static let chipPopEndScale: CGFloat = 1.0
    static let chipPopDuration: TimeInterval = 0.14
    static let chipPopHoldDuration: TimeInterval = 0.20
    static let chipPopShrinkDuration: TimeInterval = 0.45
    static let chipPopFadeDuration: TimeInterval = 0.28
    static let maxContinuousChipLifetime: TimeInterval = 1.2

    static let cardCastParticleCount = 8

    static var scrim: Animation {
        .easeOut(duration: scrimFade)
    }

    static let statusBorderPulseDuration: TimeInterval = 0.9

    static var statusBorderPulse: Animation {
        .easeInOut(duration: statusBorderPulseDuration)
    }

    static let statusBorderPulseDimOpacity = 0.45

    static func smoothProgress(_ progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }

    /// Cubic ease-out. Shared by the manual cast rise and the automatic-card
    /// arrival flight; the two presentations stay separate views because the
    /// arrival flight (off-screen fly-in to a stage position) is intentionally
    /// different from the in-place resting-center cast.
    static func easeOutCubic(_ progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }

    static func chipScale(elapsed: TimeInterval) -> CGFloat {
        if elapsed <= 0 {
            return chipPopStartScale
        }
        if elapsed <= chipPopPeakTime {
            let progress = elapsed / chipPopPeakTime
            return lerp(chipPopStartScale, chipPopOvershootScale, smoothProgress(progress))
        }
        if elapsed <= chipPopEndTime {
            let progress = (elapsed - chipPopPeakTime) / (chipPopEndTime - chipPopPeakTime)
            return lerp(chipPopOvershootScale, chipPopHoldScale, smoothProgress(progress))
        }
        if elapsed <= chipHoldEndTime {
            return chipPopHoldScale
        }
        let shrinkProgress = min(1, (elapsed - chipHoldEndTime) / chipPopShrinkDuration)
        return lerp(chipPopHoldScale, chipPopEndScale, smoothProgress(shrinkProgress))
    }

    static var chipPopPeakTime: TimeInterval {
        chipPopDuration * 0.75
    }

    static var chipPopEndTime: TimeInterval {
        chipPopDuration
    }

    static var chipHoldEndTime: TimeInterval {
        chipPopEndTime + chipPopHoldDuration
    }

    static func lerp<T: BinaryFloatingPoint>(_ start: T, _ end: T, _ progress: Double) -> T {
        let clamped = min(max(progress, 0), 1)
        return start + (end - start) * T(clamped)
    }
}
