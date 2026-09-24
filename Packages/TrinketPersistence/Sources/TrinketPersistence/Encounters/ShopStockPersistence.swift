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
            if case let .voyage(runID, nodeID) = encounter.location {
                guard save.voyage.node(runID: runID, nodeID: nodeID)?.type == .shop else { return .failure(.invalidOffer) }
            }
            guard let rewardLevel = encounter.rewardLevel(in: save) else { return .failure(.invalidOffer) }
            let effects = encounter.modifierEffects(in: save)
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
        case let .voyage(runID, nodeID): save.voyage.node(runID: runID, nodeID: nodeID)?.shopPayload
        }
        guard let data else { return nil }
        let snapshot = try JSONDecoder().decode(ShopStockSnapshot.self, from: data)
        guard snapshot.encounter.location == encounter.location,
              snapshot.encounter.worldSeed == encounter.worldSeed
        else { throw ShopPurchaseFailure.invalidOffer }
        return try snapshot.resolve()
    }

    static func encode(_ stock: ShopStock, encounter: EncounterIdentity) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(ShopStockSnapshot(stock: stock, encounter: encounter))
    }

    static func mergedPayload(preferred: Data?, other: Data?) -> Data? {
        guard let preferred, let other else { return preferred ?? other }
        guard let first = validSnapshot(preferred) else { return validSnapshot(other) == nil ? preferred : other }
        guard let second = validSnapshot(other) else { return preferred }
        do {
            guard first.snapshot.encounter.location == second.snapshot.encounter.location,
                  first.snapshot.encounter.worldSeed == second.snapshot.encounter.worldSeed
            else { return preferred }
            var stock = first.stock
            let otherOffers = Dictionary(uniqueKeysWithValues: second.stock.offers.map { ($0.id, $0) })
            for offer in stock.offers where second.stock.purchasedOfferIDs.contains(offer.id)
                && otherOffers[offer.id] == offer {
                stock.purchasedOfferIDs.insert(offer.id)
            }
            return try encode(stock, encounter: first.snapshot.encounter)
        } catch {
            return preferred
        }
    }

    private static func validSnapshot(_ data: Data) -> (snapshot: ShopStockSnapshot, stock: ShopStock)? {
        do {
            let snapshot = try JSONDecoder().decode(ShopStockSnapshot.self, from: data)
            let stock = try snapshot.resolve()
            return stock.offers.isEmpty ? nil : (snapshot, stock)
        } catch {
            return nil
        }
    }

    static func purchasedOfferIDs(in payload: Data?) -> Set<String> {
        guard let payload else { return [] }
        do {
            return try JSONDecoder().decode(ShopStockSnapshot.self, from: payload).resolve().purchasedOfferIDs
        } catch {
            return []
        }
    }

    static func setPayload(_ data: Data, encounter: EncounterIdentity, save: inout PlayerSave) {
        switch encounter.location {
        case let .journey(stageID): save.journey.shopPayloads[stageID] = data
        case let .labyrinth(nodeID): save.labyrinth.nodes[nodeID]?.shopPayload = data
        case let .voyage(runID, nodeID): save.voyage.updateNode(runID: runID, nodeID: nodeID) { $0.shopPayload = data }
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

        /// Nil when the offer's item is homeless (unknown base): the option
        /// is dropped while surviving offers resolve. Non-negative pricing
        /// is still enforced so a tampered payload cannot mint rewards.
        func resolve() -> ShopOffer? {
            guard price >= 0, let item = item.resolved() else { return nil }
            return ShopOffer(id: id, item: item, price: price)
        }
    }
}
