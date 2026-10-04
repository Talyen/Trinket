import TrinketCore

public struct BattleRewardPlan: Equatable, Sendable {
    public let completionBonus: VoyageCompletionBonus?
    public let stageGold: Int
    public let goldFindPercent: Int
    public let goldFindFlat: Int
    public let gemsFindPercent: Int
    public let initialRewardRemainders: HomesteadRewardRemainders
    public let gemsFindBonus: Int
    public let goldOverflowExperience: Int
    public let heroExperience: Int
    public let companionExperience: Int
    public let defeatHeroExperience: Int
    public let defeatCompanionExperience: Int
    public let materials: [ResourceAmount]
    public let items: [InventoryItem]

    public init(
        stageGold: Int,
        goldFindPercent: Int,
        goldFindFlat: Int = 0,
        gemsFindBonus: Int = 0,
        gemsFindPercent: Int = 0,
        initialRewardRemainders: HomesteadRewardRemainders = .zero,
        goldOverflowExperience: Int = 0,
        heroExperience: Int,
        companionExperience: Int,
        defeatHeroExperience: Int? = nil,
        defeatCompanionExperience: Int? = nil,
        materials: [ResourceAmount],
        items: [InventoryItem],
        completionBonus: VoyageCompletionBonus? = nil,
    ) {
        self.completionBonus = completionBonus
        self.stageGold = max(0, stageGold)
        self.goldFindPercent = goldFindPercent
        self.goldFindFlat = goldFindFlat
        self.gemsFindBonus = gemsFindBonus
        self.gemsFindPercent = gemsFindPercent
        self.initialRewardRemainders = initialRewardRemainders
        self.goldOverflowExperience = goldOverflowExperience
        self.heroExperience = heroExperience
        self.companionExperience = companionExperience
        self.defeatHeroExperience = defeatHeroExperience ?? heroExperience
        self.defeatCompanionExperience = defeatCompanionExperience ?? companionExperience
        self.materials = materials
        self.items = items
    }

    public func settleDefeat(progress: BattleDefeatProgress, inputs: RewardSettlementInputs) -> BattleRewardSettlement {
        let award = BattleRewardAward(
            stageGold: 0, battleGold: 0, goldFlow: .init(),
            heroExperience: ExperienceScaling.cappedAward(
                progress.experienceAward(from: defeatHeroExperience), for: inputs.heroProgression,
            ),
            companionExperience: ExperienceScaling.cappedAward(
                progress.experienceAward(from: defeatCompanionExperience), for: inputs.companionProgression,
            ),
            materials: [], items: [],
            rewardRemainders: inputs.rewardRemainders,
        )
        return BattleRewardSettlement(inputs: inputs, award: award, replacementExperience: 0)
    }

    public func resolve(
        battleGold: BattleGoldFlow,
        materials: [ResourceAmount]? = nil,
        includingCompletionBonus: Bool = true,
        rewardRemainders: HomesteadRewardRemainders? = nil,
    ) -> BattleRewardAward {
        let baseGold = SaturatedArithmetic.saturatingAdd(stageGold, battleGold.gained)
        var remainders = rewardRemainders ?? initialRewardRemainders
        let effects = HomesteadEffects(
            heroModifiers: [], companionModifiers: [], astralChanceBonusPercent: 0,
            goldFindPercent: goldFindPercent, goldFindFlat: goldFindFlat,
            gemsFindBonus: gemsFindBonus, gemsFindPercent: gemsFindPercent,
        )
        let gained = effects.adjustedGold(baseGold, remainders: &remainders)
        let stage = min(stageGold, gained)
        let adjustedMaterials = effects.adjustedMaterials(materials ?? self.materials, remainders: &remainders)
        let award = BattleRewardAward(
            stageGold: stage,
            battleGold: SaturatedArithmetic.saturatingSub(
                SaturatedArithmetic.saturatingSub(gained, stage), battleGold.spent,
            ),
            goldFlow: battleGold, heroExperience: heroExperience, companionExperience: companionExperience,
            materials: adjustedMaterials, items: items,
            rewardRemainders: remainders,
        )
        return includingCompletionBonus ? completionBonus?.applying(to: award) ?? award : award
    }

    public func settle(
        battleGold: BattleGoldFlow,
        inputs: RewardSettlementInputs,
        materials: [ResourceAmount]? = nil,
    ) -> BattleRewardSettlement {
        let resolved = resolve(battleGold: battleGold, materials: materials, rewardRemainders: inputs.rewardRemainders)
        let overflow = RewardSettlementPolicy.goldOverflow(
            gains: resolved.goldGained, spending: battleGold.spent, capacity: inputs.goldCapacity,
        )
        let grantedGold = SaturatedArithmetic.saturatingSub(resolved.goldGained, overflow)
        let grantedStageGold = min(resolved.stageGold, grantedGold)
        let compensation = RewardSettlementPolicy.overflowExperience(
            goldOverflowExperience, overflow: overflow, gains: resolved.goldGained,
        )
        let award = BattleRewardAward(
            stageGold: grantedStageGold,
            battleGold: SaturatedArithmetic.saturatingSub(
                SaturatedArithmetic.saturatingSub(grantedGold, grantedStageGold), battleGold.spent,
            ),
            goldFlow: battleGold,
            heroExperience: ExperienceScaling.cappedAward(
                SaturatedArithmetic.saturatingAdd(resolved.heroExperience, compensation),
                for: inputs.heroProgression,
            ),
            companionExperience: ExperienceScaling.cappedAward(
                SaturatedArithmetic.saturatingAdd(resolved.companionExperience, compensation),
                for: inputs.companionProgression,
            ),
            materials: resolved.materials, items: resolved.items,
            rewardRemainders: resolved.rewardRemainders,
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

    public var rewardRemainders: HomesteadRewardRemainders?

    public var goldDelta: Int {
        SaturatedArithmetic.saturatingAdd(stageGold, battleGold)
    }

    public var goldGained: Int {
        SaturatedArithmetic.saturatingAdd(goldDelta, goldFlow.spent)
    }
}
