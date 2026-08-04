import BattleEngine
import Foundation
import TrinketBattleContracts
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
@testable import TrinketBattleFeature

/// Direct fixture for the launch-baked battle run DTO.
///
/// BattleFeature tests provide every policy result explicitly. This helper only
/// packages those values into `BattleRunConfiguration` and never resolves
/// builds, rewards, progression, or homestead effects.
@MainActor
enum BattleRunConfigurationTestSupport {
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
        enemyModifiers: CombatModifierProfile = .zero,
        inventoryItems: [InventoryItem] = [],
        stageReward: StageReward? = nil,
        rewardItems: [InventoryItem] = [],
        pendingRewardItem: InventoryItem? = nil,
        experienceBonusPercent: Int = 0,
        goldFindPercent: Int = 0,
        stageRewardsAlreadyClaimed: Bool = false,
        defeatPrimaryAction: BattleDefeatPrimaryAction = .restart,
        hasProgressionRewards: Bool = false,
        musicStageID: String? = nil,
        heroExperienceAward: Int = 0,
        companionExperienceAward: Int = 0,
        materialRewards: [ResourceAmount] = []
    ) -> (configuration: BattleRunConfiguration, presentation: BattlePresentationContext) {
        let configuration = BattleRunConfiguration(
            runKey: runKey,
            rngSeed: rngSeed,
            hero: BattleRunConfiguration.PartyMember(
                combatant: hero,
                progression: heroProgression,
                equipmentLoadout: heroEquipmentLoadout,
                modifiers: heroModifiers
            ),
            companion: BattleRunConfiguration.PartyMember(
                combatant: companion,
                progression: companionProgression,
                equipmentLoadout: companionEquipmentLoadout,
                modifiers: companionModifiers
            ),
            enemy: enemy ?? Enemy.fallbackCombatant,
            enemyEncounterLevel: enemyEncounterLevel,
            enemyModifiers: enemyModifiers
        )
        let presentation = BattlePresentationContext(
            inventoryItems: inventoryItems,
            stageReward: stageReward,
            rewardItems: rewardItems,
            pendingRewardItem: pendingRewardItem,
            experienceBonusPercent: experienceBonusPercent,
            goldFindPercent: goldFindPercent,
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            defeatPrimaryAction: defeatPrimaryAction,
            hasProgressionRewards: hasProgressionRewards,
            musicStageID: musicStageID,
            heroExperienceAward: heroExperienceAward,
            companionExperienceAward: companionExperienceAward,
            materialRewards: materialRewards
        )
        return (configuration, presentation)
    }
}
