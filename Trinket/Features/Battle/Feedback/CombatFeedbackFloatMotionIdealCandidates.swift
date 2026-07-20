import CoreGraphics
import Foundation

/// Ideal combat-float family: one cohesive recipe plus micro-variations.
///
/// Design intent — immediate readable impact, ease-out rise (never accelerates
/// away), fade only after the number has been readable, pure vertical path.
/// Candidates mainly explore how hard the number punches in and how far it
/// scales down as it rises.
enum CombatFeedbackFloatMotionIdealCandidate: Int, CaseIterable, Identifiable {
    case core = 1
    case softerImpact
    case firmerImpact
    case growIn
    case holdThenShrink
    case flatScale
    case deepRecede
    case snapPunch
    case slowBloom
    case microBeat

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .core: "1. Ideal Core"
        case .softerImpact: "2. Softer Impact"
        case .firmerImpact: "3. Firmer Impact"
        case .growIn: "4. Grow In"
        case .holdThenShrink: "5. Hold Then Shrink"
        case .flatScale: "6. Flat Scale"
        case .deepRecede: "7. Deep Recede"
        case .snapPunch: "8. Snap Punch"
        case .slowBloom: "9. Slow Bloom"
        case .microBeat: "10. Micro Beat"
        }
    }

    var blurb: String {
        switch self {
        case .core:
            "1.06→1.10→0.96 — balanced punch and settle"
        case .softerImpact:
            "Quieter punch, gentler settle (1.02→1.05→0.98)"
        case .firmerImpact:
            "Stronger punch, clearer settle (1.10→1.18→0.93)"
        case .growIn:
            "Starts small, blooms up, soft settle (0.88→1.10→0.96)"
        case .holdThenShrink:
            "Spawns large, holds, then shrinks while rising"
        case .flatScale:
            "Almost no scale change — motion is rise + fade only"
        case .deepRecede:
            "Solid punch, then stronger scale-down as it rises"
        case .snapPunch:
            "Fast peak early, then settles for the rest of the rise"
        case .slowBloom:
            "Scale peaks later mid-rise, then eases down"
        case .microBeat:
            "Brief park at peak size, then lift + shrink"
        }
    }

    var configuration: CombatFeedbackFloatMotionConfiguration {
        switch self {
        case .core:
            .idealCore
        case .softerImpact:
            .idealVarying(
                from: .idealCore,
                startScale: 1.02,
                peakScale: 1.05,
                endScale: 0.98,
                peakProgress: 0.12
            )
        case .firmerImpact:
            .idealVarying(
                from: .idealCore,
                startScale: 1.10,
                peakScale: 1.18,
                endScale: 0.93,
                peakProgress: 0.09
            )
        case .growIn:
            .idealVarying(
                from: .idealCore,
                startScale: 0.88,
                peakScale: 1.10,
                endScale: 0.96,
                peakProgress: 0.16
            )
        case .holdThenShrink:
            .idealVarying(
                from: .idealCore,
                startScale: 1.16,
                peakScale: 1.16,
                endScale: 0.88,
                peakProgress: 0.22
            )
        case .flatScale:
            .idealVarying(
                from: .idealCore,
                startScale: 1.0,
                peakScale: 1.0,
                endScale: 1.0,
                peakProgress: 0.5
            )
        case .deepRecede:
            .idealVarying(
                from: .idealCore,
                startScale: 1.08,
                peakScale: 1.12,
                endScale: 0.86,
                peakProgress: 0.12
            )
        case .snapPunch:
            .idealVarying(
                from: .idealCore,
                startScale: 0.92,
                peakScale: 1.14,
                endScale: 0.95,
                peakProgress: 0.06
            )
        case .slowBloom:
            .idealVarying(
                from: .idealCore,
                startScale: 0.98,
                peakScale: 1.12,
                endScale: 0.94,
                peakProgress: 0.32
            )
        case .microBeat:
            .idealVarying(
                from: .idealCore,
                duration: 1.06,
                riseDelayFraction: 0.06,
                startScale: 1.14,
                peakScale: 1.14,
                endScale: 0.92,
                peakProgress: 0.08
            )
        }
    }
}

extension CombatFeedbackFloatMotionConfiguration {
    /// Matches production Ideal Core (`TrinketMotion.Battle` float recipe).
    static var idealCore: CombatFeedbackFloatMotionConfiguration {
        CombatFeedbackFloatMotionConfiguration()
    }

    fileprivate static func idealVarying(
        from base: CombatFeedbackFloatMotionConfiguration,
        duration: TimeInterval? = nil,
        fadeOutDuration: TimeInterval? = nil,
        opaqueHoldFraction: Double? = nil,
        riseDelayFraction: Double? = nil,
        travelFraction: CGFloat? = nil,
        startScale: CGFloat? = nil,
        peakScale: CGFloat? = nil,
        endScale: CGFloat? = nil,
        peakProgress: Double? = nil
    ) -> CombatFeedbackFloatMotionConfiguration {
        var config = base
        if let duration {
            config.duration = duration
        }
        if let fadeOutDuration {
            config.fadeOutDuration = fadeOutDuration
        }
        if let opaqueHoldFraction {
            config.opaqueHoldFraction = opaqueHoldFraction
        }
        if let riseDelayFraction {
            config.riseDelayFraction = riseDelayFraction
        }
        if let travelFraction {
            config.travelFraction = travelFraction
        }
        if let startScale {
            config.startScale = startScale
        }
        if let peakScale {
            config.peakScale = peakScale
        }
        if let endScale {
            config.endScale = endScale
        }
        if let peakProgress {
            config.peakProgress = peakProgress
        }
        return config
    }
}
