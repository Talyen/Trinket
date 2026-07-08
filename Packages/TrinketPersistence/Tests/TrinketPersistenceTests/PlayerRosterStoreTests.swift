import Testing
import TrinketContent
@testable import TrinketPersistence

@Suite @MainActor
final class PlayerRosterStoreTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    @Test func heroesFiltersByUnlock() throws {
        let rosterStore = try makeRosterStore()

        try #expect(rosterStore.heroes.map(\.id) == [PlayerRosterState.starterHeroID])
        try #expect(rosterStore.pets.map(\.id) == [PlayerRosterState.starterPetID])
        try #expect(rosterStore.collectionHeroes.count == GameContent.heroes.count)
        try #expect(rosterStore.collectionPets.count == GameContent.pets.count)
    }

    @Test func grantGoldWriteThroughToSaveStore() throws {
        let saveStore = try context.makeSaveStore()
        let rosterStore = PlayerRosterStore(saveStore: saveStore)

        var updated = rosterStore.current
        updated.grantGold(50)
        rosterStore.current = updated

        let reloaded = try context.makeSaveStore()
        try #expect(reloaded.roster.gold == 50)
    }

    @Test func grantExperienceWriteThroughToSaveStore() throws {
        let saveStore = try context.makeSaveStore()
        let rosterStore = PlayerRosterStore(saveStore: saveStore)
        let knight = try #require(GameContent.heroes.first { $0.id == PlayerRosterState.starterHeroID })

        var updated = rosterStore.current
        updated.grantExperience(25, to: knight)
        rosterStore.current = updated

        let reloaded = try context.makeSaveStore()
        try #expect(reloaded.roster.progression(for: knight).currentXP == 25)
    }

    @Test func setActiveHeroWriteThroughToSaveStore() throws {
        let saveStore = try context.makeSaveStore()
        try saveStore.applyTestSeed()
        let rosterStore = PlayerRosterStore(saveStore: saveStore)
        let wizard = try #require(GameContent.heroes.first { $0.id == "wizard" })

        var updated = rosterStore.current
        updated.setActiveHero(wizard)
        rosterStore.current = updated

        let reloaded = try context.makeSaveStore()
        try #expect(reloaded.roster.activeHeroID == "wizard")
    }

    @Test func activeHeroAndPetUseSelectedIDs() throws {
        let rosterStore = try makeRosterStore()

        try #expect(rosterStore.activeHero.id == PlayerRosterState.starterHeroID)
        try #expect(rosterStore.activePet.id == PlayerRosterState.starterPetID)
    }

    @Test func setLoadoutWriteThroughToSaveStore() throws {
        let saveStore = try context.makeSaveStore()
        let rosterStore = PlayerRosterStore(saveStore: saveStore)
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let customLoadout = AbilityLoadout(
            basic: .bash,
            skill: .smite,
            ultimate: .blessedAegis
        )

        var updated = rosterStore.current
        updated.setLoadout(customLoadout, for: knight)
        rosterStore.current = updated

        let reloaded = try context.makeSaveStore()
        try #expect(reloaded.roster.loadout(for: knight) == customLoadout)
    }

    private func makeRosterStore() throws -> PlayerRosterStore {
        PlayerRosterStore(saveStore: try context.makeSaveStore())
    }
}
