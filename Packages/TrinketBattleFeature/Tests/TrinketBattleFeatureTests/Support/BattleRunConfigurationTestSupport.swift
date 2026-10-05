import BattleEngine
import Foundation
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
import TrinketFeatureContracts
@testable import TrinketBattleFeature

@MainActor
enum BattleRunConfigurationTestSupport {
    static func make(
        runKey: BattleRunKey? = nil,
        rngSeed: UInt64 = CombatantFixtures.deterministicBattleSeed,
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
        goldFindPercent: Int = 0,
        stageRewardsAlreadyClaimed: Bool = false,
        hasProgressionRewards: Bool = false,
        musicStageID: String? = nil,
        heroExperienceAward: Int = 0,
        companionExperienceAward: Int = 0,
        materialRewards: [ResourceAmount] = [],
    ) -> (configuration: BattleRunConfiguration, presentation: BattlePresentationContext) {
        let configuration = BattleRunConfiguration(
            runKey: runKey,
            rngSeed: rngSeed,
            hero: BattleRunConfiguration.PartyMember(
                combatant: hero,
                progression: heroProgression,
                equipmentLoadout: heroEquipmentLoadout,
                modifiers: heroModifiers,
            ),
            companion: BattleRunConfiguration.PartyMember(
                combatant: companion,
                progression: companionProgression,
                equipmentLoadout: companionEquipmentLoadout,
                modifiers: companionModifiers,
            ),
            enemy: enemy ?? Enemy.fallbackCombatant,
            enemyEncounterLevel: enemyEncounterLevel,
            enemyModifiers: enemyModifiers,
        )
        let presentation = BattlePresentationContext(
            inventoryItems: inventoryItems,
            rewardPlan: BattleRewardPlan(
                stageGold: stageRewardsAlreadyClaimed ? 0 : stageReward?.gold ?? 0,
                goldFindPercent: goldFindPercent,
                heroExperience: stageRewardsAlreadyClaimed ? 0 : heroExperienceAward,
                companionExperience: stageRewardsAlreadyClaimed ? 0 : companionExperienceAward,
                materials: stageRewardsAlreadyClaimed ? [] : materialRewards,
                items: stageRewardsAlreadyClaimed ? [] : rewardItems,
            ),
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            hasProgressionRewards: hasProgressionRewards,
            musicStageID: musicStageID,
        )
        return (configuration, presentation)
    }
}
