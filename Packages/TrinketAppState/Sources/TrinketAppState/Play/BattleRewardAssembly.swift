import BattleEngine
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

enum BattleRewardAssembly {
    static func makePlan(
        inputs: BattlePreparationInputs,
        configuration: BattleRunConfiguration,
    ) -> BattleRewardPlan {
        let input = inputs.launch
        let rosterState = inputs.party.roster
        let heroMember = configuration.hero
        let companionMember = configuration.companion
        let enemyLevel = configuration.enemyEncounterLevel ?? heroMember.progression.level
        guard input.origin != nil else {
            return BattleRewardPlan(
                stageGold: 0, goldFindPercent: 0,
                goldOverflowExperience: RewardExperiencePolicy.encounterAward(encounterLevel: enemyLevel, roster: rosterState),
                heroExperience: 0, companionExperience: 0, materials: [], items: [],
            )
        }
        return BattleRewardPlan.forEncounter(
            party: (heroMember.progression, companionMember.progression),
            highestLevels: (rosterState.highestHeroLevel, rosterState.highestCompanionLevel),
            encounterLevel: enemyLevel,
            homestead: inputs.party.homestead,
            stageGold: input.stageReward?.gold ?? 0,
            materials: input.stageReward?.resolvedMaterials ?? [],
            items: resolvedRewardItems(
                stageReward: input.stageReward, pendingRewardItem: input.pendingRewardItem,
                additionalRewardItems: input.additionalRewardItems,
            ),
            experienceEarnedPercent: input.experienceBonusPercent,
            victoryOnlyExperienceBonusPercent: input.victoryOnlyExperienceBonusPercent,
            victoryGoldBonusPercent: SaturatedArithmetic.saturatingAdd(
                heroMember.modifiers.triggers.victoryGoldBonusPercent,
                companionMember.modifiers.triggers.victoryGoldBonusPercent,
            ),
            rewardsAlreadyClaimed: input.stageRewardsAlreadyClaimed,
            completionBonus: input.completionBonus,
        )
    }

    static func makePresentation(
        inputs: BattlePreparationInputs,
        configuration: BattleRunConfiguration,
        rewardPlan: BattleRewardPlan,
    ) -> BattlePresentationContext {
        BattlePresentationContext(
            inventoryItems: inputs.party.inventory.items,
            rewardPlan: rewardPlan,
            stageRewardsAlreadyClaimed: inputs.launch.stageRewardsAlreadyClaimed,
            hasProgressionRewards: inputs.launch.origin != nil,
            musicStageID: nil,
            nodeModifiers: inputs.launch.nodeModifiers,
            rewardInputs: RewardSettlementInputs(
                gold: inputs.party.roster.gold,
                reservedGold: PlayerRosterState.reservedGold(from: inputs.party.homestead.pendingProduction),
                goldLimit: PlayerRosterState.maxGoldBalance,
                heroProgression: configuration.hero.progression,
                companionProgression: configuration.companion.progression,
                productionDate: inputs.party.homestead.lastProductionAt,
                rewardRemainders: inputs.party.homestead.rewardRemainders ?? .zero,
            ),
        )
    }

    private static func resolvedRewardItems(
        stageReward: StageReward?,
        pendingRewardItem: InventoryItem?,
        additionalRewardItems: [InventoryItem],
    ) -> [InventoryItem] {
        if let pendingRewardItem {
            return [pendingRewardItem] + additionalRewardItems
        }
        guard let stageReward else { return [] }
        return stageReward.itemTemplateIDs.compactMap(GameContent.itemTemplate(matching:))
    }
}
