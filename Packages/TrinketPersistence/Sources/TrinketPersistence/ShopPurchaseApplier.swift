import Foundation
import TrinketContent
import TrinketCore

public enum ShopPurchaseResult: Equatable, Sendable {
    case success(InventoryItem)
    case insufficientGold
    case alreadyOwned

    public var failureMessage: String? {
        switch self {
        case .success:
            nil
        case .insufficientGold:
            "Not enough Gold."
        case .alreadyOwned:
            "That item is already sold."
        }
    }
}

/// Atomic gold spend + inventory grant for Merchant's Shop purchases.
public enum ShopPurchaseApplier {
    /// Stable inventory instance id for one purchase of `offerID` during `visitToken`.
    /// Visit-scoped so dismiss/re-open cannot collide with a prior grant and burn gold.
    public static func inventoryInstanceID(
        stageID: String,
        offerID: String,
        visitToken: String
    ) -> String {
        "\(stageID)-shop-\(offerID)-\(visitToken)"
    }

    /// Purchases `offer` into `save`, minting a unique inventory instance id from
    /// `stageID`, offer id, and `visitToken`. Each listing is stock-1 per visit.
    public static func purchase(
        offer: ShopOffer,
        visitToken: String,
        stageID: String,
        save: inout PlayerSave
    ) -> ShopPurchaseResult {
        let instanceID = inventoryInstanceID(
            stageID: stageID,
            offerID: offer.id,
            visitToken: visitToken
        )
        guard offer.price >= 0 else {
            return .insufficientGold
        }
        guard !save.inventory.items.contains(where: { $0.id == instanceID }) else {
            return .alreadyOwned
        }
        if offer.item.isTrinket,
           save.inventory.items.contains(where: { $0.isTrinket && $0.templateID == offer.item.templateID }) {
            return .alreadyOwned
        }
        guard save.roster.spendGold(offer.price) else {
            return .insufficientGold
        }

        let purchased = InventoryItem(
            id: offer.item.isTrinket ? offer.item.id : instanceID,
            templateID: offer.item.templateID,
            baseType: offer.item.baseType,
            rarity: offer.item.rarity,
            displayName: offer.item.displayName,
            affixes: offer.item.affixes,
            isCorrupted: offer.item.isCorrupted,
            affixPowers: offer.item.affixPowers
        )
        save.inventory.items.append(purchased)
        return .success(purchased)
    }
}
