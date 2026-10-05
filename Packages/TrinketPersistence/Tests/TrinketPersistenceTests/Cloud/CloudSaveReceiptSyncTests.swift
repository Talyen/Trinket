import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

extension CloudSaveSyncTests {
    @Test @MainActor func `capped production receipts survive spending response loss and reload without paying twice`() async throws {
        let transport = CloudSaveTestTransport()
        let first = try PersistenceTestContext()
        let second = try PersistenceTestContext()
        let a = try cloudStore(first, transport: transport)
        try seedHomestead(a)
        try a.performBatchMutation { $0.roster.gold = PlayerRosterState.maxGoldBalance - 1 }
        #expect(await a.cloudSync?.synchronize() == true)
        var b: PlayerSaveStore? = try cloudStore(second, transport: transport)
        #expect(await b?.cloudSync?.synchronize() == true)
        let day = PlayerHomesteadState.secondsPerDay
        let date = Date(timeIntervalSince1970: 2000000000).addingTimeInterval(day)
        await transport.advance(day)
        _ = await a.collectProduction(at: date)
        let secondStore = try #require(b)
        #expect(secondStore.persistBatch(logging: "Spend before collecting") { $0.applyGoldDelta(-5, at: date) })
        _ = await secondStore.collectProduction(at: date)
        #expect(await a.cloudSync?.synchronize() == true)
        #expect(await secondStore.cloudSync?.synchronize() == true)
        #expect(secondStore.roster.gold == PlayerRosterState.maxGoldBalance - 5)
        #expect(secondStore.homestead.pendingProduction[.gold, default: 0] == 0)
        await transport.advance(day)
        _ = await secondStore.collectProduction(at: date.addingTimeInterval(day))
        let actions = try #require(secondStore.cloudDeviceState.account.journal)
        await transport.configure(loseResponse: true)
        #expect(await secondStore.cloudSync?.synchronize() == false)
        let frozen = try #require(secondStore.cloudDeviceState.account.pending)
        b = nil
        let reloaded = try cloudStore(second, transport: transport)
        #expect(reloaded.cloudDeviceState.account.pending == frozen)
        #expect(reloaded.cloudDeviceState.account.journal == actions)
        #expect(reloaded.cloudDeviceState.formatVersion == 3)
        #expect(await reloaded.cloudSync?.synchronize() == true)
        #expect(reloaded.roster.gold == PlayerRosterState.maxGoldBalance - 4)
        #expect(reloaded.homestead.pendingProduction[.gold, default: 0] == 0)
        #expect(await transport.account().head?.head.formatVersion == 2)
        #expect(try second.makeReloadedStore().roster.gold == reloaded.roster.gold)
    }

    @Test @MainActor func `composite salvage receipts preserve independent materials and discard refused actions through reload`(
    ) async throws {
        let transport = CloudSaveTestTransport()
        let first = try PersistenceTestContext()
        let second = try PersistenceTestContext()
        var a: PlayerSaveStore? = try cloudStore(first, transport: transport)
        let item = try #require(GameContent.sampleInventoryItems.first { ItemSalvage.isEligible($0) })
        let items = ["shared", "first", "second"].map { item.rewardInstance(for: "receipt-\($0)") }
        let initial = try #require(a)
        #expect(initial.persistBatch(logging: "Salvage setup") { save in
            save.starterSelection = .complete
            save.inventory.items = items
            save.homestead.resources = [:]
        })
        #expect(await initial.cloudSync?.synchronize() == true)
        let b = try cloudStore(second, transport: transport)
        #expect(await b.cloudSync?.synchronize() == true)
        enum Rejection: Error { case cancelled }
        let rejected: SaveTransactionResult<Void, Rejection> = initial
            .persistTransaction(logging: "Rejected batch") { save, recordReceipt in
                _ = ItemSalvageApplier.salvage(itemID: items[0].id, save: &save, recordReceipt: recordReceipt)
                return .failure(.cancelled)
            }
        guard case .rejected = rejected else { Issue.record("Expected rejection"); return }
        #expect(initial.inventory.items == items)
        #expect(initial.cloudDeviceState.account.journal == nil)
        #if DEBUG
        initial.forcesNextSaveFailure = true
        #expect(!initial.persistBatch(logging: "Refused batch") { save, recordReceipt in
            _ = ItemSalvageApplier.salvage(itemID: items[0].id, save: &save, recordReceipt: recordReceipt)
        })
        #expect(initial.inventory.items == items)
        #expect(initial.cloudDeviceState.account.journal == nil)
        #endif
        for (store, unique) in [(initial, items[1]), (b, items[2])] {
            #expect(store.persistBatch(logging: "Composite salvage") { save, recordReceipt in
                for candidate in [items[0], unique] {
                    guard case .success = ItemSalvageApplier.salvage(itemID: candidate.id, save: &save, recordReceipt: recordReceipt)
                    else { Issue.record("Expected salvage"); return }
                }
            })
        }
        a = nil
        #expect(await b.cloudSync?.synchronize() == true)
        let reloaded = try cloudStore(first, transport: transport)
        #expect(await reloaded.cloudSync?.synchronize() == true)
        #expect(reloaded.inventory.items.isEmpty)
        for amount in ItemSalvage.yields(for: item) {
            #expect(reloaded.homestead.resources[amount.resource] == amount.quantity * 3)
        }
        let durable = try first.makeReloadedStore()
        #expect(durable.inventory.items.isEmpty)
        #expect(durable.homestead.resources == reloaded.homestead.resources)
    }
}
