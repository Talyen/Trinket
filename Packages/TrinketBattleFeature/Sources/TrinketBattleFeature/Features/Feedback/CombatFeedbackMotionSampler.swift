import Foundation
import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct CombatFeedbackAnimationState: Equatable {
    var opacity = 1.0
    var scale = 1.0
}

enum CombatFeedbackMotionSampler {
    static func state(
        for item: CombatFeedbackItem,
        at date: Date,
    ) -> CombatFeedbackAnimationState {
        let elapsed = max(0, date.timeIntervalSince(item.firstScheduledAt))
        let fadeDuration = item.retiringAt.map {
            max(TimeInterval.ulpOfOne, item.expiresAt.timeIntervalSince($0))
        } ?? BattleMotion.chipPopFadeDuration
        let opacity = min(1, max(0, item.expiresAt.timeIntervalSince(date) / fadeDuration))
        let updateElapsed = item.lastUpdatedAt.map { max(0, date.timeIntervalSince($0)) } ?? 1
        let updateScale = 1 + Double(BattleMotion.chipUpdateOvershootScale - 1) * (1 - BattleMotion.smoothProgress(updateElapsed / 0.18))
        return CombatFeedbackAnimationState(
            opacity: BattleMotion.smoothProgress(opacity),
            scale: Double(BattleMotion.chipScale(elapsed: elapsed)) * updateScale,
        )
    }
}
