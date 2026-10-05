import Foundation
import TrinketContent
import TrinketCore

/// Committed effects supplied by Persistence domain operations. App orchestration
/// forwards receipts through a transaction; it cannot construct their policy.
public struct SaveEconomicReceipt: Codable, Equatable, Sendable {
    enum Kind: Codable, Equatable, Sendable {
        case reward
        case shop(EncounterIdentity, ShopPurchase)
        case upgrade(HomesteadNodeID, Int)
        case collection(Collection)
    }

    struct ShopPurchase: Codable, Equatable, Sendable {
        let offerID: String
        let item: StoredInventoryItem
        let price: Int

        init(_ offer: ShopOffer) {
            offerID = offer.id
            item = StoredInventoryItem(offer.item)
            price = offer.price
        }
    }

    struct Collection: Codable, Equatable, Sendable {
        var positions: [HomesteadResource: UInt64]?
        let pending: [HomesteadResource: Double]
        let nodeTiers: [HomesteadNodeID: Int]
        let date: Date
        let gold: Int
    }

    var formatVersion = 1
    var kind: Kind
    let effects: CloudEconomicAction

    func validate() throws {
        guard formatVersion == 1 else { throw CloudSaveError.unsupportedSave }
        try effects.validate()
        switch kind {
        case .reward: break
        case let .shop(_, offer):
            guard offer.price >= 0, effects.gold == -offer.price else { throw CloudSaveError.unsupportedSave }
        case let .upgrade(_, tier):
            guard tier > 0, effects.gold <= 0, effects.materials.values.allSatisfy({ $0 <= 0 })
            else { throw CloudSaveError.unsupportedSave }
        case let .collection(collection):
            guard collection.date.timeIntervalSince1970.isFinite,
                  collection.pending.values.allSatisfy({ $0.isFinite && $0 >= 0 }),
                  let positions = collection.positions,
                  Set(positions.keys) == Set(collectionAmounts.keys),
                  effects.gold >= 0, effects.materials.values.allSatisfy({ $0 > 0 }),
                  effects.experience.isEmpty, effects.goldRemainder == 0, effects.gemsRemainder == 0
            else { throw CloudSaveError.unsupportedSave }
            for (resource, quantity) in collectionAmounts {
                guard let position = positions[resource], quantity > 0,
                      !position.addingReportingOverflow(UInt64(quantity)).overflow
                else { throw CloudSaveError.unsupportedSave }
            }
        }
    }

    var collectionAmounts: [HomesteadResource: Int] {
        var amounts = effects.materials
        if effects.gold > 0 {
            amounts[.gold] = effects.gold
        }
        return amounts
    }

    func positioningCollections(_ positions: inout [HomesteadResource: UInt64]) throws -> Self {
        guard case var .collection(collection) = kind else { return self }
        var starts: [HomesteadResource: UInt64] = [:]
        for (resource, quantity) in collectionAmounts {
            guard quantity > 0 else { throw CloudSaveError.unsupportedSave }
            let start = positions[resource, default: 0]
            let (end, overflow) = start.addingReportingOverflow(UInt64(quantity))
            guard !overflow else { throw CloudSaveError.unsupportedSave }
            starts[resource] = start
            positions[resource] = end
        }
        collection.positions = starts
        var positioned = self
        positioned.kind = .collection(collection)
        return positioned
    }

    func isDuplicate(in save: PlayerSave, since before: PlayerSave) -> Bool {
        switch kind {
        case .reward:
            if case let .salvage(id) = effects.claim {
                return before.inventory.item(matching: id) != nil && save.inventory.item(matching: id) == nil
            }
            return effects.claim?.isClaimed(in: save, since: before) == true
        case let .upgrade(id, tier): save.homestead.tier(for: id) >= tier
        case let .shop(encounter, offer):
            // Generations are device-local. Read the saved stock with the current
            // generation, while retaining the pinned location, seed, item and price.
            let current = EncounterIdentity(
                location: encounter.location,
                worldSeed: encounter.worldSeed,
                generation: save.sessionGeneration,
            )
            do {
                guard let stock = try ShopStockPersistence.stock(encounter: current, save: save) else { return false }
                return stock.purchasedOfferIDs.contains(offer.offerID) && stock.offers.contains {
                    $0.id == offer.offerID && $0.price == offer.price && StoredInventoryItem($0.item) == offer.item
                }
            } catch {
                return false
            }
        case .collection: false
        }
    }

    func sharesClaim(with other: Self) -> Bool {
        switch (kind, other.kind) {
        case (.reward, .reward): effects.claim != nil && effects.claim == other.effects.claim
        case let (.shop(first, offer), .shop(second, peer)):
            first.location == second.location && first.worldSeed == second.worldSeed && offer == peer
        case let (.upgrade(first, tier), .upgrade(second, peer)): first == second && tier == peer
        default: false
        }
    }
}

extension CloudEconomicAction {
    static func committed(
        claim: Claim? = nil, gold: Int = 0, materials: [HomesteadResource: Int] = [:],
        experience: [String: Int] = [:], goldRemainder: Int = 0, gemsRemainder: Int = 0,
    ) -> Self {
        Self(
            claim: claim,
            gold: gold,
            materials: materials,
            experience: experience,
            goldRemainder: goldRemainder,
            gemsRemainder: gemsRemainder,
        )
    }

    /// Apply recorded effects, without rereading authored prices or award rules.
    func applyEffects(to save: inout PlayerSave) {
        let starting = save.homestead.rewardRemainders ?? .zero
        func carry(_ value: Int, delta: Int) -> (remainder: Int, correction: Int) {
            let total = value + delta
            return ((total % 100 + 100) % 100, total < 0 ? -1 : total / 100)
        }
        let goldCarry = carry(starting.gold, delta: goldRemainder)
        let gemsCarry = carry(starting.gems, delta: gemsRemainder)
        save.roster.gold = min(PlayerRosterState.maxGoldBalance, max(0, SaturatedArithmetic.saturatingAdd(
            SaturatedArithmetic.saturatingAdd(save.roster.gold, gold), goldCarry.correction,
        )))
        for (resource, delta) in materials {
            save.homestead.resources[resource] = max(0, SaturatedArithmetic.saturatingAdd(
                save.homestead.resources[resource, default: 0], delta,
            ))
        }
        if gemsCarry.correction != 0 {
            save.homestead.resources[.gems] = max(0, SaturatedArithmetic.saturatingAdd(
                save.homestead.resources[.gems, default: 0], gemsCarry.correction,
            ))
        }
        let remainders = HomesteadRewardRemainders(gold: goldCarry.remainder, gems: gemsCarry.remainder)
        save.homestead.rewardRemainders = remainders == .zero ? nil : remainders
        for (id, delta) in experience {
            save.roster.progressions[id] = (save.roster.progressions[id] ?? .initial).addingExperience(delta)
        }
    }
}
