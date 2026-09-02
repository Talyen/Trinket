import Foundation
import TrinketContent
import TrinketCore

public enum ShopPurchaseResult: Equatable, Sendable {
    case success(InventoryItem)
    case insufficientGold
    case alreadyOwned
    case invalidOffer

    public var failureMessage: String? {
        switch self {
        case .success:
            nil
        case .insufficientGold:
            "Not enough Gold."
        case .alreadyOwned:
            "That item is already sold."
        case .invalidOffer:
            "That offer is unavailable."
        }
    }
}

public enum ShopPurchaseApplier {
    public static func inventoryInstanceID(
        stageID: String,
        offerID: String,
        visitToken: String,
    ) -> String {
        "\(stageID)-shop-\(offerID)-\(visitToken)"
    }

    public static func purchase(
        offer: ShopOffer,
        visitToken: String,
        stageID: String,
        save: inout PlayerSave,
    ) -> ShopPurchaseResult {
        let instanceID = inventoryInstanceID(
            stageID: stageID,
            offerID: offer.id,
            visitToken: visitToken,
        )
        let isSingletonItem = offer.item.isTrinket || offer.item.rarity == .unique
        let itemID = isSingletonItem ? offer.item.id : instanceID
        guard offer.price >= 0 else {
            return .invalidOffer
        }
        let purchased = InventoryItem(
            id: itemID,
            templateID: offer.item.templateID,
            baseType: offer.item.baseType,
            rarity: offer.item.rarity,
            displayName: offer.item.displayName,
            affixes: offer.item.affixes,
            isCorrupted: offer.item.isCorrupted,
            affixPowers: offer.item.affixPowers,
        )
        guard !InventoryDuplicatePolicy.containsDuplicate(of: purchased, in: save.inventory.items) else {
            return .alreadyOwned
        }
        guard save.roster.spendGold(offer.price) else {
            return .insufficientGold
        }
        save.inventory.appendUniqueItem(purchased)
        return .success(purchased)
    }
}
