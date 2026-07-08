import Foundation
import TrinketContent
import TrinketCore

public enum ShopPurchaseResult: Equatable, Sendable {
    case success(InventoryItem)
    case insufficientGold
}

/// Atomic gold spend + inventory grant for Merchant's Shop purchases.
public enum ShopPurchaseApplier {
    /// Purchases `offer` into `save`, minting a unique inventory instance id from
    /// `stageID`, offer id, and `purchaseOrdinal` so the same shelf listing can be
    /// bought more than once in a visit.
    public static func purchase(
        offer: ShopOffer,
        purchaseOrdinal: Int,
        stageID: String,
        save: inout PlayerSave
    ) -> ShopPurchaseResult {
        guard save.roster.spendGold(offer.price) else {
            return .insufficientGold
        }

        let purchased = InventoryItem(
            id: "\(stageID)-shop-\(offer.id)-\(purchaseOrdinal)",
            templateID: offer.item.templateID,
            baseType: offer.item.baseType,
            rarity: offer.item.rarity,
            displayName: offer.item.displayName,
            affixes: offer.item.affixes
        )
        save.inventory.items.append(purchased)
        return .success(purchased)
    }
}
