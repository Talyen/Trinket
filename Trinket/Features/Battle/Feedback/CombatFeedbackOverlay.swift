import SwiftUI

/// Policy helpers for combat feedback canvas labels. Presentation is owned by
/// `CombatFeedbackChipBridge` + always-mounted UIKit hosts.
enum CombatFeedbackOverlayPolicy {
    static func visibleActionGroups(from visible: [CombatFeedbackItem]) -> [CombatFeedbackActionGroup] {
        var order: [Int] = []
        var grouped: [Int: [CombatFeedbackItem]] = [:]
        for item in visible {
            if grouped[item.actionGroupID] == nil {
                order.append(item.actionGroupID)
            }
            grouped[item.actionGroupID, default: []].append(item)
        }
        return order.compactMap { id in
            guard let items = grouped[id] else { return nil }
            return CombatFeedbackActionGroup(id: id, items: items)
        }
    }

    /// One canvas chip per distinct feedback item. Same-kind amounts are already
    /// summed in `CombatFeedbackPresenter.consolidate` — do not collapse different
    /// kinds. Lane queues own concurrent density.
    static func canvasItems(from groups: [CombatFeedbackActionGroup]) -> [CombatFeedbackCanvasItem] {
        groups.flatMap { group in
            group.items
                .sorted { $0.presentationIndex < $1.presentationIndex }
                .map { CombatFeedbackCanvasItem(item: $0, label: $0.label) }
        }
    }
}

struct CombatFeedbackActionGroup: Identifiable {
    let id: Int
    let items: [CombatFeedbackItem]
}
