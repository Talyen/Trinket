import XCTest
@testable import Trinket

@MainActor
final class PlayerHomesteadStoreTests: XCTestCase {
    private var directoryURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: "PlayerHomesteadStoreTests")
    }

    override func tearDown() async throws {
        SaveTestSupport.removeTempDirectory(directoryURL)
        try await super.tearDown()
    }

    func testBuildOrUpgradeWriteThroughToSaveStore() throws {
        let saveStore = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        let rosterStore = PlayerRosterStore(saveStore: saveStore)
        let homesteadStore = PlayerHomesteadStore(saveStore: saveStore)
        saveStore.homestead = PlayerHomesteadState(
            resources: [.wood: 20, .stone: 10],
            nodeTiers: [:]
        )
        rosterStore.grantGold(4)
        let definition = try XCTUnwrap(GameContent.homesteadNode(matching: .wheatField))

        XCTAssertTrue(homesteadStore.buildOrUpgrade(definition, roster: rosterStore))

        let reloaded = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        XCTAssertEqual(reloaded.homestead.tier(for: .wheatField), 1)
        XCTAssertEqual(reloaded.homestead.resources[.wood], 10)
        XCTAssertEqual(reloaded.roster.gold, 4)
    }

    func testBuildOrUpgradeReturnsFalseWhenPrerequisitesMissing() throws {
        let saveStore = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        let rosterStore = PlayerRosterStore(saveStore: saveStore)
        let homesteadStore = PlayerHomesteadStore(saveStore: saveStore)
        saveStore.homestead = PlayerHomesteadState(
            resources: [.wood: 100, .stone: 100, .iron: 100],
            nodeTiers: [.wheatField: 1]
        )
        rosterStore.grantGold(100)
        let definition = try XCTUnwrap(GameContent.homesteadNode(matching: .blacksmithForge))

        XCTAssertFalse(homesteadStore.buildOrUpgrade(definition, roster: rosterStore))

        let reloaded = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        XCTAssertEqual(reloaded.homestead.tier(for: .blacksmithForge), 0)
        XCTAssertEqual(reloaded.roster.gold, 100)
    }

    func testGrantResourcesWriteThroughToSaveStore() {
        let homesteadStore = PlayerHomesteadStore(saveStore: SaveTestSupport.makeSaveStore(directoryURL: directoryURL))

        homesteadStore.grant([ResourceAmount(.wood, 7), ResourceAmount(.crystal, 2)])

        let reloaded = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        XCTAssertEqual(reloaded.homestead.resources[.wood], 7)
        XCTAssertEqual(reloaded.homestead.resources[.crystal], 2)
    }
}
