import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct ShopPurchaseApplierTests {
    @Test func `purchase settles production before opening gold capacity`() throws {
        var save = SaveTestSupport.makeSave(modifiedAt: .now, gold: PlayerRosterState.maxGoldBalance)
        let start = Date.now.addingTimeInterval(-PlayerHomesteadState.secondsPerDay)
        save.homestead = PlayerHomesteadState(resources: [:], nodeTiers: [.wishingWell: 1], lastProductionAt: start)
        let offer = try makeOffer(price: 28)
        let encounter = try pin([offer], in: &save)
        let purchased = try ShopPurchaseApplier.purchase(offerID: offer.id, encounter: encounter, save: &save).get()
        #expect(purchased == offer.item)
        #expect(save.roster.gold == PlayerRosterState.maxGoldBalance - offer.price)
        #expect(save.homestead.lastProductionAt > start)
        let collected = save.homestead.collectProduction(at: save.homestead.lastProductionAt, roster: &save.roster)
        #expect(collected.isEmpty)
    }

    @Test(arguments: [10, 100])
    func `purchase uses pinned price and availability`(gold: Int) throws {
        var save = SaveTestSupport.makeSave(modifiedAt: .now, gold: gold)
        let offer = try makeOffer(price: 28)
        let encounter = try pin([offer], in: &save)
        let before = save
        let availability = ShopPurchaseApplier.availability(offerID: offer.id, encounter: encounter, save: save)
        let result = ShopPurchaseApplier.purchase(offerID: offer.id, encounter: encounter, save: &save)
        if gold < offer.price {
            #expect(availability == .unavailable(.insufficientGold))
            #expect(result == .failure(.insufficientGold))
            #expect(save == before)
        } else {
            #expect(availability == .available)
            #expect(try result.get() == offer.item)
            #expect(save.roster.gold == gold - offer.price)
            #expect(save.inventory.items == before.inventory.items + [offer.item])
        }
    }

    @Test func `invalid stock and unpinned offers cannot spend gold`() throws {
        var save = SaveTestSupport.makeSave(modifiedAt: .now, gold: 100)
        let offer = try makeOffer(price: -20)
        let encounter = try pin([offer], in: &save)
        let before = save
        #expect(ShopPurchaseApplier.purchase(offerID: offer.id, encounter: encounter, save: &save) == .failure(.invalidOffer))
        #expect(ShopPurchaseApplier.purchase(offerID: "unlisted", encounter: encounter, save: &save) == .failure(.invalidOffer))
        #expect(save == before)
    }

    @Test(arguments: [false, true]) @MainActor
    func `purchase salvage reopen and reload preserve sold stock`(labyrinth: Bool) throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let encounter = try prepareStore(store, labyrinth: labyrinth)
        let loaded = try ShopStockPersistence.stock(encounter: encounter, save: store.currentSave)
        let original = try #require(loaded)
        let offer = try #require(original.offers.first)
        let result = store.persistTransaction(logging: "Buy shop item") { save in
            ShopPurchaseApplier.purchase(offerID: offer.id, encounter: encounter, save: &save)
        }
        guard case let .committed(item) = result else { Issue.record("Expected purchase"); return }
        guard case .success = store.salvageItem(id: item.id) else { Issue.record("Expected salvage"); return }
        let reloaded = try context.makeReloadedStore()
        let gold = reloaded.roster.gold
        let reopened = reloaded.persistTransaction(logging: "Reopen shop") { save in
            ShopStockPersistence.prepare(encounter: encounter, save: &save)
        }
        guard case let .committed(stock) = reopened else { Issue.record("Expected saved stock"); return }
        #expect(stock.offers == original.offers)
        #expect(stock.purchasedOfferIDs == [offer.id])
        #expect(ShopPurchaseApplier
            .availability(offerID: offer.id, encounter: encounter, save: reloaded.currentSave) == .unavailable(.soldOut))
        let repeatPurchase = reloaded.persistTransaction(logging: "Repeat purchase") { save in
            ShopPurchaseApplier.purchase(offerID: offer.id, encounter: encounter, save: &save)
        }
        guard case .rejected(.soldOut) = repeatPurchase else { Issue.record("Expected sold out"); return }
        #expect(reloaded.roster.gold == gold)
        #expect(reloaded.inventory.item(matching: item.id) == nil)
    }

    @Test(arguments: [false, true])
    func `singleton ownership is separate from purchased stock`(unique: Bool) throws {
        let item = try #require(unique ? GameContent.unique(matching: "wardbreaker") : GameContent.trinketItems.first)
        var save = SaveTestSupport.makeSave(modifiedAt: .now, gold: 200)
        let first = ShopOffer(id: "first", item: item, price: 20)
        let second = ShopOffer(id: "second", item: item, price: 20)
        let encounter = try pin([first, second], in: &save)
        #expect(try ShopPurchaseApplier.purchase(offerID: first.id, encounter: encounter, save: &save).get() == item)
        #expect(ShopPurchaseApplier.availability(offerID: first.id, encounter: encounter, save: save) == .unavailable(.soldOut))
        #expect(ShopPurchaseApplier.availability(offerID: second.id, encounter: encounter, save: save) == .unavailable(.alreadyOwned))
        #expect(ShopPurchaseApplier.purchase(offerID: second.id, encounter: encounter, save: &save) == .failure(.alreadyOwned))
        #expect(save.roster.gold == 180)
    }

    @Test func `different encounters own independent stock and stale generations fail closed`() throws {
        var save = SaveTestSupport.makeSave(modifiedAt: .now, gold: 200)
        let first = try makeOffer(price: 20)
        let encounter = try pin([first], in: &save)
        _ = try ShopPurchaseApplier.purchase(offerID: first.id, encounter: encounter, save: &save).get()
        let otherStage = try #require(GameContent.chapters.flatMap(\.stages).first {
            if case .shop = $0.encounter {
                $0.id != ShopOfferGenerator.starterShopStageID
            } else {
                false
            }
        })
        let other = EncounterIdentity(location: .journey(stageID: otherStage.id), save: save)
        let stock = try ShopStockPersistence.prepare(encounter: other, save: &save).get()
        let offer = try #require(stock.offers.first)
        #expect(ShopPurchaseApplier.availability(offerID: offer.id, encounter: other, save: save) == .available)
        save.sessionGeneration += 1
        #expect(ShopPurchaseApplier.purchase(offerID: offer.id, encounter: other, save: &save) == .failure(.invalidOffer))
    }

    #if DEBUG
    @Test @MainActor func `failed purchase rolls back stock and money then retry survives reload`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let offer = try makeOffer(price: 20)
        var encounter: EncounterIdentity?
        try store.performBatchMutation { save in
            save.roster.gold = 100
            encounter = try? pin([offer], in: &save)
        }
        let identity = try #require(encounter)
        let before = store.currentSave
        store.forcesNextSaveFailure = true
        let failed = store.persistTransaction(logging: "Fail purchase") { save in
            ShopPurchaseApplier.purchase(offerID: offer.id, encounter: identity, save: &save)
        }
        guard case .persistFailed = failed else { Issue.record("Expected persistence failure"); return }
        #expect(store.currentSave == before)
        let retried = store.persistTransaction(logging: "Retry purchase") { save in
            ShopPurchaseApplier.purchase(offerID: offer.id, encounter: identity, save: &save)
        }
        guard case .committed = retried else { Issue.record("Expected successful retry"); return }
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.gold == 80)
        #expect(ShopPurchaseApplier
            .availability(offerID: offer.id, encounter: identity, save: reloaded.currentSave) == .unavailable(.soldOut))
    }
    #endif

    @MainActor
    private func prepareStore(_ store: PlayerSaveStore, labyrinth: Bool) throws -> EncounterIdentity {
        var save = store.currentSave
        save.roster.gold = 200
        let location: EncounterIdentity.Location
        if labyrinth {
            save.labyrinth.ensureMap(seed: 55)
            let node = try #require(save.labyrinth.nodes.values.first { $0.type == .shop })
            save.labyrinth.nodes[node.id]?.isRevealed = true
            save.labyrinth.nodes[LabyrinthGenerator.entranceNodeID]?.outgoingIDs.append(node.id)
            location = .labyrinth(nodeID: node.id)
        } else {
            location = .journey(stageID: ShopOfferGenerator.starterShopStageID)
        }
        let encounter = EncounterIdentity(location: location, save: save)
        let offer = try makeOffer(price: 20)
        let payload = try ShopStockPersistence.encode(ShopStock(offers: [offer]), encounter: encounter)
        ShopStockPersistence.setPayload(payload, encounter: encounter, save: &save)
        try store.performBatchMutation { $0 = save }
        return encounter
    }

    private func pin(_ offers: [ShopOffer], in save: inout PlayerSave) throws -> EncounterIdentity {
        let encounter = EncounterIdentity(location: .journey(stageID: ShopOfferGenerator.starterShopStageID), save: save)
        let data = try ShopStockPersistence.encode(ShopStock(offers: offers), encounter: encounter)
        ShopStockPersistence.setPayload(data, encounter: encounter, save: &save)
        return encounter
    }

    private func makeOffer(price: Int) throws -> ShopOffer {
        let item = try SaveTestSupport.makeGeneratedItem(
            baseID: "longsword",
            rarity: .basic,
            id: "shop-offer-0",
            templateID: "longsword-basic",
            seed: 7,
        )
        return ShopOffer(id: "shop-offer-0", item: item, price: price)
    }
}
