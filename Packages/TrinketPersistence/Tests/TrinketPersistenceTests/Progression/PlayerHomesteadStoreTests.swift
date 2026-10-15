import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct PlayerHomesteadStoreTests {
    @Test @MainActor func `awaited homestead commands retry refused writes and settle once across reload`() async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let start = Date(timeIntervalSince1970: 0)
        let collectionDate = start.addingTimeInterval(PlayerHomesteadState.secondsPerDay)
        try store.performFixtureMutation { save in
            save.homestead = PlayerHomesteadState(
                resources: [.wood: 20, .herbs: 10], nodeTiers: [:], lastProductionAt: start,
            )
        }

        store.forcesNextSaveFailure = true
        #expect(await store.buildOrUpgradeNode(.wheatField, targetTier: 1, at: start) == .success)
        store.forcesNextSaveFailure = true
        #expect(await store.collectProduction(at: collectionDate) == .success([ResourceAmount(.food, 1)]))

        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.homestead.tier(for: .wheatField) == 1)
        #expect(reloaded.homestead.resources[.wood] == 16)
        #expect(reloaded.homestead.resources[.herbs] == 5)
        #expect(reloaded.homestead.resources[.food] == 1)
        #expect(await reloaded.collectProduction(at: collectionDate) == .noProduction)
    }

    @Test(arguments: [false, true]) @MainActor
    func `cancelled homestead command cannot commit after its initial yield`(collecting: Bool) async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let start = Date(timeIntervalSince1970: 0)
        let collectionDate = start.addingTimeInterval(PlayerHomesteadState.secondsPerDay)
        try store.performFixtureMutation { save in
            save.homestead = PlayerHomesteadState(
                resources: [.wood: 20, .herbs: 10], nodeTiers: [:],
                pendingProduction: [.food: 1], lastProductionAt: start,
            )
        }
        let before = store.currentSave
        let pending = Task {
            if collecting {
                return await store.collectProduction(at: collectionDate) == .invalidated
            }
            return await store.buildOrUpgradeNode(.wheatField, targetTier: 1, at: start) == .invalidated
        }
        pending.cancel()
        #expect(await pending.value)
        #expect(store.currentSave == before)
        #expect(try context.makeReloadedStore().currentSave == before)
    }

    @Test @MainActor func `runesmith builds without other buildings and survives reload`() async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        #expect(store.persistFixtureBatch(logging: "Independent building fixture") { save in
            save.homestead = PlayerHomesteadState(resources: [.iron: 9, .gems: 2], nodeTiers: [:])
        })
        #expect(await store.buildOrUpgradeNode(.runesmithWorkshop, targetTier: 1) == .success)
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.homestead.tier(for: .runesmithWorkshop) == 1)
        #expect(HomesteadNodeID.allCases.filter { $0 != .runesmithWorkshop }.allSatisfy { reloaded.homestead.tier(for: $0) == 0 })
        #expect(reloaded.homestead.balance(for: .iron, gold: reloaded.roster.gold) == 0)
        #expect(reloaded.homestead.balance(for: .gems, gold: reloaded.roster.gold) == 0)
    }

    @Test @MainActor func `cloud homestead actions preserve wallet tiers and production across reload`() async throws {
        let context = try PersistenceTestContext()
        let start = Date(timeIntervalSince1970: 0)
        let collectionDate = start.addingTimeInterval(PlayerHomesteadState.secondsPerDay)
        var before: PlayerSave
        do {
            let store = try context.makeSaveStore()
            #expect(store.persistFixtureBatch(logging: "Test setup") { save in
                save.roster.gold = 100
                save.homestead = PlayerHomesteadState(
                    resources: [.wood: 99, .herbs: 99],
                    nodeTiers: [.wheatField: 1, .wishingWell: 1],
                    lastProductionAt: start,
                )
            })
            before = store.currentSave
        }
        do {
            let container = try ModelContainer(
                for: PlayerSaveGraph.schema,
                configurations: ModelConfiguration(
                    schema: PlayerSaveGraph.schema,
                    url: context.storeURL(),
                    cloudKitDatabase: .none,
                ),
            )
            let store = try PlayerSaveStore(
                openResult: .init(container: container, usedInMemoryFallback: false),
                cloudSyncEnabled: true,
            )
            #expect(await store.collectProduction(at: collectionDate) == .success([
                ResourceAmount(.food, 1), ResourceAmount(.gold, 1),
            ]))
            #expect(
                await store.buildOrUpgradeNode(.wheatField, targetTier: 2, at: collectionDate) == .success,
            )
            #expect(store.currentSave != before)
        }
        let reloaded = try context.makeReloadedStore()
        #expect(await reloaded.collectProduction(at: collectionDate) == .noProduction)
        #expect(await reloaded.buildOrUpgradeNode(.wheatField, targetTier: 2, at: collectionDate) == .notAvailable)
        let afterLocalPlay = try context.makeReloadedStore()
        #expect(afterLocalPlay.homestead.tier(for: .wheatField) == 2)
        #expect(afterLocalPlay.homestead.resources[.food] == 1)
        #expect(afterLocalPlay.roster.gold == 101)
    }

    @Test @MainActor func `build or upgrade node persists homestead and roster through hub`() async throws {
        let context = try PersistenceTestContext()
        let firstStore = try context.makeSaveStore()
        #expect(firstStore.persistFixtureBatch(logging: "Test setup") { $0.homestead = PlayerHomesteadState(
            resources: [.wood: 20, .herbs: 10],
            nodeTiers: [:],
        ) })
        var roster = firstStore.roster
        roster.gold = 4
        #expect(firstStore.persistFixtureBatch(logging: "Test setup") { $0.roster = roster })

        let result = await firstStore.buildOrUpgradeNode(.wheatField, targetTier: 1)
        try #expect(result == .success)
        try #expect(firstStore.homestead.tier(for: .wheatField) == 1)
        try #expect(firstStore.homestead.resources[.wood] == 16)

        let reloaded = try context.makeReloadedStore()
        try #expect(reloaded.homestead.tier(for: .wheatField) == 1)
        try #expect(reloaded.homestead.resources[.wood] == 16)
        try #expect(reloaded.homestead.resources[.herbs] == 5)
    }

    @Test @MainActor func `build or upgrade node returns insufficient resources without mutating`() async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore(inMemoryOnly: true)
        #expect(store.persistFixtureBatch(logging: "Test setup") { $0.homestead = PlayerHomesteadState(resources: [:], nodeTiers: [:]) })

        let result = await store.buildOrUpgradeNode(.wheatField, targetTier: 1)
        try #expect(result == .insufficientResources)
        try #expect(store.homestead.tier(for: .wheatField) == 0)
    }

    @Test @MainActor func `build or upgrade node returns not available when max tier`() async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore(inMemoryOnly: true)
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let maxTier = try #require(definition.tiers.map(\.tier).max())
        #expect(store.persistFixtureBatch(logging: "Test setup") { $0.homestead = PlayerHomesteadState(
            resources: [.wood: 99, .herbs: 99],
            nodeTiers: [.wheatField: maxTier],
        ) })

        let result = await store.buildOrUpgradeNode(definition.id, targetTier: 1)
        try #expect(result == .notAvailable)
        try #expect(store.homestead.tier(for: .wheatField) == maxTier)
    }

    @Test @MainActor func `repeated displayed tier cannot buy the following upgrade`() async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        #expect(store.persistFixtureBatch(logging: "Test setup") { $0.homestead = PlayerHomesteadState(
            resources: [.wood: 99, .herbs: 99],
            nodeTiers: [:],
        ) })
        #expect(await store.buildOrUpgradeNode(.wheatField, targetTier: 1) == .success)
        let after = store.currentSave
        #expect(await store.buildOrUpgradeNode(.wheatField, targetTier: 1) == .notAvailable)
        #expect(store.currentSave == after)
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.homestead.tier(for: .wheatField) == 1)
        #expect(reloaded.homestead.resources == after.homestead.resources)
    }

    @Test @MainActor func `collect production persists pending materials and timestamp`() async throws {
        let context = try PersistenceTestContext()
        let firstStore = try context.makeSaveStore()
        let start = Date(timeIntervalSince1970: 0)
        let collectionDate = start.addingTimeInterval(PlayerHomesteadState.secondsPerDay)
        #expect(firstStore.persistFixtureBatch(logging: "Test setup") { $0.homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wheatField: 1, .wishingWell: 1],
            lastProductionAt: start,
        ) })
        var roster = firstStore.roster
        roster.gold = 900
        #expect(firstStore.persistFixtureBatch(logging: "Test setup") { $0.roster = roster })

        let result = await firstStore.collectProduction(at: collectionDate)
        try #expect(result == .success([
            ResourceAmount(.food, 1),
            ResourceAmount(.gold, 1),
        ]))

        let reloaded = try context.makeReloadedStore()
        try #expect(reloaded.homestead.resources[.food] == 1)
        try #expect(reloaded.roster.gold == 901)
        try #expect(reloaded.homestead.pendingProduction.isEmpty)
        try #expect(reloaded.homestead.lastProductionAt == collectionDate)
    }

    @Test @MainActor func `build settles production before changing node tier`() async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore(inMemoryOnly: true)
        let start = Date(timeIntervalSince1970: 0)
        let upgradeDate = start.addingTimeInterval(PlayerHomesteadState.secondsPerDay)
        #expect(store.persistFixtureBatch(logging: "Test setup") { $0.homestead = PlayerHomesteadState(
            resources: [.wood: 20, .herbs: 20],
            nodeTiers: [.wheatField: 1],
            lastProductionAt: start,
        ) })

        let result = await store.buildOrUpgradeNode(.wheatField, targetTier: 2, at: upgradeDate)
        try #expect(result == .success)
        try #expect(store.homestead.tier(for: .wheatField) == 2)
        try #expect(store.homestead.pendingProduction[.food] == 1)
    }
}
