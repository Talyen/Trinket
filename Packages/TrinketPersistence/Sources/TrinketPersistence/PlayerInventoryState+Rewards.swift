import Foundation
import TrinketContent

public extension PlayerInventoryState {
    mutating func addRewardItem(from template: InventoryItem, for stage: Stage) {
        var randomNumberGenerator = SystemRandomNumberGenerator()
        addRewardItem(from: template, for: stage, using: &randomNumberGenerator)
    }

    mutating func addRewardItem(
        from template: InventoryItem,
        for stage: Stage,
        using _: inout some RandomNumberGenerator
    ) {
        appendUniqueItem(template.rewardInstance(for: stage.id))
    }

    mutating func appendUniqueItem(_ item: InventoryItem) {
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.append(item)
    }
}
