import Foundation
import TrinketContent
import TrinketCore

public struct ShopStock: Equatable, Sendable {
    public let offers: [ShopOffer]
    public internal(set) var purchasedOfferIDs: Set<String> = []
}

public enum ShopStockPersistence {
    public static func prepare(
        encounter: EncounterIdentity,
        save: inout PlayerSave,
    ) -> Result<ShopStock, ShopPurchaseFailure> {
        guard encounter.isPlayable(in: save) else { return .failure(.invalidOffer) }
        do {
            if let stock = try stock(encounter: encounter, save: save) {
                return .success(stock)
            }
            if case let .journey(stageID) = encounter.location {
                guard let stage = GameContent.stage(id: stageID), case .shop = stage.encounter else { return .failure(.invalidOffer) }
            } else if let nodeID = encounter.labyrinthNodeID {
                guard save.labyrinth.nodes[nodeID]?.type == .shop else { return .failure(.invalidOffer) }
            }
            guard let rewardLevel = encounter.rewardLevel(in: save) else { return .failure(.invalidOffer) }
            let effects = encounter.labyrinthNodeID.map { save.labyrinth.effects(for: $0) } ?? .zero
            var rng = SeededRandomNumberGenerator(seed: ShopOfferGenerator.seed(
                worldSeed: encounter.worldSeed,
                forStageID: encounter.stageID,
            ))
            let stock = ShopStock(offers: ShopOfferGenerator.generateOffers(
                stageID: encounter.stageID, rewardLevel: rewardLevel, ownedTrinketIDs: save.inventory.ownedTrinketIDs,
                astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
                allAstral: effects.astralShopOffers, priceDiscountPercent: effects.shopDiscountPercent, using: &rng,
            ))
            let payload = try encode(stock, encounter: encounter)
            setPayload(payload, encounter: encounter, save: &save)
            return .success(stock)
        } catch {
            return .failure(.invalidOffer)
        }
    }

    public static func stock(encounter: EncounterIdentity, save: PlayerSave) throws -> ShopStock? {
        guard encounter.isCurrent(in: save) else { throw ShopPurchaseFailure.invalidOffer }
        let data: Data? = switch encounter.location {
        case let .journey(stageID): save.journey.shopPayloads[stageID]
        case let .labyrinth(nodeID): save.labyrinth.nodes[nodeID]?.shopPayload
        }
        guard let data else { return nil }
        let snapshot = try JSONDecoder().decode(ShopStockSnapshot.self, from: data)
        guard snapshot.encounter == encounter else { throw ShopPurchaseFailure.invalidOffer }
        return try snapshot.resolve()
    }

    static func encode(_ stock: ShopStock, encounter: EncounterIdentity) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(ShopStockSnapshot(stock: stock, encounter: encounter))
    }

    static func setPayload(_ data: Data, encounter: EncounterIdentity, save: inout PlayerSave) {
        switch encounter.location {
        case let .journey(stageID): save.journey.shopPayloads[stageID] = data
        case let .labyrinth(nodeID): save.labyrinth.nodes[nodeID]?.shopPayload = data
        }
    }
}

private struct ShopStockSnapshot: Codable {
    let encounter: EncounterIdentity
    let offers: [StoredOffer]
    let purchasedOfferIDs: [String]

    init(stock: ShopStock, encounter: EncounterIdentity) {
        self.encounter = encounter
        offers = stock.offers.map(StoredOffer.init)
        purchasedOfferIDs = stock.purchasedOfferIDs.sorted()
    }

    func resolve() throws -> ShopStock {
        let resolved = try offers.map { try $0.resolve() }
        let ids = Set(resolved.map(\.id))
        guard ids.count == resolved.count, Set(purchasedOfferIDs).isSubset(of: ids) else { throw ShopPurchaseFailure.invalidOffer }
        return ShopStock(offers: resolved, purchasedOfferIDs: Set(purchasedOfferIDs))
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

        func resolve() throws -> ShopOffer {
            guard price >= 0 else { throw ShopPurchaseFailure.invalidOffer }
            return try ShopOffer(id: id, item: item.resolve(), price: price)
        }
    }
}
