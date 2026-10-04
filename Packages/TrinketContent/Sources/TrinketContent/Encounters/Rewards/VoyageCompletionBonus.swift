import TrinketCore

/// Previously earned combat rewards, captured before the final battle begins.
public struct VoyageCompletionBonus: Equatable, Sendable {
    public let gold: Int
    public let materials: [HomesteadResource: Int]

    public init(gold: Int, materials: [HomesteadResource: Int]) {
        self.gold = gold
        self.materials = materials
    }

    public func applying(to award: BattleRewardAward) -> BattleRewardAward {
        let finalMaterials = Dictionary(grouping: award.materials, by: \.resource)
        let resources = Set(materials.keys).union(finalMaterials.keys)
        let rewards = resources.sorted { $0.rawValue < $1.rawValue }.compactMap { resource -> ResourceAmount? in
            let quantities = (finalMaterials[resource] ?? []).map(\.quantity)
            let earned = quantities.reduce(0, SaturatedArithmetic.saturatingAdd)
            let total = quantities.reduce(materials[resource, default: 0], SaturatedArithmetic.saturatingAdd)
            let quantity = SaturatedArithmetic.saturatingAdd(earned, total / 5)
            return quantity > 0 ? ResourceAmount(resource, quantity) : nil
        }
        return BattleRewardAward(
            stageGold: SaturatedArithmetic.saturatingAdd(
                award.stageGold,
                SaturatedArithmetic.saturatingAdd(gold, award.goldGained) / 5,
            ),
            battleGold: award.battleGold, goldFlow: award.goldFlow,
            heroExperience: award.heroExperience, companionExperience: award.companionExperience,
            materials: rewards, items: award.items,
            rewardRemainders: award.rewardRemainders,
        )
    }
}
