import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

@MainActor
final class PlayerHomesteadStoreTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    @Test func buildOrUpgradeNodePersistsHomesteadAndRosterThroughHub() throws {
        let storeURL = context.storeURL()
        let firstStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true, persistSaveImmediately: true)
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        firstStore.homestead = PlayerHomesteadState(
            resources: [.wood: 20, .herbs: 10],
            nodeTiers: [:]
        )
        var roster = firstStore.roster
        roster.gold = 4
        firstStore.roster = roster

        let result = firstStore.homesteadStore.buildOrUpgradeNode(definition)
        try #expect(result == .success)
        try #expect(firstStore.homestead.tier(for: .wheatField) == 1)
        try #expect(firstStore.homestead.resources[.wood] == 15)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reloaded.homestead.tier(for: .wheatField) == 1)
        try #expect(reloaded.homestead.resources[.wood] == 15)
        try #expect(reloaded.homestead.resources[.herbs] == 5)
    }

    @Test func buildOrUpgradeNodeReturnsInsufficientResourcesWithoutMutating() throws {
        let store = try context.makeSaveStore()
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        store.homestead = PlayerHomesteadState(resources: [:], nodeTiers: [:])

        let result = store.homesteadStore.buildOrUpgradeNode(definition)
        try #expect(result == .insufficientResources)
        try #expect(store.homestead.tier(for: .wheatField) == 0)
    }
}
