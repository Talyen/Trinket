import TrinketContent
import TrinketCore

public enum ShopPurchaseFailure: Error, Equatable, Sendable {
    case insufficientGold
    case soldOut
    case alreadyOwned
    case invalidOffer

    public var message: String {
        switch self {
        case .insufficientGold: "Not enough Gold."
        case .soldOut: "That item is already sold."
        case .alreadyOwned: "You already own that item."
        case .invalidOffer: "That offer is unavailable."
        }
    }
}

public enum ShopOfferAvailability: Equatable, Sendable {
    case available
    case unavailable(ShopPurchaseFailure)

    public var canPurchase: Bool {
        self == .available
    }
}

public enum ShopPurchaseApplier {
    public static func availability(
        offerID: String,
        encounter: EncounterIdentity,
        save: PlayerSave,
    ) -> ShopOfferAvailability {
        guard encounter.isPlayable(in: save) else { return .unavailable(.invalidOffer) }
        do {
            guard let stock = try ShopStockPersistence.stock(encounter: encounter, save: save) else { return .unavailable(.invalidOffer) }
            return availability(offerID: offerID, stock: stock, save: save)
        } catch {
            return .unavailable(.invalidOffer)
        }
    }

    public static func purchase(
        offerID: String,
        encounter: EncounterIdentity,
        save: inout PlayerSave,
    ) -> Result<InventoryItem, ShopPurchaseFailure> {
        guard encounter.isPlayable(in: save) else { return .failure(.invalidOffer) }
        do {
            guard var stock = try ShopStockPersistence.stock(encounter: encounter, save: save) else { return .failure(.invalidOffer) }
            if case let .unavailable(reason) = availability(offerID: offerID, stock: stock, save: save) {
                return .failure(reason)
            }
            guard let offer = stock.offers.first(where: { $0.id == offerID }) else { return .failure(.invalidOffer) }
            stock.purchasedOfferIDs.insert(offerID)
            let payload = try ShopStockPersistence.encode(stock, encounter: encounter)
            save.applyGoldDelta(-offer.price)
            save.inventory.appendUniqueItem(offer.item)
            ShopStockPersistence.setPayload(payload, encounter: encounter, save: &save)
            return .success(offer.item)
        } catch {
            return .failure(.invalidOffer)
        }
    }

    private static func availability(offerID: String, stock: ShopStock, save: PlayerSave) -> ShopOfferAvailability {
        guard let offer = stock.offers.first(where: { $0.id == offerID }), offer.price >= 0 else { return .unavailable(.invalidOffer) }
        guard !stock.purchasedOfferIDs.contains(offerID) else { return .unavailable(.soldOut) }
        guard !InventoryDuplicatePolicy.containsDuplicate(of: offer.item, in: save.inventory.items)
        else { return .unavailable(.alreadyOwned) }
        return save.roster.gold >= offer.price ? .available : .unavailable(.insufficientGold)
    }
}
