import BattleEngine
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
@testable import TrinketBattleFeature

/// Direct fixture for the launch-baked battle DTO.
///
/// BattleFeature tests provide every policy result explicitly. This helper only
/// packages those values into `ActiveBattleConfiguration` and never resolves
/// builds, rewards, progression, or homestead effects.
@MainActor
enum ActiveBattleConfigurationTestSupport {
    static func make(
        runKey: BattleRunKey? = nil,
        rngSeed: UInt64 = 0,
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        heroProgression: CombatantProgression = .initial,
        companionProgression: CombatantProgression = .initial,
        heroEquipmentLoadout: EquipmentLoadout = .init(),
        companionEquipmentLoadout: EquipmentLoadout = .init(),
        heroModifiers: CombatModifierProfile = .zero,
        companionModifiers: CombatModifierProfile = .zero,
        highestHeroLevel: Int = 1,
        highestCompanionLevel: Int = 1,
        enemyModifiers: CombatModifierProfile = .zero,
        inventoryItems: [InventoryItem] = [],
        stageReward: StageReward? = nil,
        rewardItems: [InventoryItem] = [],
        pendingRewardItem: InventoryItem? = nil,
        experienceBonusPercent: Int = 0,
        goldFindPercent: Int = 0,
        stageRewardsAlreadyClaimed: Bool = false,
        universalModifiers: [AffixModifier] = [],
        defeatPrimaryAction: BattleDefeatPrimaryAction = .restart,
        hasProgressionRewards: Bool = false,
        musicStageID: String? = nil,
        heroExperienceAward: Int = 0,
        companionExperienceAward: Int = 0,
        materialRewards: [ResourceAmount] = []
    ) -> ActiveBattleConfiguration {
        ActiveBattleConfiguration(
            runKey: runKey,
            rngSeed: rngSeed,
            hero: ActiveBattleConfiguration.PartyMember(
                combatant: hero,
                progression: heroProgression,
                equipmentLoadout: heroEquipmentLoadout,
                modifiers: heroModifiers
            ),
            companion: ActiveBattleConfiguration.PartyMember(
                combatant: companion,
                progression: companionProgression,
                equipmentLoadout: companionEquipmentLoadout,
                modifiers: companionModifiers
            ),
            enemy: enemy ?? Enemy.fallbackCombatant,
            enemyEncounterLevel: enemyEncounterLevel,
            highestHeroLevel: highestHeroLevel,
            highestCompanionLevel: highestCompanionLevel,
            enemyModifiers: enemyModifiers,
            inventoryItems: inventoryItems,
            stageReward: stageReward,
            rewardItems: rewardItems,
            pendingRewardItem: pendingRewardItem,
            experienceBonusPercent: experienceBonusPercent,
            goldFindPercent: goldFindPercent,
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            universalModifiers: universalModifiers,
            defeatPrimaryAction: defeatPrimaryAction,
            hasProgressionRewards: hasProgressionRewards,
            musicStageID: musicStageID,
            heroExperienceAward: heroExperienceAward,
            companionExperienceAward: companionExperienceAward,
            materialRewards: materialRewards
        )
    }
}
