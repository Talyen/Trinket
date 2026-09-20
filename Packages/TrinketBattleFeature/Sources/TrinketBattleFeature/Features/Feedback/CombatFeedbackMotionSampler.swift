import Foundation
import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct CombatFeedbackAnimationState: Equatable {
    var opacity = 1.0
    var scale = 1.0
    var riseProgress = 0.0
    var shineProgress = 1.0
}

enum CombatFeedbackMotionSampler {
    static func state(
        for item: CombatFeedbackItem,
        at date: Date,
    ) -> CombatFeedbackAnimationState {
        let date = item.pausedAt ?? date
        let elapsed = max(0, date.timeIntervalSince(item.firstScheduledAt))
        if item.usesStationaryExperiment {
            let updateElapsed = item.lastUpdatedAt.map { max(0, date.timeIntervalSince($0)) }
            let pulseProgress = BattleMotion.smoothProgress((updateElapsed ?? StationaryFeedbackLayout.mergePulseDuration)
                / StationaryFeedbackLayout.mergePulseDuration)
            let pulseScale = 1 + (StationaryFeedbackLayout.mergePulseScale - 1) * (1 - pulseProgress)
            let driftProgress = min(1, max(0, (elapsed - StationaryFeedbackLayout.shrinkStart) / StationaryFeedbackLayout.shrinkDuration))
            let fadeProgress = (elapsed - StationaryFeedbackLayout.fadeStart) / StationaryFeedbackLayout.fadeDuration
            return CombatFeedbackAnimationState(
                opacity: 1 - BattleMotion.smoothProgress(fadeProgress),
                scale: stationaryScale(elapsed: elapsed) * pulseScale,
                riseProgress: driftProgress * driftProgress,
                shineProgress: min(1, (updateElapsed ?? elapsed) / StationaryFeedbackLayout.shineDuration),
            )
        }
        let holdEnd = item.firstScheduledAt.addingTimeInterval(BattleMotion.chipHoldEndTime)
        let riseStart = min(holdEnd, item.retiringAt ?? holdEnd)
        let riseDuration = BattleMotion.chipDisplayDuration - BattleMotion.chipHoldEndTime
        let fadeDuration = item.retiringAt.map {
            max(TimeInterval.ulpOfOne, item.expiresAt.timeIntervalSince($0))
        } ?? BattleMotion.chipPopFadeDuration
        let opacity = min(1, max(0, item.expiresAt.timeIntervalSince(date) / fadeDuration))
        let updateElapsed = item.lastUpdatedAt.map { max(0, date.timeIntervalSince($0)) } ?? 1
        let updateScale = 1 + Double(BattleMotion.chipUpdateOvershootScale - 1) * (1 - BattleMotion.smoothProgress(updateElapsed / 0.18))
        return CombatFeedbackAnimationState(
            opacity: BattleMotion.smoothProgress(opacity),
            scale: Double(BattleMotion.chipScale(elapsed: elapsed)) * updateScale,
            riseProgress: BattleMotion.smoothProgress(date.timeIntervalSince(riseStart) / riseDuration),
        )
    }

    private static func stationaryScale(elapsed: TimeInterval) -> Double {
        let scale: Double
        if elapsed < StationaryFeedbackLayout.popDuration {
            let remaining = 1 - elapsed / StationaryFeedbackLayout.popDuration
            scale = StationaryFeedbackLayout.initialScale
                + (StationaryFeedbackLayout.peakScale - StationaryFeedbackLayout.initialScale) * (1 - remaining * remaining * remaining)
        } else {
            let progress = min(1, max(0, (elapsed - StationaryFeedbackLayout.shrinkStart) / StationaryFeedbackLayout.shrinkDuration))
            scale = StationaryFeedbackLayout.peakScale
                + (StationaryFeedbackLayout.finalScale - StationaryFeedbackLayout.peakScale) * progress * progress
        }
        return StationaryFeedbackLayout.sizeScale * scale
    }
}
