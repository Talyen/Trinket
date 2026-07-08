import Foundation
import TrinketContent

public extension PlayerInventoryState {
    mutating func addRewardItem(from template: InventoryItem, for stage: Stage) {
        var randomNumberGenerator = SystemRandomNumberGenerator()
        addRewardItem(from: template, for: stage, using: &randomNumberGenerator)
    }

    mutating func addRewardItem<RNG: RandomNumberGenerator>(
        from template: InventoryItem,
        for stage: Stage,
        using _: inout RNG
    ) {
        let rewardItem = template.rewardInstance(for: stage.id)
        guard !items.contains(where: { $0.id == rewardItem.id }) else { return }
        items.append(rewardItem)
    }
}
