import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct CloudSaveMergeTests {
    @Test func `spending an earned Contract refresh stays spent after replay`() {
        var base = PlayerSave.testSeed
        base.contracts.earnRefresh()
        var spent = base
        let didRefresh = spent.contracts.refresh()
        #expect(didRefresh)

        let merged = CloudSaveMerge.merge(incoming: spent, existing: base, base: base, preferIncoming: true)
        #expect(!merged.contracts.refreshAvailable)
        #expect(merged.contracts.offers == spent.contracts.offers)
    }

    @Test func `different offline Mystery choices preserve both earned items and secondary Gold`() throws {
        var base = PlayerSave.testSeed
        base.inventory.items = []
        base.roster.gold = 10
        let stageID = "chapter-1-stage-4"
        let templates = GameContent.sampleInventoryItems.filter { $0.rarity == .basic }
        let first = try #require(templates.first).rewardInstance(for: "\(stageID)-left")
        let second = try #require(templates.dropFirst().first).rewardInstance(for: "\(stageID)-right")
        var left = base
        left.inventory.appendUniqueItem(first)
        left.journey.claimedRewardStageIDs.insert(stageID)
        left.roster.gold = 20
        var right = base
        right.inventory.appendUniqueItem(second)
        right.journey.claimedRewardStageIDs.insert(stageID)
        right.roster.gold = 30

        let merged = CloudSaveMerge.merge(incoming: left, existing: right, base: base, preferIncoming: true)
        #expect(merged.inventory.items.map(\.id).contains(first.id))
        #expect(merged.inventory.items.map(\.id).contains(second.id))
        #expect(merged.roster.gold == 40)
        #expect(merged.journey.claimedRewardStageIDs.contains(stageID))
    }

    @Test func `unrelated older saves keep the larger resource balance and both items`() throws {
        var first = PlayerSave.testSeed
        first.inventory.items = []
        first.roster.gold = 20
        first.homestead.resources[.wood] = 50
        var second = first
        second.roster.gold = 30
        second.homestead.resources[.wood] = 40
        try first.inventory.appendUniqueItem(#require(GameContent.sampleInventoryItems.first))
        try second.inventory.appendUniqueItem(#require(GameContent.sampleInventoryItems.dropFirst().first))

        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: nil, preferIncoming: false)
        #expect(merged.roster.gold == 30)
        #expect(merged.homestead.resources[.wood] == 50)
        #expect(merged.inventory.items.count == 2)
    }

    @Test func `different offline upgrades both survive shared material spending`() {
        var base = PlayerSave.testSeed
        base.homestead.resources = [.wood: 20]
        base.homestead.nodeTiers = [:]
        var first = base
        first.homestead.resources[.wood] = 10
        first.homestead.nodeTiers[.wheatField] = 1
        var second = base
        second.homestead.resources[.wood] = 10
        second.homestead.nodeTiers[.herbGarden] = 1

        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: true)
        #expect(merged.homestead.tier(for: .wheatField) == 1)
        #expect(merged.homestead.tier(for: .herbGarden) == 1)
        #expect(merged.homestead.resources[.wood] == 0)
    }

    @Test func `a Unique claimed on both devices remains one copy`() throws {
        var base = PlayerSave.testSeed
        base.inventory.items = []
        let unique = try #require(GameContent.uniqueItems.first)
        var first = base
        var second = base
        first.inventory.appendUniqueItem(unique)
        second.inventory.appendUniqueItem(unique)
        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: true)
        #expect(merged.inventory.items.count(where: { $0.templateID == unique.templateID }) == 1)
    }

    @Test func `same Contract offer cannot pay twice across offline devices`() throws {
        var base = PlayerSave.testSeed
        base.roster.gold = 10
        base.contracts.ensureBoard()
        let offer = try #require(base.contracts.offer(for: .easy))
        var first = base
        var second = base
        _ = first.contracts.replace(offerID: offer.id)
        _ = second.contracts.replace(offerID: offer.id)
        first.roster.gold = 20
        second.roster.gold = 20

        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: true)
        #expect(merged.roster.gold == 20)
    }

    @Test func `latest party choice wins while both devices keep earned inventory`() throws {
        var base = PlayerSave.testSeed
        base.inventory.items = []
        let items = GameContent.sampleInventoryItems
        var older = base
        try older.inventory.appendUniqueItem(#require(items.first))
        older.modifiedAt = Date(timeIntervalSince1970: 100)
        var newer = base
        try newer.inventory.appendUniqueItem(#require(items.dropFirst().first))
        newer.roster.activeHeroID = "rogue"
        newer.modifiedAt = Date(timeIntervalSince1970: 200)

        let merged = CloudSaveMerge.merge(incoming: older, existing: newer, base: base, preferIncoming: true)
        #expect(merged.roster.activeHeroID == "rogue")
        #expect(merged.inventory.items.count == 2)
    }

    @Test func `an equipment edit survives a later unrelated device action`() {
        let base = PlayerSave.testSeed
        var equipped = base
        equipped.roster.equipmentLoadouts["knight"]?.itemIDsBySlot[.weapon] = "dagger-basic"
        equipped.modifiedAt = Date(timeIntervalSince1970: 100)
        var later = base
        later.roster.gold += 5
        later.modifiedAt = Date(timeIntervalSince1970: 200)

        let merged = CloudSaveMerge.merge(incoming: equipped, existing: later, base: base, preferIncoming: false)
        #expect(merged.roster.equipmentLoadouts["knight"]?.itemID(for: .weapon) == "dagger-basic")
        #expect(merged.roster.gold == base.roster.gold + 5)
    }

    @Test func `salvaged gear stays removed when a later device earns Gold`() throws {
        var base = PlayerSave.testSeed
        let item = try #require(GameContent.sampleInventoryItems.first)
        base.inventory.items = [item]
        var salvaged = base
        salvaged.inventory.removeItem(id: item.id)
        salvaged.modifiedAt = Date(timeIntervalSince1970: 100)
        var later = base
        later.roster.gold += 5
        later.modifiedAt = Date(timeIntervalSince1970: 200)

        let merged = CloudSaveMerge.merge(incoming: salvaged, existing: later, base: base, preferIncoming: false)
        #expect(merged.inventory.item(matching: item.id) == nil)
        #expect(merged.roster.gold == base.roster.gold + 5)
    }

    @Test(arguments: [true, false])
    func `corrupted gear survives a later unrelated device action`(corruptionIsIncoming: Bool) throws {
        let baseType = try #require(GameContent.itemBaseType(matching: "longsword"))
        var random = SeededRandomNumberGenerator(seed: 42)
        let item = ItemGenerator().generate(
            id: "cloud-sword", baseType: baseType, rarity: .basic,
            fixedAffixCount: 2, using: &random,
        )
        let unchanged = try #require(GameContent.sampleInventoryItems.first)
        let corrupted = try #require(ItemCorruption.corrupt(item, using: &random)).item
        var base = PlayerSave.testSeed
        base.inventory.items = [item, unchanged]
        base.modifiedAt = Date(timeIntervalSince1970: 1)
        var changed = base
        changed.inventory.items[0] = corrupted
        changed.modifiedAt = Date(timeIntervalSince1970: 100)
        var later = base
        later.roster.gold += 5
        later.modifiedAt = Date(timeIntervalSince1970: 200)

        let merged = CloudSaveMerge.merge(
            incoming: corruptionIsIncoming ? changed : later,
            existing: corruptionIsIncoming ? later : changed,
            base: base, preferIncoming: corruptionIsIncoming,
        )
        #expect(merged.inventory.items == [corrupted, unchanged])
        #expect(merged.roster.gold == base.roster.gold + 5)
    }

    @Test func `same Shop offer purchased twice charges once and stays sold out`() throws {
        var base = PlayerSave.testSeed
        base.roster.gold = PlayerRosterState.maxGoldBalance
        base.inventory.items = []
        let encounter = EncounterIdentity(
            location: .journey(stageID: ShopOfferGenerator.starterShopStageID), save: base,
        )
        let stock = try ShopStockPersistence.prepare(encounter: encounter, save: &base).get()
        let offer = try #require(stock.offers.first)
        var first = base
        var second = base
        _ = try ShopPurchaseApplier.purchase(offerID: offer.id, encounter: encounter, save: &first).get()
        _ = try ShopPurchaseApplier.purchase(offerID: offer.id, encounter: encounter, save: &second).get()

        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: true)
        #expect(merged.roster.gold == PlayerRosterState.maxGoldBalance - offer.price)
        #expect(merged.inventory.items.count(where: { $0.id == offer.item.id }) == 1)
        let savedStock = try ShopStockPersistence.stock(encounter: encounter, save: merged)
        let mergedStock = try #require(savedStock)
        #expect(mergedStock.purchasedOfferIDs == [offer.id])
    }

    @Test func `different offline Shop purchases both remain sold out`() throws {
        var base = PlayerSave.testSeed
        base.roster.gold = PlayerRosterState.maxGoldBalance
        base.inventory.items = []
        let encounter = EncounterIdentity(
            location: .journey(stageID: ShopOfferGenerator.starterShopStageID), save: base,
        )
        let stock = try ShopStockPersistence.prepare(encounter: encounter, save: &base).get()
        let firstOffer = try #require(stock.offers.first)
        let secondOffer = try #require(stock.offers.dropFirst().first)
        var first = base
        var second = base
        _ = try ShopPurchaseApplier.purchase(offerID: firstOffer.id, encounter: encounter, save: &first).get()
        _ = try ShopPurchaseApplier.purchase(offerID: secondOffer.id, encounter: encounter, save: &second).get()

        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: true)
        #expect(merged.roster.gold == PlayerRosterState.maxGoldBalance - firstOffer.price - secondOffer.price)
        let savedStock = try ShopStockPersistence.stock(encounter: encounter, save: merged)
        let mergedStock = try #require(savedStock)
        #expect(mergedStock.purchasedOfferIDs == [firstOffer.id, secondOffer.id])
    }

    @Test func `a purchase of a different offline Shop item does not sell the preferred item`() throws {
        var base = PlayerSave.testSeed
        base.roster.gold = PlayerRosterState.maxGoldBalance
        base.inventory.items = []
        let encounter = EncounterIdentity(
            location: .journey(stageID: ShopOfferGenerator.starterShopStageID), save: base,
        )
        let items = GameContent.sampleInventoryItems.filter { $0.rarity == .basic }
        let preferredItem = try #require(items.first)
        let purchasedItem = try #require(items.first { $0.id != preferredItem.id })
        let offerID = "offline-offer"
        let preferredOffer = ShopOffer(id: offerID, item: preferredItem, price: 20)
        let otherOffer = ShopOffer(id: offerID, item: purchasedItem, price: 25)
        var preferred = base
        var other = base
        let preferredPayload = try ShopStockPersistence.encode(ShopStock(offers: [preferredOffer]), encounter: encounter)
        let otherPayload = try ShopStockPersistence.encode(ShopStock(offers: [otherOffer]), encounter: encounter)
        ShopStockPersistence.setPayload(
            preferredPayload,
            encounter: encounter, save: &preferred,
        )
        ShopStockPersistence.setPayload(
            otherPayload,
            encounter: encounter, save: &other,
        )
        _ = try ShopPurchaseApplier.purchase(offerID: offerID, encounter: encounter, save: &other).get()

        let merged = CloudSaveMerge.merge(incoming: preferred, existing: other, base: base, preferIncoming: true)
        let loaded = try ShopStockPersistence.stock(encounter: encounter, save: merged)
        let stock = try #require(loaded)
        #expect(stock.offers == [preferredOffer])
        #expect(stock.purchasedOfferIDs.isEmpty)
        #expect(ShopPurchaseApplier.availability(offerID: offerID, encounter: encounter, save: merged) == .available)
        #expect(merged.inventory.items.contains(purchasedItem))
    }

    @Test func `a readable offline Shop survives a corrupt preferred stock payload`() throws {
        let base = PlayerSave.testSeed
        let encounter = EncounterIdentity(
            location: .journey(stageID: ShopOfferGenerator.starterShopStageID), save: base,
        )
        let item = try #require(GameContent.sampleInventoryItems.first)
        let offer = ShopOffer(id: "recovered-offer", item: item, price: 20)
        var preferred = base
        preferred.journey.shopPayloads[ShopOfferGenerator.starterShopStageID] = Data([0xFF])
        var other = base
        let payload = try ShopStockPersistence.encode(ShopStock(offers: [offer]), encounter: encounter)
        ShopStockPersistence.setPayload(
            payload,
            encounter: encounter, save: &other,
        )

        let merged = CloudSaveMerge.merge(incoming: preferred, existing: other, base: base, preferIncoming: true)
        let stock = try ShopStockPersistence.stock(encounter: encounter, save: merged)

        #expect(stock?.offers == [offer])
    }

    @Test func `abandoning a Voyage does not restore its old route from another device`() throws {
        var base = PlayerSave.testSeed
        base.modifiedAt = Date(timeIntervalSince1970: 1)
        base.voyage.ensureBoard(access: .fullGame)
        let offer = try #require(base.voyage.offers.first)
        let embarked = base.voyage.embark(offerID: offer.id, eligibleRecruitEventIDs: [], access: .fullGame)
        #expect(embarked)
        let runID = try #require(base.voyage.activeRun?.id)
        let firstNodeID = try #require(base.voyage.activeRun?.nodes.first?.id)
        base.voyage.updateNode(runID: runID, nodeID: firstNodeID) { $0.isCleared = true }
        var abandoned = base
        let didAbandon = abandoned.voyage.abandon(runID: runID, access: .fullGame)
        #expect(didAbandon)
        abandoned.modifiedAt = Date(timeIntervalSince1970: 100)

        let merged = CloudSaveMerge.merge(incoming: abandoned, existing: base, base: base, preferIncoming: true)

        #expect(merged.voyage.activeRun == nil)
        #expect(merged.voyage.offers != base.voyage.offers)

        var progressed = base
        let secondNodeID = try #require(progressed.voyage.activeRun?.nodes.dropFirst().first?.id)
        progressed.voyage.updateNode(runID: runID, nodeID: secondNodeID) { $0.isCleared = true }
        progressed.modifiedAt = Date(timeIntervalSince1970: 200)
        let racing = CloudSaveMerge.merge(incoming: progressed, existing: abandoned, base: base, preferIncoming: true)
        #expect(racing.voyage.activeRun == nil)
    }

    @Test func `a newly unlocked Labyrinth floor keeps its clusters after cloud merge`() throws {
        var base = PlayerSave.testSeed
        base.labyrinth.ensureMap(seed: base.worldSeed)
        let boss = try #require(base.labyrinth.nodes.values.first { $0.type == .boss })
        var expanded = base
        expanded.labyrinth.markCleared(nodeID: boss.id)
        let newCluster = try #require(expanded.labyrinth.clusters.first { $0.depthBand == 2 })
        let nextNodeID = try #require(expanded.labyrinth.node(id: boss.id)?.outgoingIDs.first)

        let merged = CloudSaveMerge.merge(incoming: base, existing: expanded, base: base, preferIncoming: true)
        let sanitized = PlayerSaveSanitizer.sanitize(merged)

        #expect(merged.labyrinth.cluster(id: newCluster.id) == newCluster)
        #expect(newCluster.nodeIDs.allSatisfy { sanitized.labyrinth.node(id: $0) != nil })
        #expect(sanitized.labyrinth.isNodeReachable(nextNodeID))
    }
}
