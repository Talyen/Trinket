import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence
@testable import TrinketAppState

@MainActor
enum ActiveBattleConfigurationTestSupport {
    static func make(
        resumeToken: ActiveBattleResumeToken? = nil,
        rngSeed: UInt64 = 0,
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        roster: PlayerRosterState = .initial,
        inventory: PlayerInventoryState = .initial,
        stageReward: StageReward? = nil,
        experienceBonusPercent: Int = 0,
        pendingRewardItem: InventoryItem? = nil,
        universalModifiers: [AffixModifier] = []
    ) throws -> ActiveBattleConfiguration {
        ActiveBattleConfiguration.make(
            resumeToken: resumeToken,
            rngSeed: rngSeed,
            hero: hero,
            companion: companion,
            rosterState: roster,
            inventoryState: inventory,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            stageReward: stageReward,
            experienceBonusPercent: experienceBonusPercent,
            pendingRewardItem: pendingRewardItem,
            universalModifiers: universalModifiers
        )
    }
}
