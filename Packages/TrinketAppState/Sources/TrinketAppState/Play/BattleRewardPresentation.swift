import BattleEngine
import TrinketContent
import TrinketFeatureContracts
import TrinketPersistence

enum BattleRewardPresentation {
    static func make(
        inputs: BattlePreparationInputs,
        configuration: BattleRunConfiguration,
    ) -> BattlePresentationContext {
        let input = inputs.launch
        let rosterState = inputs.party.roster
        let inventoryState = inputs.party.inventory
        let homesteadEffects = inputs.party.homestead.effects
        let heroMember = configuration.hero
        let companionMember = configuration.companion
        let enemyLevel = configuration.enemyEncounterLevel ?? heroMember.progression.level
        let victoryPercent = input.experienceBonusPercent + input.victoryOnlyExperienceBonusPercent
        let heroExperience = experienceAwards(
            for: heroMember, highestLevel: rosterState.highestHeroLevel,
            enemyLevel: enemyLevel, launch: input, homesteadBonus: homesteadEffects.experienceBonusPercent,
        )
        let companionExperience = experienceAwards(
            for: companionMember, highestLevel: rosterState.highestCompanionLevel,
            enemyLevel: enemyLevel, launch: input, homesteadBonus: homesteadEffects.experienceBonusPercent,
        )
        return BattlePresentationContext(
            inventoryItems: inventoryState.items,
            stageReward: input.stageReward,
            rewardItems: resolvedRewardItems(
                stageReward: input.stageReward,
                pendingRewardItem: input.pendingRewardItem,
                additionalRewardItems: input.additionalRewardItems,
            ),
            additionalRewardItems: input.additionalRewardItems,
            pendingRewardItem: input.pendingRewardItem,
            experienceBonusPercent: input.experienceBonusPercent,
            victoryOnlyExperienceBonusPercent: input.victoryOnlyExperienceBonusPercent,
            goldFindPercent: homesteadEffects.goldFindPercent,
            goldFindFlat: homesteadEffects.goldFindFlat,
            gemsFindBonus: homesteadEffects.gemsFindBonus,
            gemsFindPercent: homesteadEffects.gemsFindPercent,
            rewardRemainders: inputs.party.homestead.rewardRemainders ?? .zero,
            stageRewardsAlreadyClaimed: input.stageRewardsAlreadyClaimed,
            hasProgressionRewards: inputs.hasProgressionRewards,
            musicStageID: nil,
            heroExperienceAward: heroExperience.victory,
            companionExperienceAward: companionExperience.victory,
            defeatHeroExperienceAward: heroExperience.defeat,
            defeatCompanionExperienceAward: companionExperience.defeat,
            materialRewards: StageCompletion.resolvedMaterialRewards(stageReward: input.stageReward ?? .empty),
            nodeModifiers: input.nodeModifiers,
            goldOverflowExperience: RewardExperiencePolicy.encounterAward(
                encounterLevel: enemyLevel, roster: rosterState,
                percent: victoryPercent,
            ),
            rewardInputs: RewardSettlementInputs(
                gold: rosterState.gold,
                reservedGold: PlayerRosterState.reservedGold(from: inputs.party.homestead.pendingProduction),
                goldLimit: PlayerRosterState.maxGoldBalance,
                heroProgression: heroMember.progression, companionProgression: companionMember.progression,
                productionDate: inputs.party.homestead.lastProductionAt,
            ),
            completionBonus: input.completionBonus,
        )
    }

    private static func experienceAwards(
        for member: BattleRunConfiguration.PartyMember,
        highestLevel: Int,
        enemyLevel: Int,
        launch: BattleLaunchInput,
        homesteadBonus: Int,
    ) -> (victory: Int, defeat: Int) {
        let victoryPercent = launch.experienceBonusPercent + launch.victoryOnlyExperienceBonusPercent
        return (
            victory: VictoryRewardApplier.battleExperienceAward(
                playerLevel: member.progression.level, enemyLevel: enemyLevel,
                highestLevel: highestLevel, experienceEarnedPercent: victoryPercent + homesteadBonus,
            ),
            defeat: VictoryRewardApplier.battleExperienceAward(
                playerLevel: member.progression.level, enemyLevel: enemyLevel,
                highestLevel: highestLevel, experienceEarnedPercent: launch.experienceBonusPercent + homesteadBonus,
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
