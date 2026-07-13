import TrinketContent
import TrinketCore
import TrinketPersistence
@testable import Trinket

@MainActor
enum ActiveBattleConfigurationTestSupport {
    static func make(
        stageID: String? = nil,
        aspectBattle: ActiveBattleConfiguration.AspectBattle? = nil,
        rngSeed: UInt64 = 0,
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        roster: PlayerRosterState = .initial,
        inventory: PlayerInventoryState = .initial,
        stageReward: StageReward? = nil
    ) throws -> ActiveBattleConfiguration {
        ActiveBattleConfiguration.make(
            stageID: stageID,
            aspectBattle: aspectBattle,
            rngSeed: rngSeed,
            hero: hero,
            companion: companion,
            rosterState: roster,
            inventoryState: inventory,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            stageReward: stageReward
        )
    }
}
