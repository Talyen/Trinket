import SwiftUI

struct CombatFeedbackOverlay: View {
    let items: [CombatFeedbackItem]

    var body: some View {
        ZStack {
            ForEach(actionGroups(from: items)) { group in
                CombatFeedbackActionGroupView(items: group.items)
            }
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }

    private func actionGroups(from visible: [CombatFeedbackItem]) -> [CombatFeedbackActionGroup] {
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
}

private struct CombatFeedbackActionGroup: Identifiable {
    let id: Int
    let items: [CombatFeedbackItem]
}

private struct CombatFeedbackActionGroupView: View {
    let items: [CombatFeedbackItem]

    var body: some View {
        ZStack {
            ForEach(visibleItems) { item in
                CombatFeedbackEventView(item: item)
            }

            if hiddenCount > 0, let anchor = visibleItems.first {
                CombatFeedbackEventView(
                    item: anchor,
                    role: .overflow,
                    laneIndex: 3,
                    textOverride: hiddenCount == 1 ? "+1 Effect" : "+\(hiddenCount) Effects"
                )
            }
        }
    }

    private var visibleItems: [CombatFeedbackItem] {
        items
            .filter { $0.presentationIndex < 3 }
            .sorted { $0.presentationIndex < $1.presentationIndex }
    }

    private var hiddenCount: Int {
        max(0, (items.first?.groupResultCount ?? 0) - 3)
    }
}
