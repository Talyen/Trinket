import Foundation
import SwiftUI
import TrinketCore
import TrinketDesignSystem

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
                * TrinketMotion.Battle.chipMotionProgress(elapsed: elapsed)
        )
    }
}

extension CombatFeedbackItem {
    /// Primary (trailing) visual style for the chip. Dual-icon chips expose the
    /// subject keyword / role via `chipPresentation` instead.
    var feedbackVisualStyle: Keyword.VisualStyle {
        chipPresentation.trailingTint
    }
}
