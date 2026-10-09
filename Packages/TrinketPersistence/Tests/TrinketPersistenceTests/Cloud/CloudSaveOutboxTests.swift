import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct CloudSaveOutboxTests {
    @Test @MainActor func `schema two and legacy pending prefixes migrate without losing later actions`() throws {
        let fixture = try PersistenceTestContext()
        let base = try populatedLegacySave()
        var first = base
        first.roster.gold = 5
        var second = first
        second.roster.gold = 8
        let mutations = [mutation("first", from: base, to: first), mutation("second", from: first, to: second)]
        var state = CloudDeviceState()
        state.activeAccountID = "player-a"
        state.account.journal = CloudSaveJournal(mutations)
        let (pendingState, request) = CloudSaveTransitions.enqueue(
            .upload, state: state, local: CloudSaveSnapshot(first), id: "frozen-upload",
        )
        state = pendingState
        state.account.pending = CloudSaveRequest(
            id: request.id, action: request.action, baseEpoch: request.baseEpoch,
            baseRevisionID: request.baseRevisionID, authoritySequence: request.authoritySequence,
            revision: request.revision, baseSnapshot: request.baseSnapshot,
            mutations: CloudSaveJournal([mutations[0]]),
        )
        try writeLegacyStore(second, state: state, mutations: mutations, at: fixture.storeURL())
        var store: PlayerSaveStore? = try fixture.makeReloadedStore()
        #expect(store?.usesMemoryFallback == false)
        #expect(store?.roster.gold == 8)
        let migrated = try #require(store?.currentSave)
        expectPopulatedState(migrated, matching: second)
        #expect(try Array(#require(store?.cloudDeviceState.account.journal)) == mutations)
        #expect(store?.cloudDeviceState.account.pending?.id == "frozen-upload")
        #expect(try Array(#require(store?.cloudDeviceState.account.pending?.mutations)) == [mutations[0]])
        #expect(store?.persistBatch(logging: "Migrate journal") { $0.roster.gold += 1 } == true)
        store = nil
        let reloaded = try fixture.makeReloadedStore()
        let restoredRequest = try #require(reloaded.cloudDeviceState.account.pending)
        #expect(restoredRequest.id == "frozen-upload")
        #expect(reloaded.cloudDeviceState.formatVersion == 2)
        #expect(try Array(#require(reloaded.cloudDeviceState.account.journal)) == mutations)
        var archivedState = reloaded.cloudDeviceState
        archivedState.archives["other-account"] = CloudAccountArchive(
            snapshot: CloudSaveSnapshot(first), state: CloudAccountState(pending: restoredRequest),
        )
        try reloaded.commitCloudState(archivedState)
        let head = CloudSaveHead(epoch: request.id, resetCount: 0, authoritySequence: 0, revision: request.revision)
        let receipt = CloudSaveReceipt(requestID: request.id, epoch: head.epoch, authoritySequence: 0, outcome: .synchronized)
        let acknowledgement = try #require(try CloudSaveTransitions.acknowledge(
            restoredRequest, receipt: receipt, head: head, accountID: "player-a",
            state: reloaded.cloudDeviceState, local: CloudSaveSnapshot(reloaded.currentSave),
        ))
        try reloaded.commitCloudState(acknowledgement.transition.state)
        let afterReceipt = try fixture.makeReloadedStore()
        #expect(afterReceipt.cloudDeviceState.account.pending == nil)
        #expect(try Array(#require(afterReceipt.cloudDeviceState.account.journal)) == [mutations[1]])
        #expect(afterReceipt.roster.gold == 9)
        expectPopulatedState(afterReceipt.currentSave, matching: migrated)
        #expect(!afterReceipt.isCloudSyncEnabled)
        let archived = try #require(afterReceipt.cloudDeviceState.archives["other-account"]?.state.pending)
        #expect(try Array(#require(archived.mutations)) == [mutations[0]])
    }

    @Test @MainActor func `lost receipt and new offline earnings retain a frozen request across reload`() async throws {
        let fixture = try PersistenceTestContext()
        let transport = CloudSaveTestTransport()
        var store: PlayerSaveStore? = try cloudStore(fixture, transport: transport)
        #expect(await store?.cloudSync?.synchronize() == true)
        #expect(store?.persistBatch(logging: "First reward") { $0.roster.gold += 5 } == true)
        await transport.configure(loseResponse: true)
        #expect(await store?.cloudSync?.synchronize() == false)
        let pending = try #require(store?.cloudDeviceState.account.pending)
        #expect(store?.persistBatch(logging: "Next reward") { $0.roster.gold += 3 } == true)
        let ids = try #require(store?.cloudDeviceState.account.journal?.records.map(\.id))
        #expect(store?.cloudDeviceState.account.pending == pending)
        store = nil
        let reloaded = try cloudStore(fixture, transport: transport)
        #expect(reloaded.cloudDeviceState.account.pending == pending)
        #expect(reloaded.cloudDeviceState.account.journal?.records.map(\.id) == ids)
        #expect(await reloaded.cloudSync?.synchronize() == true)
        #expect(reloaded.roster.gold == 8)
        #expect(reloaded.cloudDeviceState.account.journal?.isEmpty == true)
        #expect(reloaded.cloudOutbox?.storedRecords.isEmpty == true)
        #expect(try fixture.makeReloadedStore().roster.gold == 8)
        #expect(await transport.account().head?.head.revision.snapshot.roster.gold == 8)
    }

    @Test @MainActor func `database recovery preserves rewards and outbox while refused writes leave no phantom actions`() async throws {
        let fixture = try PersistenceTestContext()
        let transport = CloudSaveTestTransport()
        var store: PlayerSaveStore? = try cloudStore(fixture, transport: transport)
        #expect(await store?.cloudSync?.synchronize() == true)
        store?.forcesNextDatabaseSaveFailure = true
        #expect(store?.persistBatch(logging: "Recovered reward") { $0.roster.gold += 7 } == true)
        let ids = try #require(store?.cloudDeviceState.account.journal?.records.map(\.id))
        let recovery = try #require(store?.pendingSaveRecovery)
        #expect(try recovery.read()?.outboxRecords?.count == 2)
        store = nil
        let reloaded = try cloudStore(fixture, transport: transport)
        #expect(reloaded.roster.gold == 7)
        #expect(reloaded.cloudDeviceState.account.journal?.records.map(\.id) == ids)
        #expect(!reloaded.isPersistenceDegraded)
        reloaded.forcesNextSaveFailure = true
        #expect(!reloaded.persistBatch(logging: "Refused reward") { $0.roster.gold += 100 })
        #expect(reloaded.roster.gold == 7)
        #expect(reloaded.cloudDeviceState.account.journal?.records.map(\.id) == ids)
        #expect(reloaded.cloudOutbox?.storedRecords.count == 2)
        #expect(reloaded.persistBatch(logging: "Later accepted reward") { $0.roster.gold += 2 })
        #expect(await reloaded.cloudSync?.synchronize() == true)
        #expect(reloaded.roster.gold == 9)
        #expect(try fixture.makeReloadedStore().roster.gold == 9)
        #expect(await transport.account().head?.head.revision.snapshot.roster.gold == 9)
    }

    @Test @MainActor func `a missing outbox record disables sync while preserving local progress and opaque metadata`() async throws {
        let fixture = try PersistenceTestContext()
        let transport = CloudSaveTestTransport()
        var store: PlayerSaveStore? = try cloudStore(fixture, transport: transport)
        #expect(await store?.cloudSync?.synchronize() == true)
        #expect(store?.persistBatch(logging: "Saved reward") { $0.roster.gold += 7 } == true)
        let metadata = try #require(store?.root.cloudStatePayload)
        let context = try #require(store?.context)
        let row = try #require(context.fetch(FetchDescriptor<CloudOutboxRecord>()).first { $0.index == 0 })
        context.delete(row)
        try context.save()
        store = nil
        let reloaded = try cloudStore(fixture, transport: transport)
        #expect(!reloaded.isCloudSyncEnabled)
        #expect(reloaded.preservesUnreadableCloudState)
        #expect(reloaded.roster.gold == 7)
        #expect(reloaded.persistBatch(logging: "Local-only reward") { $0.roster.gold += 2 })
        let local = try fixture.makeReloadedStore()
        #expect(local.roster.gold == 9)
        #expect(local.root.cloudStatePayload == metadata)
    }

    private func expectPopulatedState(_ actual: PlayerSave, matching expected: PlayerSave) {
        #expect(actual.inventory == expected.inventory)
        #expect(actual.roster.equipmentLoadouts == expected.roster.equipmentLoadouts)
        #expect(actual.roster.unlockedTalents == expected.roster.unlockedTalents)
        #expect(actual.homestead == expected.homestead)
        #expect(actual.labyrinth == expected.labyrinth)
        #expect(actual.voyage == expected.voyage)
        #expect(actual.journey.shopPayloads == expected.journey.shopPayloads)
    }

    private func populatedLegacySave() throws -> PlayerSave {
        var base = PlayerSave.testSeed
        base.worldSeed = 99
        let hero = base.roster.activeHero
        let tree = try #require(CombatantTalentCatalog.allConfigs[hero.id]?.trees.first)
        let talent = try #require(tree.nodes.first)
        base.roster.progressions[hero.id] = .at(level: 6)
        base.roster.unlockedTalents[hero.id] = [talent.id]
        base.labyrinth.ensureMap(seed: 99)
        base.labyrinth.hasEntered = true
        base.voyage.ensureBoard(access: .fullGame)
        let offer = try #require(base.voyage.offers.first)
        #expect(base.voyage.embark(offerID: offer.id, eligibleRecruitEventIDs: [], access: .fullGame))
        let encounter = EncounterIdentity(location: .journey(stageID: ShopOfferGenerator.starterShopStageID), save: base)
        let item = try #require(base.inventory.items.first)
        let stock = ShopStock(offers: [ShopOffer(id: "migrated-pinned-offer", item: item, price: 3)])
        let payload = try ShopStockPersistence.encode(stock, encounter: encounter)
        ShopStockPersistence.setPayload(payload, encounter: encounter, save: &base)
        return base
    }

    private func mutation(_ id: String, from before: PlayerSave, to after: PlayerSave) -> CloudSaveMutation {
        CloudSaveMutation(
            id: id, changedSliceMask: PlayerSaveSlice.all.rawValue,
            before: CloudSaveSnapshot(before), after: CloudSaveSnapshot(after),
            economy: CloudEconomicAction.record(from: before, to: after),
        )
    }

    @MainActor private func cloudStore(_ fixture: PersistenceTestContext, transport: CloudSaveTestTransport) throws -> PlayerSaveStore {
        let schema = PlayerSaveGraph.schema
        let configuration = ModelConfiguration(schema: schema, url: fixture.storeURL(), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, migrationPlan: PlayerSaveMigrationPlan.self, configurations: configuration)
        return try PlayerSaveStore(
            openResult: .init(container: container, usedInMemoryFallback: false),
            cloudSyncEnabled: true, cloudTransport: transport, recoveryConfiguration: configuration,
        )
    }

    @MainActor private func writeLegacyStore(
        _ save: PlayerSave, state: CloudDeviceState, mutations: [CloudSaveMutation], at url: URL,
    ) throws {
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        object["formatVersion"] = 1
        var account = try #require(object["account"] as? [String: Any])
        account["journal"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(mutations))
        var pending = try #require(account["pending"] as? [String: Any])
        pending["mutations"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode([mutations[0]]))
        account["pending"] = pending
        object["account"] = account
        let metadata = try JSONSerialization.data(withJSONObject: object)
        let schema = Schema(versionedSchema: PlayerSaveSchemaV2.self)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none),
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let root = PlayerSaveRoot(save: save)
        root.cloudStatePayload = metadata
        context.insert(root)
        try context.save()
    }
}
