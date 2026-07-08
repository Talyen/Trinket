import TrinketContent
import TrinketCore
import TrinketPersistence
@testable import Trinket

@MainActor
enum ActiveBattleConfigurationTestSupport {
    static func make(
        stageID: String? = nil,
        rngSeed: UInt64 = 0,
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        roster: PlayerRosterState = .initial,
        inventory: PlayerInventoryState = .initial,
        stageReward: StageReward? = nil
    ) throws -> ActiveBattleConfiguration {
        ActiveBattleConfiguration.make(
            stageID: stageID,
            rngSeed: rngSeed,
            hero: hero,
            pet: pet,
            rosterState: roster,
            inventoryState: inventory,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            stageReward: stageReward
        )
    }
}

