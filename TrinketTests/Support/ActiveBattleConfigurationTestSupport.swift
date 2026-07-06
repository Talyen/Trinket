import TrinketContent
import TrinketCore
import TrinketPersistence
@testable import Trinket

@MainActor
enum ActiveBattleConfigurationTestSupport {
    static func makeStores(
        roster: PlayerRosterState = .initial,
        inventory: PlayerInventoryState = .initial
    ) -> (roster: PlayerRosterStore, inventory: PlayerInventoryStore) {
        let saveStore = PlayerSaveStore(persistDebounceNanoseconds: 0)
        saveStore.roster = roster
        saveStore.inventory = inventory
        return (
            PlayerRosterStore(saveStore: saveStore),
            PlayerInventoryStore(saveStore: saveStore)
        )
    }

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
    ) -> ActiveBattleConfiguration {
        let stores = makeStores(roster: roster, inventory: inventory)
        return ActiveBattleConfiguration.make(
            stageID: stageID,
            rngSeed: rngSeed,
            hero: hero,
            pet: pet,
            roster: stores.roster,
            inventory: stores.inventory,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            stageReward: stageReward
        )
    }
}
