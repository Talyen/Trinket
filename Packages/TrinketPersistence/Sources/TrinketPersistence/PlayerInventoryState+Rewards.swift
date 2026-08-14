import Foundation
import TrinketContent

public extension PlayerInventoryState {
    /// Grants a deterministic per-stage instance of a catalog template.
    /// Reward identity is `stageID-templateID`; no randomness is involved.
    mutating func addRewardItem(from template: InventoryItem, for stage: Stage) {
        appendUniqueItem(template.rewardInstance(for: stage.id))
    }

    mutating func appendUniqueItem(_ item: InventoryItem) {
        guard !items.contains(where: {
            $0.id == item.id || (item.isTrinket && $0.isTrinket && $0.templateID == item.templateID)
        }) else { return }
        items.append(item)
    }

    mutating func removeItem(id: String) {
        items.removeAll { $0.id == id }
    }
}
