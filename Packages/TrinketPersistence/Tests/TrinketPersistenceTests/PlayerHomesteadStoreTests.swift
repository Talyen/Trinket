import Foundation
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

    @Test func `build or upgrade node persists homestead and roster through hub`() throws {
        let storeURL = context.storeURL()
        let firstStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true, persistSaveImmediately: true)
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        firstStore.homestead = PlayerHomesteadState(
            resources: [.wood: 20, .herbs: 10],
            nodeTiers: [:],
        )
        var roster = firstStore.roster
        roster.gold = 4
        firstStore.roster = roster

        let result = firstStore.buildOrUpgradeNode(definition)
        try #expect(result == .success)
        try #expect(firstStore.homestead.tier(for: .wheatField) == 1)
        try #expect(firstStore.homestead.resources[.wood] == 15)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reloaded.homestead.tier(for: .wheatField) == 1)
        try #expect(reloaded.homestead.resources[.wood] == 15)
        try #expect(reloaded.homestead.resources[.herbs] == 5)
    }

    @Test func `build or upgrade node returns insufficient resources without mutating`() throws {
        let store = try context.makeSaveStore()
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        store.homestead = PlayerHomesteadState(resources: [:], nodeTiers: [:])

        let result = store.buildOrUpgradeNode(definition)
        try #expect(result == .insufficientResources)
        try #expect(store.homestead.tier(for: .wheatField) == 0)
    }

    @Test func `build or upgrade node returns not available when max tier`() throws {
        let store = try context.makeSaveStore()
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let maxTier = try #require(definition.tiers.map(\.tier).max())
        store.homestead = PlayerHomesteadState(
            resources: [.wood: 99, .herbs: 99],
            nodeTiers: [.wheatField: maxTier],
        )

        let result = store.buildOrUpgradeNode(definition)
        try #expect(result == .notAvailable)
        try #expect(store.homestead.tier(for: .wheatField) == maxTier)
    }

    @Test func `collect production persists pending materials and timestamp`() throws {
        let storeURL = context.storeURL()
        let firstStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true, persistSaveImmediately: true)
        let start = Date(timeIntervalSince1970: 0)
        let collectionDate = start.addingTimeInterval(PlayerHomesteadState.secondsPerDay)
        firstStore.homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wheatField: 1, .wishingWell: 1],
            lastProductionAt: start,
        )
        var roster = firstStore.roster
        roster.gold = 900
        firstStore.roster = roster

        let result = firstStore.collectProduction(at: collectionDate)
        try #expect(result == .success([
            ResourceAmount(.food, 1),
            ResourceAmount(.gold, 1),
        ]))

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reloaded.homestead.resources[.food] == 1)
        try #expect(reloaded.roster.gold == 901)
        try #expect(reloaded.homestead.pendingProduction.isEmpty)
        try #expect(reloaded.homestead.lastProductionAt == collectionDate)
    }

    @Test func `build settles production before changing node tier`() throws {
        let store = try context.makeSaveStore()
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let start = Date(timeIntervalSince1970: 0)
        let upgradeDate = start.addingTimeInterval(PlayerHomesteadState.secondsPerDay)
        store.homestead = PlayerHomesteadState(
            resources: [.wood: 20, .herbs: 20],
            nodeTiers: [.wheatField: 1],
            lastProductionAt: start,
        )

        let result = store.buildOrUpgradeNode(definition, at: upgradeDate)
        try #expect(result == .success)
        try #expect(store.homestead.tier(for: .wheatField) == 2)
        try #expect(store.homestead.pendingProduction[.food] == 1)
    }
}
