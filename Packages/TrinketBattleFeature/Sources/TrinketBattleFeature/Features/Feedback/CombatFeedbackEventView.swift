import Foundation
import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct CombatFeedbackCanvasItem: Identifiable {
    let item: CombatFeedbackItem

    var id: Int {
        item.id
    }

    var label: CombatFeedbackChipLabel {
        item.label
    }

    /// Derived for tests and debug tooling.
    var text: String {
        label.displayString
    }
}

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
            opacity: TrinketMotion.Battle.chipOpacity(elapsed: elapsed),
            verticalOffset: -Double(travelDistance)
                * TrinketMotion.Battle.chipMotionProgress(elapsed: elapsed),
            scale: Double(TrinketMotion.Battle.chipScale(elapsed: elapsed))
        )
    }
}
