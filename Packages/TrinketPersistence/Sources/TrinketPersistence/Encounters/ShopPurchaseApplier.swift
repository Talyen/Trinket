import TrinketContent
import TrinketCore

public enum ShopPurchaseFailure: Error, Equatable, Sendable {
    case insufficientGold
    case soldOut
    case alreadyOwned
    case invalidOffer
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
            _ = try purchasableOffer(offerID: offerID, stock: stock, save: save)
            return .available
        } catch let failure as ShopPurchaseFailure {
            return .unavailable(failure)
        } catch {
            return .unavailable(.invalidOffer)
        }
    }

    static func purchase(
        offerID: String,
        encounter: EncounterIdentity,
        save: inout PlayerSave,
        recordReceipt: (SaveEconomicReceipt) -> Void,
    ) -> Result<InventoryItem, ShopPurchaseFailure> {
        guard encounter.isPlayable(in: save) else { return .failure(.invalidOffer) }
        do {
            guard var stock = try ShopStockPersistence.stock(encounter: encounter, save: save) else { return .failure(.invalidOffer) }
            let offer = try purchasableOffer(offerID: offerID, stock: stock, save: save)
            stock.purchasedOfferIDs.insert(offerID)
            let payload = try ShopStockPersistence.encode(stock, encounter: encounter)
            // Publish money, item and sold stock together only after admission succeeds.
            var candidate = save
            let gold = candidate.applyGoldDelta(-offer.price)
            candidate.inventory.appendUniqueItem(offer.item)
            guard candidate.inventory.item(matching: offer.item.id) != nil else { return .failure(.alreadyOwned) }
            ShopStockPersistence.setPayload(payload, encounter: encounter, save: &candidate)
            save = candidate
            recordReceipt(SaveEconomicReceipt(kind: .shop(encounter, .init(offer)), effects: .committed(gold: gold)))
            return .success(offer.item)
        } catch let failure as ShopPurchaseFailure {
            return .failure(failure)
        } catch {
            return .failure(.invalidOffer)
        }
    }

    private static func purchasableOffer(offerID: String, stock: ShopStock, save: PlayerSave) throws -> ShopOffer {
        guard let offer = stock.offers.first(where: { $0.id == offerID }), offer.price >= 0 else { throw ShopPurchaseFailure.invalidOffer }
        guard !stock.purchasedOfferIDs.contains(offerID) else { throw ShopPurchaseFailure.soldOut }
        guard !InventoryDuplicatePolicy.containsDuplicate(of: offer.item, in: save.inventory.items)
        else { throw ShopPurchaseFailure.alreadyOwned }
        guard save.roster.gold >= offer.price else { throw ShopPurchaseFailure.insufficientGold }
        return offer
    }
}
