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
        var totals = materials
        var rewards: [HomesteadResource: Int] = [:]
        for reward in award.materials {
            totals[reward.resource, default: 0] = SaturatedArithmetic.saturatingAdd(
                totals[reward.resource, default: 0], reward.quantity,
            )
            rewards[reward.resource, default: 0] = SaturatedArithmetic.saturatingAdd(
                rewards[reward.resource, default: 0], reward.quantity,
            )
        }
        for (resource, quantity) in totals {
            rewards[resource, default: 0] = SaturatedArithmetic.saturatingAdd(
                rewards[resource, default: 0], quantity / 5,
            )
        }
        return BattleRewardAward(
            stageGold: SaturatedArithmetic.saturatingAdd(
                award.stageGold,
                SaturatedArithmetic.saturatingAdd(gold, award.goldGained) / 5,
            ),
            battleGold: award.battleGold, goldFlow: award.goldFlow,
            heroExperience: award.heroExperience, companionExperience: award.companionExperience,
            materials: rewards.keys.sorted { $0.rawValue < $1.rawValue }.compactMap { resource in
                let quantity = rewards[resource, default: 0]
                return quantity > 0 ? ResourceAmount(resource, quantity) : nil
            }, items: award.items,
        )
    }
}
