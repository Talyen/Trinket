import Foundation
import TrinketCore

/// A single Merchant's Shop listing: a rolled item with a locked visit price.
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

/// Procedural shop shelf for journey shop encounters.
public enum ShopOfferGenerator {
    public static let offerCount = 4
    public static let basePriceRange = 20 ... 40
    public static let astralPriceMultiplier = 2

    public static func generateOffers(
        stageID: String,
        count: Int = offerCount,
        baseTypes: [ItemBaseType] = GameContent.itemBaseTypes,
        itemGenerator: ItemGenerator = ItemGenerator(),
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> [ShopOffer] {
        guard count > 0, !baseTypes.isEmpty else { return [] }

        return (0 ..< count).map { index in
            let baseType = baseTypes.randomElement(using: &randomNumberGenerator) ?? baseTypes[0]
            let rarity = MysteryItemRarity.roll(using: &randomNumberGenerator)
            let basePrice = Int.random(in: basePriceRange, using: &randomNumberGenerator)
            let price = rarity == .astral ? basePrice * astralPriceMultiplier : basePrice
            let offerID = "\(stageID)-offer-\(index)"
            let item = itemGenerator.generate(
                id: offerID,
                templateID: "\(baseType.id)-\(rarity.rawValue)",
                baseType: baseType,
                rarity: rarity,
                using: &randomNumberGenerator
            )
            return ShopOffer(id: offerID, item: item, price: price)
        }
    }

    /// Deterministic seed derived from the stage id so a visit shelf is stable for that stage.
    public static func seed(forStageID stageID: String) -> UInt64 {
        GameContent.stableSeed(for: "shop-\(stageID)")
    }
}
