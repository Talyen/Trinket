import TrinketContent

struct ShopStockSnapshot: Codable {
    let encounter: EncounterIdentity
    let offers: [StoredOffer]
    let purchasedOfferIDs: [String]

    init(stock: ShopStock, encounter: EncounterIdentity) {
        self.encounter = encounter
        offers = stock.offers.map(StoredOffer.init)
        purchasedOfferIDs = stock.purchasedOfferIDs.sorted()
    }

    func resolve() throws -> ShopStock {
        let resolved = offers.compactMap { $0.resolve() }
        let ids = Set(resolved.map(\.id))
        guard ids.count == resolved.count else { throw ShopPurchaseFailure.invalidOffer }
        let validPurchased = Set(purchasedOfferIDs).intersection(ids)
        return ShopStock(offers: resolved, purchasedOfferIDs: validPurchased)
    }

    struct StoredOffer: Codable {
        let id: String
        let item: StoredInventoryItem
        let price: Int

        init(_ offer: ShopOffer) {
            id = offer.id
            item = StoredInventoryItem(offer.item)
            price = offer.price
        }

        /// Retired item bases and invalid prices drop the offer while preserving surviving stock.
        func resolve() -> ShopOffer? {
            guard price >= 0, let item = item.resolved() else { return nil }
            return ShopOffer(id: id, item: item, price: price)
        }
    }
}
