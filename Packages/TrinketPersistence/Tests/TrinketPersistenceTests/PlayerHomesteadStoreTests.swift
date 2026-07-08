import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

@Suite @MainActor
final class PlayerHomesteadStoreTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    @Test func buildOrUpgradeWriteThroughToSaveStore() throws {
        let saveStore = try context.makeSaveStore()
        let rosterStore = PlayerRosterStore(saveStore: saveStore)
        let homesteadStore = PlayerHomesteadStore(saveStore: saveStore)
        saveStore.homestead = PlayerHomesteadState(
            resources: [.wood: 20, .stone: 10],
            nodeTiers: [:]
        )
        var updatedRoster = rosterStore.current
        updatedRoster.grantGold(4)
        rosterStore.current = updatedRoster
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))

        try #expect(homesteadStore.buildOrUpgrade(definition, roster: rosterStore) == .success)

        let reloaded = try context.makeSaveStore()
        try #expect(reloaded.homestead.tier(for: .wheatField) == 1)
        try #expect(reloaded.homestead.resources[.wood] == 10)
        try #expect(reloaded.roster.gold == 4)
    }

    @Test func buildOrUpgradeReturnsFalseWhenPrerequisitesMissing() throws {
        let saveStore = try context.makeSaveStore()
        let rosterStore = PlayerRosterStore(saveStore: saveStore)
        let homesteadStore = PlayerHomesteadStore(saveStore: saveStore)
        saveStore.homestead = PlayerHomesteadState(
            resources: [.wood: 100, .stone: 100, .iron: 100],
            nodeTiers: [.wheatField: 1]
        )
        var updatedRoster = rosterStore.current
        updatedRoster.grantGold(100)
        rosterStore.current = updatedRoster
        let definition = try #require(GameContent.homesteadNode(matching: .blacksmithForge))

        try #expect(
            homesteadStore.buildOrUpgrade(definition, roster: rosterStore) == .insufficientResources
        )

        let reloaded = try context.makeSaveStore()
        try #expect(reloaded.homestead.tier(for: .blacksmithForge) == 0)
        try #expect(reloaded.roster.gold == 100)
    }

    @Test func grantResourcesWriteThroughToSaveStore() throws {
        let homesteadStore = PlayerHomesteadStore(saveStore: try context.makeSaveStore())

        homesteadStore.grant([ResourceAmount(.wood, 7), ResourceAmount(.crystal, 2)])

        let reloaded = try context.makeSaveStore()
        try #expect(reloaded.homestead.resources[.wood] == 7)
        try #expect(reloaded.homestead.resources[.crystal] == 2)
    }
}
