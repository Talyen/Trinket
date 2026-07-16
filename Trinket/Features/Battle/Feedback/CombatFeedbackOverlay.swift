import SwiftUI

/// Policy helpers for combat feedback canvas labels. Presentation is owned by
/// `CombatFeedbackChipBridge` + always-mounted UIKit hosts.
enum CombatFeedbackOverlayPolicy {
    /// A combatant only has readable feedback lanes for the newest action.
    /// Keeping older action groups alive underneath multiplies independently
    /// animated text layers without presenting additional readable information.
    static let maxSimultaneousActionGroups = 1

    static func visibleActionGroups(from visible: [CombatFeedbackItem]) -> [CombatFeedbackActionGroup] {
        var order: [Int] = []
        var grouped: [Int: [CombatFeedbackItem]] = [:]
        for item in visible {
            if grouped[item.actionGroupID] == nil {
                order.append(item.actionGroupID)
            }
            grouped[item.actionGroupID, default: []].append(item)
        }
        return order.suffix(maxSimultaneousActionGroups).compactMap { id in
            guard let items = grouped[id] else { return nil }
            return CombatFeedbackActionGroup(id: id, items: items)
        }
    }

    /// One canvas chip per distinct feedback item. Same-kind amounts are already
    /// summed in `CombatFeedbackPresenter.consolidate` — do not collapse different
    /// kinds into a single "+N Effects" label.
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
