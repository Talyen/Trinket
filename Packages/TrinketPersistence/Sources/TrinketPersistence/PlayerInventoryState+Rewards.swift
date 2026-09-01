import Foundation
import TrinketContent

public extension PlayerInventoryState {
    mutating func addRewardItem(from template: InventoryItem, for stage: Stage) {
        appendUniqueItem(template.rewardInstance(for: stage.id))
    }

    mutating func appendUniqueItem(_ item: InventoryItem) {
        guard !InventoryDuplicatePolicy.containsDuplicate(of: item, in: items) else { return }
        items.append(item)
    }

    mutating func removeItem(id: String) {
        items.removeAll { $0.id == id }
    }
}
