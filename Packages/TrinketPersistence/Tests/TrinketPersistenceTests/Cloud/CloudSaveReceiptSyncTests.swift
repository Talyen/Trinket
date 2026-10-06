import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

extension CloudSaveSyncTests {
    @Test(arguments: [false, true]) @MainActor
    func `incomplete receipts refuse the entire save and journal through reload`(partial: Bool) async throws {
        let transport = CloudSaveTestTransport()
        let context = try PersistenceTestContext()
        let store = try cloudStore(context, transport: transport)
        #expect(await store.cloudSync?.synchronize() == true)
        let before = store.currentSave
        let journal = store.cloudDeviceState.account.journal
        #expect(!store.persistBatch(logging: "Incomplete receipt") { save, recordReceipt in
            save.roster.gold += 10
            if partial {
                recordReceipt(SaveEconomicReceipt(kind: .reward, effects: .committed(gold: 5)))
            }
        })
        #expect(store.currentSave == before)
        #expect(store.cloudDeviceState.account.journal == journal)
        guard case .invalidSave? = store.lastPersistenceError else { Issue.record("Expected invalid receipt coverage"); return }
        #expect(try context.makeReloadedStore().currentSave == before)
    }

    @Test @MainActor func `Mystery claims and forging retain separate effects through concurrent replay and response loss`() async throws {
        let transport = CloudSaveTestTransport()
        let first = try PersistenceTestContext()
        let second = try PersistenceTestContext()
        let a = try cloudStore(first, transport: transport)
        #expect(a.persistBatch(logging: "Economic command setup") { save in
            save.starterSelection = .complete
            save.inventory.items = []
            save.homestead = PlayerHomesteadState(
                resources: [.iron: 500, .wood: 500, .hide: 500], nodeTiers: [.blacksmithForge: 1],
                lastProductionAt: Date(timeIntervalSince1970: 2000000000),
            )
        })
        #expect(await a.cloudSync?.synchronize() == true)
        let b = try cloudStore(second, transport: transport)
        #expect(await b.cloudSync?.synchronize() == true)
        let event = try #require(GameContent.mysteryEvent(matching: "crystal-geode"))
        let date = Date(timeIntervalSince1970: 2000000000)
        var expectedGems = 0
        for store in [a, b] {
            var random = SeededRandomNumberGenerator(seed: 11)
            let encounter = EncounterIdentity(location: .journey(stageID: "chapter-1-stage-4"), save: store.currentSave)
            guard case let .committed(offers) = store.prepareMysteryEncounter(event: event, encounter: encounter, using: &random, at: date),
                  let offer = offers.first else { Issue.record("Expected pinned Mystery offers"); return }
            expectedGems = offer.bonus.amount
            let request = MysteryEncounterRequest(encounter: encounter, event: event, displayedOffers: offers)
            guard case .committed(.reward) = store.resolveMysteryEncounter(
                request,
                action: .choice(offer.choiceID),
                using: &random,
                at: date,
            )
            else { Issue.record("Expected committed Mystery choice"); return }
        }
        let forged = try await b.forgeBlacksmithItem(recipeID: "blacksmith-dagger").get()
        let expectedIron = b.homestead.resources[.iron]
        let expectedWood = b.homestead.resources[.wood]
        #expect(await a.cloudSync?.synchronize() == true)
        await transport.configure(loseResponse: true)
        #expect(await b.cloudSync?.synchronize() == false)
        let reloaded = try cloudStore(second, transport: transport)
        #expect(await reloaded.cloudSync?.synchronize() == true)
        #expect(reloaded.homestead.resources[.gems] == expectedGems)
        #expect(reloaded.homestead.resources[.iron] == expectedIron)
        #expect(reloaded.homestead.resources[.wood] == expectedWood)
        #expect(reloaded.inventory.item(matching: forged.id) == forged)
        let durable = try second.makeReloadedStore()
        #expect(durable.homestead.resources == reloaded.homestead.resources)
        #expect(durable.inventory.item(matching: forged.id) == forged)
    }

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
