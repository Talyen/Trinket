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
        using randomNumberGenerator: inout RNG
    ) {
        let rewardItem = ItemGenerator().generate(
            id: "\(stage.id)-\(template.templateID)",
            templateID: template.templateID,
            baseType: template.baseType,
            rarity: template.rarity,
            using: &randomNumberGenerator
        )
        guard !items.contains(where: { $0.id == rewardItem.id }) else { return }
        items.append(rewardItem)
    }
}
