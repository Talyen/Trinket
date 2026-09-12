import TrinketCore

public struct BattleRewardPlan: Equatable, Sendable {
    public let stageGold: Int
    public let goldFindPercent: Int
    public let goldOverflowExperience: Int
    public let heroExperience: Int
    public let companionExperience: Int
    public let materials: [ResourceAmount]
    public let items: [InventoryItem]

    public init(
        stageGold: Int,
        goldFindPercent: Int,
        goldOverflowExperience: Int = 0,
        heroExperience: Int,
        companionExperience: Int,
        materials: [ResourceAmount],
        items: [InventoryItem],
    ) {
        self.stageGold = max(0, stageGold)
        self.goldFindPercent = goldFindPercent
        self.goldOverflowExperience = goldOverflowExperience
        self.heroExperience = heroExperience
        self.companionExperience = companionExperience
        self.materials = materials
        self.items = items
    }

    public func resolve(battleGold: BattleGoldFlow, materials: [ResourceAmount]? = nil) -> BattleRewardAward {
        let gained = max(0, CombatRounding.scaled(stageGold + battleGold.gained, byPercent: goldFindPercent))
        let stage = min(stageGold, gained)
        return BattleRewardAward(
            stageGold: stage, battleGold: gained - stage - battleGold.spent,
            goldFlow: battleGold, heroExperience: heroExperience, companionExperience: companionExperience,
            materials: materials ?? self.materials, items: items,
        )
    }

    public func settle(
        battleGold: BattleGoldFlow,
        inputs: RewardSettlementInputs,
        materials: [ResourceAmount]? = nil,
    ) -> BattleRewardSettlement {
        let resolved = resolve(battleGold: battleGold, materials: materials)
        let replacesGold = RewardSettlementPolicy.replacesGold(
            gains: resolved.goldGained, spending: battleGold.spent, capacity: inputs.goldCapacity,
        )
        let compensation = replacesGold ? goldOverflowExperience : 0
        let award = BattleRewardAward(
            stageGold: replacesGold ? 0 : resolved.stageGold,
            battleGold: replacesGold ? -battleGold.spent : resolved.battleGold,
            goldFlow: battleGold,
            heroExperience: ExperienceScaling.cappedAward(resolved.heroExperience + compensation, for: inputs.heroProgression),
            companionExperience: ExperienceScaling.cappedAward(
                resolved.companionExperience + compensation,
                for: inputs.companionProgression,
            ),
            materials: resolved.materials, items: resolved.items,
        )
        return BattleRewardSettlement(inputs: inputs, award: award, replacementExperience: compensation)
    }
}

public struct BattleRewardAward: Equatable, Sendable {
    public let stageGold: Int
    public let battleGold: Int
    public let goldFlow: BattleGoldFlow
    public let heroExperience: Int
    public let companionExperience: Int
    public let materials: [ResourceAmount]
    public let items: [InventoryItem]

    public var goldDelta: Int {
        stageGold + battleGold
    }

    public var goldGained: Int {
        goldDelta + goldFlow.spent
    }
}
