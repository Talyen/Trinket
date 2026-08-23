import SwiftUI
import TrinketFeatureSupport

/// Policy helpers for combat feedback canvas labels. Presentation is owned by
/// `CombatFeedbackChipBridge` + always-mounted UIKit hosts.
enum CombatFeedbackOverlayPolicy {
    /// Chips to draw, ordered by action group then presentation index. Same-kind
    /// amounts are already summed in `CombatFeedbackPresenter.consolidate` — do
    /// not collapse different kinds. Lane queues own concurrent density.
    static func orderedChips(from visible: [CombatFeedbackItem]) -> [CombatFeedbackItem] {
        var order: [Int] = []
        var grouped: [Int: [CombatFeedbackItem]] = [:]
        for item in visible {
            if grouped[item.actionGroupID] == nil {
                order.append(item.actionGroupID)
            }
            grouped[item.actionGroupID, default: []].append(item)
        }
        return order.flatMap { id in
            (grouped[id] ?? []).sorted { $0.presentationIndex < $1.presentationIndex }
        }
    }
}
