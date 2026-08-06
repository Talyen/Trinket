import BattleEngine
import Foundation
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

extension PlayBattleLaunch {
    static func assembleLaunch(
        runKey: BattleRunKey? = nil,
        rngSeed: UInt64,
        hero: Combatant,
        companion: Combatant,
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState,
        homesteadState: PlayerHomesteadState = .freshStart,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        stageReward: StageReward? = nil,
        experienceBonusPercent: Int = 0,
        pendingRewardItem: InventoryItem? = nil,
        stageRewardsAlreadyClaimed: Bool = false,
        universalModifiers: [AffixModifier] = [],
        defeatPrimaryAction: BattleDefeatPrimaryAction = .restart,
        hasProgressionRewards: Bool = false,
        musicStageID: String? = nil
    ) -> (configuration: BattleRunConfiguration, presentation: BattlePresentationContext, universalModifiers: [AffixModifier]) {
        let enemyBuild = resolvedEnemyBuild(enemy: enemy)
        var enemyModifiers = enemyBuild.modifiers
        enemyModifiers.merge(universalModifiers)
        let homesteadEffects = homesteadState.effects
        let heroMember = partyMember(
            combatant: hero,
            rosterState: rosterState,
            inventoryState: inventoryState,
            additionalModifiers: homesteadEffects.heroModifiers + universalModifiers
        )
        let companionMember = partyMember(
            combatant: companion,
            rosterState: rosterState,
            inventoryState: inventoryState,
            additionalModifiers: homesteadEffects.companionModifiers + universalModifiers
        )
        let resolvedStageReward = stageReward ?? StageReward(gold: 0, itemTemplateIDs: [])
        let enemyLevel = enemyEncounterLevel ?? heroMember.progression.level
        let configuration = BattleRunConfiguration(
            runKey: runKey,
            rngSeed: rngSeed,
            hero: heroMember,
            companion: companionMember,
            enemy: enemyBuild.combatant,
            enemyEncounterLevel: enemyEncounterLevel,
            enemyModifiers: enemyModifiers
        )
        let presentation = BattlePresentationContext(
            inventoryItems: inventoryState.items,
            stageReward: stageReward,
            rewardItems: resolvedRewardItems(
                stageReward: stageReward,
                pendingRewardItem: pendingRewardItem
            ),
            pendingRewardItem: pendingRewardItem,
            experienceBonusPercent: experienceBonusPercent,
            goldFindPercent: homesteadEffects.goldFindPercent,
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            defeatPrimaryAction: defeatPrimaryAction,
            hasProgressionRewards: hasProgressionRewards,
            musicStageID: musicStageID,
            heroExperienceAward: StageCompletion.battleExperienceAward(
                playerLevel: heroMember.progression.level,
                enemyLevel: enemyLevel,
                highestLevel: rosterState.highestHeroLevel,
                xpPercent: experienceBonusPercent
            ),
            companionExperienceAward: StageCompletion.battleExperienceAward(
                playerLevel: companionMember.progression.level,
                enemyLevel: enemyLevel,
                highestLevel: rosterState.highestCompanionLevel,
                xpPercent: experienceBonusPercent
            ),
            materialRewards: StageCompletion.resolvedMaterialRewards(stageReward: resolvedStageReward)
        )
        return (configuration, presentation, universalModifiers)
    }

    private static func partyMember(
        combatant: Combatant,
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState,
        additionalModifiers: [AffixModifier] = []
    ) -> BattleRunConfiguration.PartyMember {
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
        return BattleRunConfiguration.PartyMember(
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
        // Preserve the encounter combatant (already scaled by launch).
        // Only resolve trait modifiers from the catalog entry — do not replace scaled stats
        // with the catalog base combatant.
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
