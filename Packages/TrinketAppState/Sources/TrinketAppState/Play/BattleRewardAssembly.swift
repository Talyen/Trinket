import BattleEngine
import TrinketContent
import TrinketFeatureContracts
import TrinketPersistence

enum BattleRewardAssembly {
    static func makePlan(
        inputs: BattlePreparationInputs,
        configuration: BattleRunConfiguration,
    ) -> BattleRewardPlan {
        let input = inputs.launch
        let rosterState = inputs.party.roster
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
        guard input.origin != nil else {
            return BattleRewardPlan(
                stageGold: 0, goldFindPercent: 0,
                goldOverflowExperience: RewardExperiencePolicy.encounterAward(encounterLevel: enemyLevel, roster: rosterState),
                heroExperience: 0, companionExperience: 0, materials: [], items: [],
            )
        }
        let claimed = input.stageRewardsAlreadyClaimed
        return BattleRewardPlan(
            stageGold: claimed ? 0 : input.stageReward?.gold ?? 0,
            goldFindPercent: homesteadEffects.goldFindPercent,
            goldFindFlat: homesteadEffects.goldFindFlat,
            gemsFindBonus: homesteadEffects.gemsFindBonus,
            gemsFindPercent: homesteadEffects.gemsFindPercent,
            initialRewardRemainders: inputs.party.homestead.rewardRemainders ?? .zero,
            goldOverflowExperience: RewardExperiencePolicy.encounterAward(
                encounterLevel: enemyLevel, roster: rosterState, percent: victoryPercent,
            ),
            heroExperience: claimed ? 0 : heroExperience.victory,
            companionExperience: claimed ? 0 : companionExperience.victory,
            defeatHeroExperience: claimed ? 0 : heroExperience.defeat,
            defeatCompanionExperience: claimed ? 0 : companionExperience.defeat,
            materials: claimed ? [] : StageCompletion.resolvedMaterialRewards(stageReward: input.stageReward ?? .empty),
            items: claimed ? [] : resolvedRewardItems(
                stageReward: input.stageReward, pendingRewardItem: input.pendingRewardItem,
                additionalRewardItems: input.additionalRewardItems,
            ),
            completionBonus: claimed ? nil : input.completionBonus,
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
            ),
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
