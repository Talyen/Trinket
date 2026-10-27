import TrinketCore

/// Previously earned combat rewards, captured before the final battle begins.
public struct VoyageCompletionBonus: Equatable, Sendable {
    public let gold: Int
    public let materials: [HomesteadResource: Int]

    public init(gold: Int, materials: [HomesteadResource: Int]) {
        self.gold = gold
        self.materials = materials
    }

    private static func fifth(of first: Int, followedBy amounts: some Sequence<Int>) -> Int {
        var whole = max(0, first) / 5
        var remainder = max(0, first) % 5
        for amount in amounts where amount > 0 {
            whole = SaturatedArithmetic.saturatingAdd(whole, amount / 5)
            remainder += amount % 5
            whole = SaturatedArithmetic.saturatingAdd(whole, remainder / 5)
            remainder %= 5
        }
        return whole
    }

    public func applying(to award: BattleRewardAward) -> BattleRewardAward {
        let finalMaterials = Dictionary(grouping: award.materials, by: \.resource)
        let resources = Set(materials.keys).union(finalMaterials.keys)
        let rewards = resources.sorted { $0.rawValue < $1.rawValue }.compactMap { resource -> ResourceAmount? in
            let quantities = (finalMaterials[resource] ?? []).lazy.map(\.quantity)
            let earned = quantities.reduce(0, SaturatedArithmetic.saturatingAdd)
            let bonus = Self.fifth(of: materials[resource, default: 0], followedBy: quantities)
            let quantity = SaturatedArithmetic.saturatingAdd(earned, bonus)
            return quantity > 0 ? ResourceAmount(resource, quantity) : nil
        }
        return BattleRewardAward(
            stageGold: SaturatedArithmetic.saturatingAdd(
                award.stageGold,
                Self.fifth(of: gold, followedBy: CollectionOfOne(award.goldGained)),
            ),
            battleGold: award.battleGold, goldFlow: award.goldFlow,
            heroExperience: award.heroExperience, companionExperience: award.companionExperience,
            materials: rewards, items: award.items,
            rewardRemainders: award.rewardRemainders,
        )
    }
}
