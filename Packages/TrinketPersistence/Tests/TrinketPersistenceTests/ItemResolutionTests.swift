import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

/// Degradation policy shared by the three item codecs (see
/// `ItemResolution`): unknown bases drop the item, unknown keywords are
/// stripped, unknown rarities fall back to basic. Pure in-memory coverage.
struct ItemResolutionTests {
    private static func storedItem(
        baseTypeID: String = "longsword",
        rarityID: String = Rarity.basic.rawValue,
        keywords: Set<Keyword> = [.physical],
    ) -> InventoryItem {
        InventoryItem(
            id: "test-item",
            templateID: "test-template",
            baseType: GameContent.itemBaseType(matching: baseTypeID) ?? ItemBaseType(
                id: baseTypeID, name: baseTypeID, slot: .weapon, keywordAffinities: [.physical],
            ),
            rarity: Rarity(rawValue: rarityID) ?? .basic,
            displayName: "Test Item",
            affixes: [ItemAffix(id: "test-affix", title: "Test", description: "Test", keywords: keywords)],
        )
    }

    @Test func `swift data codec drops unknown base and falls back rarity`() {
        let unknown = InventoryItemModel()
        unknown.id = "ghost"
        unknown.baseTypeID = "removed-family"
        let weirdRarity = InventoryItemModel()
        weirdRarity.id = "weird"
        weirdRarity.baseTypeID = "longsword"
        weirdRarity.rarityID = "mythic"
        let model = InventoryModel()
        model.items = [unknown, weirdRarity]

        let state = model.toPlayerInventoryState()
        #expect(state.items.map(\.id) == ["weird"])
        #expect(state.items.first?.rarity == .basic)
    }

    @Test func `cloud codec drops unknown base instead of rejecting snapshot`() throws {
        let homeless = CloudItemSnapshot(
            Self.storedItem(baseTypeID: "removed-family"),
        )
        #expect(homeless.restored() == nil)

        var save = PlayerSaveSanitizer.sanitize(.testSeed)
        save.sessionGeneration = 0
        let snapshot = CloudSaveSnapshot(save)
        #expect(try snapshot.restored() == save)
    }

    @Test func `json codecs strip unknown keywords instead of failing payload`() throws {
        let json = Data("""
        {"id":"a","title":"T","description":"D","keywords":["Physical","Removed-Keyword"],"isCorrupted":false}
        """.utf8)
        let stored = try JSONDecoder().decode(StoredInventoryItem.StoredAffix.self, from: json)
        #expect(stored.keywords == [.physical])
        #expect(stored.resolved.id == "a")

        let cloudJSON = Data("""
        {"id":"a","title":"T","description":"D","keywords":["Burn","Removed-Keyword"],"isCorrupted":false}
        """.utf8)
        let cloud = try JSONDecoder().decode(CloudItemSnapshot.Affix.self, from: cloudJSON)
        #expect(cloud.keywords == [.burn])
    }

    @Test func `offer codecs drop homeless options but keep valid ones`() {
        let homeless = StoredInventoryItem(Self.storedItem(baseTypeID: "removed-family"))
        #expect(homeless.resolved() == nil)
        #expect(StoredInventoryItem(Self.storedItem()).resolved() != nil)
    }

    @Test func `offer codec falls back to basic on unknown rarity`() throws {
        let encoded = try JSONEncoder().encode(StoredInventoryItem(Self.storedItem()))
        var object = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["rarity"] = "mythic"
        let tampered = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(StoredInventoryItem.self, from: tampered)
        #expect(decoded.rarity == .basic)
        #expect(decoded.resolved() != nil)
    }

    @Test func `cloud codec falls back to basic on unknown rarity`() throws {
        let encoded = try JSONEncoder().encode(CloudItemSnapshot(Self.storedItem()))
        var object = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["rarity"] = "mythic"
        let tampered = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(CloudItemSnapshot.self, from: tampered)
        #expect(decoded.rarity == .basic)
        #expect(decoded.restored() != nil)
    }

    @Test func `trinket overwrite drops stored powers`() throws {
        let template = try #require(GameContent.trinketItems.first)
        let stored = InventoryItem(
            id: "trinket-1",
            templateID: template.templateID,
            baseType: template.baseType,
            rarity: .basic,
            displayName: "Stale",
            affixes: [ItemAffix(id: "stale", title: "Stale", description: "Stale", keywords: [])],
            affixPowers: [ItemAffixPower(description: "stale", modifiers: [])],
        )
        let resolved = ItemResolution.trinketAuthoritativeItem(
            persisted: stored,
            baseSlot: template.baseType.slot,
            templateID: template.templateID,
        )
        let authoritative = try #require(resolved)
        #expect(authoritative.affixes == template.affixes)
        #expect(authoritative.affixPowers == nil)
        #expect(authoritative.rarity == template.rarity)
    }

    @Test func `shop codec resolves even when purchased offer is homeless`() throws {
        let validItem = Self.storedItem(baseTypeID: "longsword")
        let homelessItem = Self.storedItem(baseTypeID: "removed-family")
        let stock = ShopStock(
            offers: [
                ShopOffer(id: "offer-valid", item: validItem, price: 10),
                ShopOffer(id: "offer-homeless", item: homelessItem, price: 20),
            ],
            purchasedOfferIDs: ["offer-homeless"],
        )
        var save = PlayerSave.fresh
        let encounter = EncounterIdentity(location: .journey(stageID: ShopOfferGenerator.starterShopStageID), save: save)
        let data = try ShopStockPersistence.encode(stock, encounter: encounter)
        save.journey.shopPayloads[ShopOfferGenerator.starterShopStageID] = data
        let loaded = try #require(try ShopStockPersistence.stock(encounter: encounter, save: save))
        #expect(loaded.offers.map(\.id) == ["offer-valid"])
        #expect(loaded.purchasedOfferIDs.isEmpty)
    }
}
