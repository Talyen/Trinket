import TrinketCore

public struct BattleRewardPlan: Equatable, Sendable {
    public let stageGold: Int
    public let goldFindPercent: Int
    public let heroExperience: Int
    public let companionExperience: Int
    public let materials: [ResourceAmount]
    public let items: [InventoryItem]

    public init(
        stageGold: Int,
        goldFindPercent: Int,
        heroExperience: Int,
        companionExperience: Int,
        materials: [ResourceAmount],
        items: [InventoryItem],
    ) {
        self.stageGold = max(0, stageGold)
        self.goldFindPercent = goldFindPercent
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

    fileprivate init(
        stageGold: Int,
        battleGold: Int,
        goldFlow: BattleGoldFlow,
        heroExperience: Int,
        companionExperience: Int,
        materials: [ResourceAmount],
        items: [InventoryItem],
    ) {
        self.stageGold = stageGold
        self.battleGold = battleGold
        self.goldFlow = goldFlow
        self.heroExperience = heroExperience
        self.companionExperience = companionExperience
        self.materials = materials
        self.items = items
    }
}
