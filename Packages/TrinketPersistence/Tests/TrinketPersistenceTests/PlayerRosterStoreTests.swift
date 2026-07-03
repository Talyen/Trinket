import XCTest
import TrinketContent
@testable import TrinketPersistence

@MainActor
final class PlayerRosterStoreTests: XCTestCase {
    private var directoryURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: "PlayerRosterStoreTests")
    }

    override func tearDown() async throws {
        SaveTestSupport.removeTempDirectory(directoryURL)
        try await super.tearDown()
    }

    func testHeroesFiltersByUnlock() {
        let rosterStore = makeRosterStore()

        XCTAssertEqual(rosterStore.heroes.map(\.id), [PlayerRosterState.starterHeroID])
        XCTAssertEqual(rosterStore.pets.map(\.id), [PlayerRosterState.starterPetID])
        XCTAssertEqual(rosterStore.collectionHeroes.count, GameContent.heroes.count)
        XCTAssertEqual(rosterStore.collectionPets.count, GameContent.pets.count)
    }

    func testGrantGoldWriteThroughToSaveStore() {
        let saveStore = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        let rosterStore = PlayerRosterStore(saveStore: saveStore)

        rosterStore.grantGold(50)

        let reloaded = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        XCTAssertEqual(reloaded.roster.gold, 50)
    }

    func testGrantExperienceWriteThroughToSaveStore() throws {
        let saveStore = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        let rosterStore = PlayerRosterStore(saveStore: saveStore)
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == PlayerRosterState.starterHeroID })

        rosterStore.grantExperience(25, to: knight)

        let reloaded = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        XCTAssertEqual(reloaded.roster.progression(for: knight).currentXP, 25)
    }

    func testSetActiveHeroWriteThroughToSaveStore() throws {
        let saveStore = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        saveStore.applyTestSeed()
        let rosterStore = PlayerRosterStore(saveStore: saveStore)
        let wizard = try XCTUnwrap(GameContent.heroes.first { $0.id == "wizard" })

        rosterStore.setActiveHero(wizard)

        let reloaded = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        XCTAssertEqual(reloaded.roster.activeHeroID, "wizard")
    }

    func testActiveHeroAndPetUseSelectedIDs() {
        let rosterStore = makeRosterStore()

        XCTAssertEqual(rosterStore.activeHero.id, PlayerRosterState.starterHeroID)
        XCTAssertEqual(rosterStore.activePet.id, PlayerRosterState.starterPetID)
    }

    func testSetLoadoutWriteThroughToSaveStore() throws {
        let saveStore = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        let rosterStore = PlayerRosterStore(saveStore: saveStore)
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let customLoadout = AbilityLoadout(
            basic: .bash,
            skill: .smite,
            ultimate: .blessedAegis
        )

        rosterStore.setLoadout(customLoadout, for: knight)

        let reloaded = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        XCTAssertEqual(reloaded.roster.loadout(for: knight), customLoadout)
    }

    private func makeRosterStore() -> PlayerRosterStore {
        PlayerRosterStore(saveStore: SaveTestSupport.makeSaveStore(directoryURL: directoryURL))
    }
}
