import SwiftUI

struct CombatFeedbackOverlay: View {
    let items: [CombatFeedbackItem]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let groups = CombatFeedbackOverlayPolicy.visibleActionGroups(from: items)
        let canvasItem = CombatFeedbackOverlayPolicy.canvasItems(from: groups).first
        CombatFeedbackRasterSlot(
            canvasItem: canvasItem,
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .battleFramePacingSignpost(
            BattleFramePacingSignposts.Name.combatFeedback,
            isActive: !items.isEmpty
        )
    }
}

enum CombatFeedbackOverlayPolicy {
    /// A combatant only has four readable feedback lanes. Keeping older action groups
    /// alive underneath the newest group multiplies independently animated text layers
    /// without presenting additional readable information.
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

    static func canvasItems(from groups: [CombatFeedbackActionGroup]) -> [CombatFeedbackCanvasItem] {
        groups.compactMap { group in
            guard let headline = group.items.first else { return nil }
            let additionalCount = max(0, headline.groupResultCount - 1)
            let text: String
            if additionalCount == 0 {
                text = headline.text
            } else {
                let suffix = additionalCount == 1 ? "+1 Effect" : "+\(additionalCount) Effects"
                text = "\(headline.text)  \(suffix)"
            }
            return CombatFeedbackCanvasItem(item: headline, text: text)
        }
    }
}

struct CombatFeedbackActionGroup: Identifiable {
    let id: Int
    let items: [CombatFeedbackItem]
}
