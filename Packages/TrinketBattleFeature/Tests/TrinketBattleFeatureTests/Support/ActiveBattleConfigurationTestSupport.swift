import BattleEngine
import TrinketContent
import TrinketCore
import TrinketPersistence
@testable import TrinketBattleFeature

/// Test-only bake mirror of `PlayBattleLaunch.assembleConfiguration`.
/// Production BattleFeature never assembles from live save slices.
@MainActor
enum ActiveBattleConfigurationTestSupport {
    static func make(
        runKey: BattleRunKey? = nil,
        rngSeed: UInt64 = 0,
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        roster: PlayerRosterState = .initial,
        inventory: PlayerInventoryState = .initial,
        homestead: PlayerHomesteadState = .freshStart,
        stageReward: StageReward? = nil,
        experienceBonusPercent: Int = 0,
        pendingRewardItem: InventoryItem? = nil,
        stageRewardsAlreadyClaimed: Bool = false,
        universalModifiers: [AffixModifier] = [],
        defeatPrimaryAction: BattleDefeatPrimaryAction = .restart,
        hasProgressionRewards: Bool = false,
        musicStageID: String? = nil
    ) throws -> ActiveBattleConfiguration {
        let enemyBuild = resolvedEnemyBuild(enemy: enemy)
        var enemyModifiers = enemyBuild.modifiers
        enemyModifiers.merge(universalModifiers)
        let homesteadEffects = homestead.effects
        let heroMember = partyMember(
            combatant: hero,
            rosterState: roster,
            inventoryState: inventory,
            additionalModifiers: homesteadEffects.heroModifiers + universalModifiers
        )
        let companionMember = partyMember(
            combatant: companion,
            rosterState: roster,
            inventoryState: inventory,
            additionalModifiers: homesteadEffects.companionModifiers + universalModifiers
        )
        let resolvedStageReward = stageReward ?? StageReward(gold: 0, itemTemplateIDs: [])
        let enemyLevel = enemyEncounterLevel ?? heroMember.progression.level
        return ActiveBattleConfiguration(
            runKey: runKey,
            rngSeed: rngSeed,
            hero: heroMember,
            companion: companionMember,
            enemy: enemyBuild.combatant,
            enemyEncounterLevel: enemyEncounterLevel,
            highestHeroLevel: roster.highestHeroLevel,
            highestCompanionLevel: roster.highestCompanionLevel,
            enemyModifiers: enemyModifiers,
            inventoryState: inventory,
            stageReward: stageReward,
            rewardItems: resolvedRewardItems(
                stageReward: stageReward,
                pendingRewardItem: pendingRewardItem
            ),
            pendingRewardItem: pendingRewardItem,
            experienceBonusPercent: experienceBonusPercent,
            goldFindPercent: homesteadEffects.goldFindPercent,
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            universalModifiers: universalModifiers,
            defeatPrimaryAction: defeatPrimaryAction,
            hasProgressionRewards: hasProgressionRewards,
            musicStageID: musicStageID,
            heroExperienceAward: StageCompletion.battleExperienceAward(
                playerLevel: heroMember.progression.level,
                enemyLevel: enemyLevel,
                highestLevel: roster.highestHeroLevel,
                xpPercent: experienceBonusPercent
            ),
            companionExperienceAward: StageCompletion.battleExperienceAward(
                playerLevel: companionMember.progression.level,
                enemyLevel: enemyLevel,
                highestLevel: roster.highestCompanionLevel,
                xpPercent: experienceBonusPercent
            ),
            materialRewards: StageCompletion.resolvedMaterialRewards(stageReward: resolvedStageReward)
        )
    }

    private static func partyMember(
        combatant: Combatant,
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState,
        additionalModifiers: [AffixModifier] = []
    ) -> ActiveBattleConfiguration.PartyMember {
        let progression = rosterState.progression(for: combatant)
        let equipmentLoadout = rosterState.equipmentLoadout(for: combatant)
        let build = CombatBuildResolver.build(
            combatant: CombatantLevelScaler.scale(
                combatant: combatant,
                level: progression.level
            ),
            equipmentLoadout: equipmentLoadout,
            inventory: inventoryState.items,
            additionalModifiers: additionalModifiers
        )
        return ActiveBattleConfiguration.PartyMember(
            combatant: build.combatant,
            progression: progression,
            equipmentLoadout: equipmentLoadout,
            modifiers: build.modifiers
        )
    }

    private static func resolvedEnemyBuild(
        enemy: Combatant?
    ) -> CombatBuild {
        guard let enemy else {
            return CombatBuild(combatant: Enemy.fallbackCombatant, modifiers: .zero)
        }
        if let catalogEnemy = GameContent.enemy(matching: enemy.id) {
            let catalogBuild = CombatBuildResolver.build(enemy: catalogEnemy)
            return CombatBuild(combatant: enemy, modifiers: catalogBuild.modifiers)
        }
        return CombatBuild(combatant: enemy, modifiers: .zero)
    }

    private static func resolvedRewardItems(
        stageReward: StageReward?,
        pendingRewardItem: InventoryItem?
    ) -> [InventoryItem] {
        if let pendingRewardItem {
            return [pendingRewardItem]
        }
        guard let stageReward else { return [] }
        return stageReward.itemTemplateIDs.compactMap(GameContent.itemTemplate(matching:))
    }
}
