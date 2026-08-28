import Foundation
import TrinketCore

public struct ShopOffer: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let item: InventoryItem
    public let price: Int

    public init(id: String, item: InventoryItem, price: Int) {
        self.id = id
        self.item = item
        self.price = price
    }
}

public enum ShopOfferGenerator {
    public static let offerCount = 4
    public static let basePriceRange = 20 ... 40
    public static let astralPriceMultiplier = 2
    public static let starterShopStageID = "chapter-1-stage-9"
    public static let starterShopPriceDiscountPercent = 50

    public static func generateOffers(
        stageID: String,
        count: Int = offerCount,
        baseTypes: [ItemBaseType] = GameContent.itemBaseTypes,
        itemGenerator: ItemGenerator = ItemGenerator(),
        ownedTrinketIDs: Set<String> = [],
        astralChanceBonusPercent: Int = 0,
        allAstral: Bool = false,
        priceDiscountPercent: Int = 0,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> [ShopOffer] {
        guard count > 0, !baseTypes.isEmpty else { return [] }

        let isStarterShop = stageID == starterShopStageID

        var reservedTrinketIDs = Set<String>()
        var offers: [ShopOffer] = []
        for index in 0 ..< count {
            let tier: ItemDropTier = if isStarterShop {
                .basic
            } else if allAstral {
                .astral
            } else {
                MysteryItemRarity.roll(
                    astralChanceBonusPercent: astralChanceBonusPercent,
                    using: &randomNumberGenerator
                )
            }
            let priceRarity: Rarity = tier == .basic ? .basic : .astral
            let basePrice = Int.random(in: basePriceRange, using: &randomNumberGenerator)
            var price = priceRarity == .astral ? basePrice * astralPriceMultiplier : basePrice
            if isStarterShop {
                price = max(1, (price * starterShopPriceDiscountPercent) / 100)
            } else if priceDiscountPercent > 0 {
                price = max(1, (price * (100 - min(priceDiscountPercent, 100))) / 100)
            }
            let offerID = "\(stageID)-offer-\(index)"
            let item = ItemRewardGenerator.generate(
                id: offerID,
                tier: tier,
                ownedTrinketIDs: ownedTrinketIDs,
                ownedUniqueIDs: [],
                reservedTrinketIDs: reservedTrinketIDs,
                baseTypes: baseTypes,
                itemGenerator: itemGenerator,
                using: &randomNumberGenerator
            )
            if item.isTrinket {
                reservedTrinketIDs.insert(item.templateID)
            }
            offers.append(ShopOffer(id: offerID, item: item, price: price))
        }
        return offers
    }

    public static func seed(worldSeed: UInt64, forStageID stageID: String) -> UInt64 {
        GameContent.encounterSeed(worldSeed, salt: "shop-\(stageID)")
    }
}
