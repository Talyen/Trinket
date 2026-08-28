import Foundation
import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct CombatFeedbackAnimationState: Equatable {
    var opacity = 1.0
    var verticalOffset = 0.0
    var scale = 1.0
}

enum CombatFeedbackMotionSampler {
    static func state(
        for item: CombatFeedbackItem,
        travelDistance: CGFloat,
        at date: Date
    ) -> CombatFeedbackAnimationState {
        let elapsed = max(0, date.timeIntervalSince(item.availableAt))
        return CombatFeedbackAnimationState(
            opacity: BattleMotion.chipOpacity(elapsed: elapsed),
            verticalOffset: -Double(travelDistance)
                * BattleMotion.chipMotionProgress(elapsed: elapsed),
            scale: Double(BattleMotion.chipScale(elapsed: elapsed))
        )
    }
}
