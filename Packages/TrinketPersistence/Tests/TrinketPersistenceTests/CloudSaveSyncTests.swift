import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct CloudSaveSyncTests {
    @Test(arguments: [CloudSaveRequest.Action.collect, .upgrade(.wheatField, 2)])
    @MainActor func `production preserves progress earned after preliminary synchronization`(
        action: CloudSaveRequest.Action,
    ) async throws {
        let transport = CloudSaveTestTransport()
        let context = try PersistenceTestContext()
        let store = try cloudStore(context, transport: transport)
        try seedHomestead(store)
        #expect(await store.cloudSync?.synchronize() == true)
        await transport.advance(PlayerHomesteadState.secondsPerDay)
        try store.performBatchMutation { $0.roster.gold += 7 }
        let outcome = await store.cloudSync?.perform(action)
        let expectedGold: Int
        switch action {
        case .collect:
            #expect(outcome == .collected([.food: 1, .gold: 1]))
            expectedGold = 108
        default:
            #expect(outcome == .upgraded)
            expectedGold = 107
        }
        #expect(store.roster.gold == expectedGold)
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.gold == expectedGold)
        #expect(reloaded.homestead == store.homestead)
        #expect(reloaded.cloudDeviceState.account.pending == nil)
    }

    @Test @MainActor func `local production after rollback cannot reopen cloud claim intervals`() async throws {
        let transport = CloudSaveTestTransport()
        let context = try PersistenceTestContext()
        let linked = try cloudStore(context, transport: transport)
        try seedHomestead(linked)
        #expect(await linked.cloudSync?.synchronize() == true)
        await transport.advance(PlayerHomesteadState.secondsPerDay)
        let local = try context.makeReloadedStore()
        let date = Date(timeIntervalSince1970: 2000000000 + PlayerHomesteadState.secondsPerDay)
        #expect(await local.collectProduction(at: date) == .success([ResourceAmount(.food, 1), ResourceAmount(.gold, 1)]))
        #expect(local.cloudDeviceState.activeAccountID == nil)
        #expect(local.homestead.resources[.food] == 1)
        let rejoined = try cloudStore(context, transport: transport)
        #expect(await rejoined.cloudSync?.synchronize() == true)
        #expect(rejoined.cloudDeviceState.guestBackup?.homestead.resources[.food] == 1)
        #expect(await rejoined.collectProduction() == .success([ResourceAmount(.food, 1), ResourceAmount(.gold, 1)]))
        #expect(rejoined.homestead.resources[.food] == 1)
        #expect(rejoined.roster.gold == 101)
    }

    @Test @MainActor func `own upload acknowledgements keep sessions while remote progress invalidates them`() async throws {
        let transport = CloudSaveTestTransport()
        let first = try PersistenceTestContext()
        let second = try PersistenceTestContext()
        let a = try cloudStore(first, transport: transport)
        var invalidations = 0
        a.onExternalProgressChange = { invalidations += 1 }
        #expect(await a.cloudSync?.synchronize() == true)
        try a.performBatchMutation { $0.roster.gold = 11 }
        #expect(await a.cloudSync?.synchronize() == true)
        #expect(invalidations == 0)
        let b = try cloudStore(second, transport: transport)
        #expect(await b.cloudSync?.synchronize() == true)
        try b.performBatchMutation { $0.roster.gold = 22 }
        #expect(await b.cloudSync?.synchronize() == true)
        #expect(await a.cloudSync?.synchronize() == true)
        #expect(a.roster.gold == 22)
        #expect(invalidations == 1)
    }

    @Test @MainActor func `unreadable cloud metadata stays intact while local progress remains playable`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        try store.performBatchMutation { $0.roster.gold = 47 }
        let container = try ModelContainer(for: PlayerSaveGraph.schema, configurations: ModelConfiguration(
            schema: PlayerSaveGraph.schema, url: context.storeURL(), cloudKitDatabase: .none,
        ))
        let side = ModelContext(container)
        let root = try #require(side.fetch(FetchDescriptor<PlayerSaveRoot>()).first)
        let invalid = Data("unreadable cloud metadata".utf8)
        root.cloudStatePayload = invalid
        try side.save()
        let reopened = try cloudStore(context, transport: CloudSaveTestTransport())
        #expect(!reopened.isCloudSyncEnabled)
        #expect(reopened.cloudSync == nil)
        #expect(reopened.roster.gold == 47)
        try reopened.performBatchMutation { $0.roster.gold += 3 }
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.gold == 50)
        let inspection = try ModelContainer(for: PlayerSaveGraph.schema, configurations: ModelConfiguration(
            schema: PlayerSaveGraph.schema, url: context.storeURL(), cloudKitDatabase: .none,
        ))
        let persisted = try ModelContext(inspection).fetch(FetchDescriptor<PlayerSaveRoot>()).first
        #expect(persisted?.cloudStatePayload == invalid)
    }

    @Test func `complete snapshot coding preserves gameplay and validates its schema`() throws {
        var save = PlayerSaveSanitizer.sanitize(.testSeed)
        save.sessionGeneration = 0
        let snapshot = CloudSaveSnapshot(save)
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(CloudSaveSnapshot.self, from: data)
        #expect(try decoded.restored() == save)
        save.schemaVersion += 1
        #expect(throws: CloudSaveError.unsupportedSave) { try CloudSaveSnapshot(save).restored() }
    }

    @Test @MainActor func `populated saves reconcile as complete snapshots and retain the losing progress`() async throws {
        let transport = CloudSaveTestTransport()
        let first = try PersistenceTestContext()
        let second = try PersistenceTestContext()
        let local = try first.makeSaveStore()
        try local.performBatchMutation { save in
            save.starterSelection = .complete
            save.roster.gold = 17
            save.journey.completedStageIDs = ["chapter-1-stage-1"]
        }
        let a = try cloudStore(first, transport: transport)
        #expect(await a.cloudSync?.synchronize() == true)
        let b = try cloudStore(second, transport: transport)
        try b.performBatchMutation { save in
            save.starterSelection = .complete
            save.roster.gold = 29
            save.journey.completedStageIDs = ["chapter-1-stage-1", "chapter-1-stage-2"]
        }
        #expect(await b.cloudSync?.synchronize() == true)
        #expect(b.roster.gold == 29)
        let server = await transport.account()
        #expect(server.backups.contains { $0.snapshot.roster.gold == 17 })
        #expect(await a.cloudSync?.synchronize() == true)
        #expect(a.roster.gold == 29)
        #expect(a.journey.completedStageIDs == b.journey.completedStageIDs)
        let reloaded = try first.makeReloadedStore()
        #expect(reloaded.roster.gold == 29)
        #expect(!reloaded.isCloudSyncEnabled)
        #expect(reloaded.cloudDeviceState.account.base == a.cloudDeviceState.account.base)
    }

    @Test @MainActor func `failed backup leaves both devices intact and retries the same request`() async throws {
        let transport = CloudSaveTestTransport()
        let first = try PersistenceTestContext()
        let second = try PersistenceTestContext()
        let a = try cloudStore(first, transport: transport)
        try a.performBatchMutation { $0.roster.gold = 10 }
        #expect(await a.cloudSync?.synchronize() == true)
        let b = try cloudStore(second, transport: transport)
        try b.performBatchMutation { $0.roster.gold = 20 }
        await transport.configure(failCommit: true)
        #expect(await b.cloudSync?.synchronize() == false)
        let pending = try #require(b.cloudDeviceState.account.pending)
        #expect(b.roster.gold == 20)
        #expect(await transport.account().head?.head.revision.snapshot.roster.gold == 10)
        #expect(await b.cloudSync?.synchronize() == true)
        #expect(await transport.account().receipts[pending.id] != nil)
        #expect(await transport.account().backups.count == 1)
    }

    @Test @MainActor func `committed production recovers after response loss and disk reload exactly once`() async throws {
        let transport = CloudSaveTestTransport()
        let context = try PersistenceTestContext()
        var original: PlayerSaveStore? = try cloudStore(context, transport: transport)
        try seedHomestead(#require(original))
        #expect(await original?.cloudSync?.synchronize() == true)
        await transport.advance(PlayerHomesteadState.secondsPerDay)
        await transport.configure(loseResponse: true)
        #expect(await original?.collectProduction() == .cloudUnavailable)
        #expect(original?.homestead.resources[.food, default: 0] == 0)
        #expect(original?.cloudDeviceState.account.pending != nil)
        original = nil
        let recovered = try cloudStore(context, transport: transport)
        #expect(await recovered.cloudSync?.synchronize() == true)
        #expect(recovered.homestead.resources[.food] == 1)
        #expect(recovered.roster.gold == 101)
        #expect(await recovered.collectProduction() == .noProduction)
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.homestead.resources[.food] == 1)
        #expect(reloaded.roster.gold == 101)
        #expect(reloaded.cloudDeviceState.account.pending == nil)
    }

    @Test @MainActor func `two collectors share an interval and upgrades settle the old rate`() async throws {
        let transport = CloudSaveTestTransport()
        let first = try PersistenceTestContext()
        let second = try PersistenceTestContext()
        let a = try cloudStore(first, transport: transport)
        try seedHomestead(a)
        #expect(await a.cloudSync?.synchronize() == true)
        let b = try cloudStore(second, transport: transport)
        #expect(await b.cloudSync?.synchronize() == true)
        await transport.advance(PlayerHomesteadState.secondsPerDay)
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        await transport.configure(conflicts: 7)
        #expect(await a.buildOrUpgradeNode(definition, targetTier: 2) == .success)
        #expect(a.homestead.pendingProduction[.food] == 1)
        async let firstCollection = a.collectProduction()
        async let secondCollection = b.collectProduction()
        let results = await (firstCollection, secondCollection)
        let outcomes = [results.0, results.1]
        #expect(outcomes.contains(.success([ResourceAmount(.food, 1), ResourceAmount(.gold, 1)])))
        #expect(outcomes.contains(.noProduction))
        #expect(a.homestead.tier(for: .wheatField) == 2)
        #expect(a.homestead.resources[.wood] == 89)
        await transport.advance(PlayerHomesteadState.secondsPerDay)
        #expect(await a.collectProduction() == .success([ResourceAmount(.food, 2), ResourceAmount(.gold, 1)]))
        #expect(a.homestead.resources[.food] == 3)
    }

    @Test @MainActor func `concurrent collect and upgrade complete without repeating rewards`() async throws {
        let transport = CloudSaveTestTransport()
        let first = try PersistenceTestContext()
        let second = try PersistenceTestContext()
        let a = try cloudStore(first, transport: transport)
        try seedHomestead(a)
        #expect(await a.cloudSync?.synchronize() == true)
        let b = try cloudStore(second, transport: transport)
        #expect(await b.cloudSync?.synchronize() == true)
        await transport.advance(PlayerHomesteadState.secondsPerDay)
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        async let collection = a.collectProduction()
        async let upgrade = b.buildOrUpgradeNode(definition, targetTier: 2)
        let results = await (collection, upgrade)
        #expect(results.0 == .success([ResourceAmount(.food, 1), ResourceAmount(.gold, 1)]))
        #expect(results.1 == .success)
        #expect(await a.cloudSync?.synchronize() == true)
        #expect(a.homestead.tier(for: .wheatField) == 2)
        #expect(a.homestead.resources[.wood] == 89)
        #expect(a.homestead.resources[.food] == 1)
        #expect(a.roster.gold == 101)
        #expect(await b.collectProduction() == .noProduction)
    }

    @Test @MainActor func `offline cloud play continues but production waits for authority`() async throws {
        let transport = CloudSaveTestTransport()
        let context = try PersistenceTestContext()
        let store = try cloudStore(context, transport: transport)
        try seedHomestead(store)
        #expect(await store.cloudSync?.synchronize() == true)
        await transport.configure(offline: true)
        try store.performBatchMutation { $0.roster.gold += 7 }
        #expect(await store.collectProduction() == .cloudUnavailable)
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        #expect(await store.buildOrUpgradeNode(definition, targetTier: 2) == .cloudUnavailable)
        #expect(try context.makeReloadedStore().roster.gold == 107)
        await transport.configure()
        #expect(await store.cloudSync?.synchronize() == true)
        #expect(store.roster.gold == 107)
    }

    @Test @MainActor func `reset wins over returning offline progress and invalidates its claims`() async throws {
        let transport = CloudSaveTestTransport()
        let first = try PersistenceTestContext()
        let second = try PersistenceTestContext()
        let a = try cloudStore(first, transport: transport)
        try seedHomestead(a)
        #expect(await a.cloudSync?.synchronize() == true)
        let b = try cloudStore(second, transport: transport)
        #expect(await b.cloudSync?.synchronize() == true)
        let oldEpoch = b.cloudDeviceState.account.base?.epoch
        try b.performBatchMutation { save in
            save.roster.gold = 888
            save.journey.completedStageIDs = Set(GameContent.chapters.flatMap(\.stages).map(\.id))
        }
        try a.resetGameplayProgress()
        #expect(await a.cloudSync?.synchronize() == true)
        #expect(await b.cloudSync?.synchronize() == true)
        #expect(b.roster.gold == 0)
        #expect(b.journey.completedStageIDs.isEmpty)
        #expect(b.cloudDeviceState.account.base?.epoch != oldEpoch)
        #expect(await transport.account().backups.contains { $0.snapshot.roster.gold == 888 })
        #expect(try second.makeReloadedStore().worldSeed == a.worldSeed)
    }

    @Test @MainActor func `account switching and signed out play never enter another accounts save`() async throws {
        let transport = CloudSaveTestTransport()
        let context = try PersistenceTestContext()
        let store = try cloudStore(context, transport: transport)
        try store.performBatchMutation { $0.roster.gold = 100 }
        #expect(await store.cloudSync?.synchronize() == true)
        await transport.switchAccount(nil)
        #expect(await store.cloudSync?.synchronize() == true)
        #expect(store.roster.gold == 100)
        try store.performBatchMutation { $0.roster.gold = 777 }
        await transport.switchAccount("player-b")
        #expect(await store.cloudSync?.synchronize() == true)
        #expect(store.roster.gold == 0)
        #expect(store.cloudDeviceState.guestBackup?.roster.gold == 777)
        await transport.switchAccount("player-a")
        #expect(await store.cloudSync?.synchronize() == true)
        #expect(store.roster.gold == 100)
        #expect(await transport.account("player-b").head?.head.revision.snapshot.roster.gold == 0)
        #expect(try context.makeReloadedStore().cloudDeviceState.activeAccountID == "player-a")
    }

    @Test @MainActor func `late remote fetch cannot overwrite a new local mutation`() async throws {
        let transport = CloudSaveTestTransport()
        let first = try PersistenceTestContext()
        let second = try PersistenceTestContext()
        let a = try cloudStore(first, transport: transport)
        #expect(await a.cloudSync?.synchronize() == true)
        let b = try cloudStore(second, transport: transport)
        #expect(await b.cloudSync?.synchronize() == true)
        try b.performBatchMutation { $0.roster.gold = 40 }
        #expect(await b.cloudSync?.synchronize() == true)
        await transport.onNextFetch {
            #expect(a.persistBatch(logging: "Concurrent gameplay") { save in
                save.roster.gold = 70
                save.journey.completedStageIDs = ["chapter-1-stage-1"]
            })
        }
        #expect(await a.cloudSync?.synchronize() == true)
        #expect(a.roster.gold == 70)
        #expect(try first.makeReloadedStore().roster.gold == 70)
    }

    @MainActor private func cloudStore(
        _ context: PersistenceTestContext,
        transport: CloudSaveTestTransport,
    ) throws -> PlayerSaveStore {
        let schema = PlayerSaveGraph.schema
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(
            schema: schema, url: context.storeURL(), cloudKitDatabase: .none,
        ))
        return try PlayerSaveStore(
            openResult: .init(container: container, usedInMemoryFallback: false),
            cloudSyncEnabled: true,
            cloudTransport: transport,
        )
    }

    @MainActor private func seedHomestead(_ store: PlayerSaveStore) throws {
        try store.performBatchMutation { save in
            save.starterSelection = .complete
            save.roster.gold = 100
            save.homestead = PlayerHomesteadState(
                resources: [.wood: 99, .herbs: 99],
                nodeTiers: [.wheatField: 1, .wishingWell: 1],
                lastProductionAt: Date(timeIntervalSince1970: 2000000000),
            )
        }
    }
}
