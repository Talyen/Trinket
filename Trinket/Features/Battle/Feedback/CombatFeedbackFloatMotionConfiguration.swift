import CoreGraphics
import Foundation
import TrinketDesignSystem

/// Tunable floating-combat-text motion recipe for the DEBUG Float Motion Lab.
///
/// Defaults match production Ideal Core (`TrinketMotion.Battle`).
/// The lab mutates a copy; promote dialed-in values into production sampling
/// after picking a winner.
struct CombatFeedbackFloatMotionConfiguration: Equatable {
    enum VerticalDirection: String, CaseIterable, Identifiable {
        case up
        case down

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .up: "Up"
            case .down: "Down"
            }
        }
    }

    enum Easing: String, CaseIterable, Identifiable {
        case linear
        case easeIn
        case easeOut
        case easeInOut
        case power

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .linear: "Linear"
            case .easeIn: "Ease In"
            case .easeOut: "Ease Out"
            case .easeInOut: "Ease In-Out"
            case .power: "Power"
            }
        }
    }

    struct Pose: Equatable {
        var opacity: Double
        var offsetX: CGFloat
        var offsetY: CGFloat
        var scale: CGFloat
        var rotationDegrees: Double
    }

    // MARK: Timing

    var duration: TimeInterval = TrinketMotion.Battle.chipDisplayDuration
    var fadeOutDuration: TimeInterval = TrinketMotion.Battle.chipFadeOutDuration
    /// Fraction of `duration` that stays fully opaque before fade begins.
    var opaqueHoldFraction: Double = TrinketMotion.Battle.chipOpaqueHoldFraction
    /// Fraction of `duration` spent parked at origin before vertical travel begins.
    var riseDelayFraction: Double = 0

    // MARK: Path

    var travelFraction: CGFloat = TrinketMotion.Battle.chipTravelFraction
    var verticalDirection: VerticalDirection = .up
    /// Constant horizontal bias as a fraction of chip width (negative = left).
    var lateralBias: CGFloat = 0
    /// Peak lateral arc as a fraction of chip width (parabola mid-flight).
    var arcAmplitude: CGFloat = 0
    /// Lateral sine amplitude as a fraction of chip width.
    var driftAmplitude: CGFloat = 0
    var driftFrequency: Double = 2
    /// Extra rise past travel, then drop back by this fraction near the end (0 = none).
    var settleAmount: CGFloat = 0

    // MARK: Easing

    var easing: Easing = .easeOut
    var easingPower: Double = 2

    // MARK: Scale

    var startScale: CGFloat = TrinketMotion.Battle.chipStartScale
    var peakScale: CGFloat = TrinketMotion.Battle.chipPeakScale
    var endScale: CGFloat = TrinketMotion.Battle.chipEndScale
    var peakProgress: Double = TrinketMotion.Battle.chipPeakProgress

    // MARK: Rotation

    var startRotation: Double = 0
    var endRotation: Double = 0
    var shakeAmplitude: Double = 0
    var shakeFrequency: Double = 8

    // MARK: Travel

    func travelDistance(cardHeight: CGFloat, chipHeight: CGFloat) -> CGFloat {
        let proportionalTravel = cardHeight * travelFraction
        let topSafeTravel = cardHeight / 2 - chipHeight / 2 - TrinketMotion.Battle.chipTopClearance
        return max(0, min(proportionalTravel, topSafeTravel))
    }

    // MARK: Sampling

    func sample(
        elapsed: TimeInterval,
        seed: Int,
        chipWidth: CGFloat,
        travelDistance: CGFloat
    ) -> Pose {
        let t = min(max(elapsed / max(duration, 0.001), 0), 1)
        let delay = min(max(riseDelayFraction, 0), 0.95)
        let riseWindow = max(1 - delay, 0.001)
        let riseT = t <= delay ? 0 : min((t - delay) / riseWindow, 1)
        let easedRise = applyEasing(riseT)
        let noise = CombatFeedbackLayout.unitNoise(seed: seed)
        let phase = Double(noise) * .pi * 2
        let arcSign: CGFloat = noise < 0.5 ? -1 : 1

        let biasX = lateralBias * chipWidth
        let arcX = arcAmplitude * chipWidth * 4 * easedRise * (1 - easedRise) * arcSign
        let driftX = driftAmplitude * chipWidth
            * CGFloat(sin(2 * Double.pi * driftFrequency * Double(riseT) + phase))
        let offsetX = biasX + arcX + driftX

        let riseProgress = verticalProgress(eased: easedRise)
        let ySign: CGFloat = verticalDirection == .up ? -1 : 1
        let offsetY = ySign * travelDistance * riseProgress

        let baseRotation = startRotation + (endRotation - startRotation) * easedRise
        let shake = shakeAmplitude
            * sin(2 * Double.pi * shakeFrequency * Double(t) + phase * 1.7)

        return Pose(
            opacity: opacity(elapsed: elapsed),
            offsetX: offsetX,
            offsetY: offsetY,
            scale: scale(at: t),
            rotationDegrees: baseRotation + shake
        )
    }

    /// Paste-friendly dump of every knob for promoting lab values into production.
    func parameterDump() -> String {
        """
        // Timing
        duration: \(fmt(duration))
        fadeOutDuration: \(fmt(fadeOutDuration))
        opaqueHoldFraction: \(fmt(opaqueHoldFraction))
        riseDelayFraction: \(fmt(riseDelayFraction))

        // Path
        travelFraction: \(fmt(travelFraction))
        verticalDirection: \(verticalDirection.rawValue)
        lateralBias: \(fmt(lateralBias))
        arcAmplitude: \(fmt(arcAmplitude))
        driftAmplitude: \(fmt(driftAmplitude))
        driftFrequency: \(fmt(driftFrequency))
        settleAmount: \(fmt(settleAmount))

        // Easing
        easing: \(easing.rawValue)
        easingPower: \(fmt(easingPower))

        // Scale
        startScale: \(fmt(startScale))
        peakScale: \(fmt(peakScale))
        endScale: \(fmt(endScale))
        peakProgress: \(fmt(peakProgress))

        // Rotation
        startRotation: \(fmt(startRotation))
        endRotation: \(fmt(endRotation))
        shakeAmplitude: \(fmt(shakeAmplitude))
        shakeFrequency: \(fmt(shakeFrequency))
        """
    }

    // MARK: Private

    private func applyEasing(_ t: Double) -> Double {
        let clamped = min(max(t, 0), 1)
        switch easing {
        case .linear:
            return clamped
        case .easeIn:
            return clamped * clamped
        case .easeOut:
            let inv = 1 - clamped
            return 1 - inv * inv
        case .easeInOut:
            if clamped < 0.5 {
                return 2 * clamped * clamped
            }
            let inv = -2 * clamped + 2
            return 1 - (inv * inv) / 2
        case .power:
            return pow(clamped, max(easingPower, 0.01))
        }
    }

    private func verticalProgress(eased: Double) -> CGFloat {
        guard settleAmount > 0 else { return CGFloat(eased) }
        let peak = 1 + settleAmount
        let settleStart = 0.72
        if eased < settleStart {
            return CGFloat(eased / settleStart) * peak
        }
        let u = (eased - settleStart) / (1 - settleStart)
        let settled = 1 - settleAmount * 0.35
        return peak + (settled - peak) * CGFloat(u)
    }

    private func scale(at t: Double) -> CGFloat {
        let peakAt = min(max(peakProgress, 0.001), 0.999)
        if t <= peakAt {
            let u = t / peakAt
            return startScale + (peakScale - startScale) * CGFloat(u)
        }
        let u = (t - peakAt) / (1 - peakAt)
        return peakScale + (endScale - peakScale) * CGFloat(u)
    }

    private func opacity(elapsed: TimeInterval) -> Double {
        let holdEnd = min(duration * opaqueHoldFraction, duration - 0.001)
        guard elapsed > holdEnd else { return 1 }
        let fadeLen = max(min(fadeOutDuration, duration - holdEnd), 0.001)
        return min(max((holdEnd + fadeLen - elapsed) / fadeLen, 0), 1)
    }

    private func fmt(_ value: Double) -> String {
        String(format: "%.4g", value)
    }

    private func fmt(_ value: CGFloat) -> String {
        String(format: "%.4g", Double(value))
    }
}
