import TrinketContent
import TrinketCore
import TrinketPersistence
@testable import TrinketBattleFeature

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
        homestead: PlayerHomesteadState = .freshStart,
        stageReward: StageReward? = nil,
        experienceBonusPercent: Int = 0,
        pendingRewardItem: InventoryItem? = nil,
        stageRewardsAlreadyClaimed: Bool = false,
        universalModifiers: [AffixModifier] = []
    ) throws -> ActiveBattleConfiguration {
        ActiveBattleConfiguration.make(
            resumeToken: resumeToken,
            rngSeed: rngSeed,
            hero: hero,
            companion: companion,
            rosterState: roster,
            inventoryState: inventory,
            homesteadState: homestead,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            stageReward: stageReward,
            experienceBonusPercent: experienceBonusPercent,
            pendingRewardItem: pendingRewardItem,
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            universalModifiers: universalModifiers
        )
    }
}
