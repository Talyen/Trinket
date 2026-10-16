import Foundation
import TrinketDesignSystem

struct CombatFeedbackAnimationState: Equatable {
    var opacity = 1.0
    var scale = 1.0
    var riseProgress = 0.0
    var shineProgress = 1.0
}

/// Matching fragment hosts share timing math; fitting and lane pushes stay host-local.
@MainActor
final class CombatFeedbackMotionTrack {
    struct Sample: Equatable {
        let animation: CombatFeedbackAnimationState
        let elapsed: TimeInterval
        let criticalElapsed: TimeInterval
        let shadowOpacity: Float
        let flashOpacity: Float
    }

    private struct Key: Equatable {
        let date: Date
        let firstScheduledAt: Date
        let expiresAt: Date
        let lastUpdatedAt: Date?
        let criticalAt: Date?
        let isImpact: Bool
    }

    private var lastKey: Key?
    private var lastSample: Sample?

    func sample(for item: CombatFeedbackItem, at date: Date) -> Sample {
        let now = item.pausedAt ?? date
        let key = Key(
            date: now, firstScheduledAt: item.firstScheduledAt, expiresAt: item.expiresAt,
            lastUpdatedAt: item.lastUpdatedAt, criticalAt: item.criticalAt, isImpact: item.region == .impact,
        )
        if lastKey == key, let sample = lastSample {
            return sample
        }
        let criticalElapsed = item.criticalAt.map { max(0, now.timeIntervalSince($0)) } ?? 1
        let sample = Sample(
            animation: CombatFeedbackMotionSampler.state(for: item, at: date),
            elapsed: now.timeIntervalSince(item.firstScheduledAt),
            criticalElapsed: criticalElapsed,
            shadowOpacity: Float(1 - BattleMotion.smoothProgress(criticalElapsed / 0.48)),
            flashOpacity: Float(0.8 * (1 - BattleMotion.smoothProgress(criticalElapsed / 0.14))),
        )
        lastKey = key
        lastSample = sample
        return sample
    }
}

enum CombatFeedbackMotionSampler {
    static let lifetime: TimeInterval = 0.92
    static let fadeDuration: TimeInterval = 0.34
    static let riseDistance = 52.0
    static let statusSizeScale = 0.80
    static let statusPeakScale = 1.20

    static func state(for item: CombatFeedbackItem, at date: Date) -> CombatFeedbackAnimationState {
        let date = item.pausedAt ?? date
        if item.region == .announcement {
            let elapsed = max(0, date.timeIntervalSince(item.firstScheduledAt))
            let scale = elapsed < 0.14 ? 0.9 + 0.18 * BattleMotion.smoothProgress(elapsed / 0.14)
                : 1.08 - 0.08 * BattleMotion.smoothProgress((elapsed - 0.14) / 0.10)
            return CombatFeedbackAnimationState(
                opacity: 1 - BattleMotion.smoothProgress((elapsed - 1.25) / 0.35),
                scale: 1.25 * scale,
                riseProgress: 1 - pow(1 - min(1, max(0, (elapsed - 0.20) / (lifetime - 0.20))), 3),
                shineProgress: min(1, max(0, (elapsed - 0.10) / 1.0)),
            )
        }
        let elapsed = max(0, date.timeIntervalSince(item.firstScheduledAt))
        let progress = min(1, max(0, (elapsed - 0.20) / (lifetime - 0.20)))
        let exit = 1 - pow(1 - progress, 3)
        let scale = if item.region != .impact {
            statusScale(at: elapsed)
        } else if elapsed < 0.05 {
            0.85 + (1.78 - 0.85) * (1 - pow(1 - elapsed / 0.05, 3))
        } else if elapsed < 0.09 {
            1.78
        } else if elapsed < 0.16 {
            1.78 + (1.48 - 1.78) * BattleMotion.smoothProgress((elapsed - 0.09) / 0.07)
        } else {
            1.48 + (1.22 - 1.48) * exit
        }
        let updateElapsed = item.region == .impact ? item.lastUpdatedAt.map { max(0, date.timeIntervalSince($0)) } : nil
        let pulse = 1 + 0.10 * (1 - BattleMotion.smoothProgress((updateElapsed ?? 0.18) / 0.18))
        let fadeElapsed = date.timeIntervalSince(item.expiresAt.addingTimeInterval(-fadeDuration))
        return CombatFeedbackAnimationState(
            opacity: 1 - BattleMotion.smoothProgress(fadeElapsed / fadeDuration),
            scale: 1.2 * scale * pulse * (item.region == .impact ? 1 : statusSizeScale),
            riseProgress: item.region == .impact ? exit : 0,
            shineProgress: min(1, (updateElapsed ?? elapsed) / 0.45),
        )
    }

    private static func statusScale(at elapsed: TimeInterval) -> Double {
        if elapsed < 0.05 {
            return 0.85 + (statusPeakScale - 0.85) * (1 - pow(1 - elapsed / 0.05, 3))
        }
        if elapsed < 0.09 {
            return statusPeakScale
        }
        return statusPeakScale + (1 - statusPeakScale) * BattleMotion.smoothProgress((elapsed - 0.09) / 0.07)
    }
}
