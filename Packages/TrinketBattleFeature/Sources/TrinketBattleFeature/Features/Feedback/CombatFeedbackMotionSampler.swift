import Foundation
import TrinketDesignSystem

struct CombatFeedbackAnimationState: Equatable {
    var opacity = 1.0
    var scale = 1.0
    var riseProgress = 0.0
    var shineProgress = 1.0
}

enum CombatFeedbackMotionSampler {
    static let lifetime: TimeInterval = 0.92
    static let fadeDuration: TimeInterval = 0.34
    static let riseDistance = 52.0
    static let statusSizeScale = 0.80

    static func state(for item: CombatFeedbackItem, at date: Date) -> CombatFeedbackAnimationState {
        let date = item.pausedAt ?? date
        let elapsed = max(0, date.timeIntervalSince(item.firstScheduledAt))
        let progress = min(1, max(0, (elapsed - 0.20) / (lifetime - 0.20)))
        let exit = 1 - pow(1 - progress, 3)
        let scale = if elapsed < 0.05 {
            0.85 + (1.78 - 0.85) * (1 - pow(1 - elapsed / 0.05, 3))
        } else if elapsed < 0.09 {
            1.78
        } else if elapsed < 0.16 {
            1.78 + (1.48 - 1.78) * BattleMotion.smoothProgress((elapsed - 0.09) / 0.07)
        } else {
            1.48 + (1.22 - 1.48) * exit
        }
        let updateElapsed = item.lastUpdatedAt.map { max(0, date.timeIntervalSince($0)) }
        let pulse = 1 + 0.10 * (1 - BattleMotion.smoothProgress((updateElapsed ?? 0.18) / 0.18))
        let fadeElapsed = date.timeIntervalSince(item.expiresAt.addingTimeInterval(-fadeDuration))
        return CombatFeedbackAnimationState(
            opacity: 1 - BattleMotion.smoothProgress(fadeElapsed / fadeDuration),
            scale: 1.2 * scale * pulse * (item.region == .impact ? 1 : statusSizeScale),
            riseProgress: item.region == .impact ? exit : 0,
            shineProgress: min(1, (updateElapsed ?? elapsed) / 0.45),
        )
    }
}
