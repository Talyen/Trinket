import SwiftUI
import TrinketFeatureSupport

enum CombatFeedbackOverlayPolicy {
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
