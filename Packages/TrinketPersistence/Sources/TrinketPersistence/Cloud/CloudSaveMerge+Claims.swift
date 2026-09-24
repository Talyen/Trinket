import Foundation

extension CloudSaveMerge {
    static func hasDuplicateClaim(incoming: PlayerSave, existing: PlayerSave, base: PlayerSave?) -> Bool {
        guard let base else { return true }
        let common = incoming.journey.claimedRewardStageIDs.subtracting(base.journey.claimedRewardStageIDs)
            .intersection(existing.journey.claimedRewardStageIDs.subtracting(base.journey.claimedRewardStageIDs))
        let existingItemIDs = Set(base.inventory.items.map(\.id))
        for stageID in common {
            let prefix = "\(stageID)-"
            let first = Set(incoming.inventory.items.map(\.id).filter { $0.hasPrefix(prefix) && !existingItemIDs.contains($0) })
            let second = Set(existing.inventory.items.map(\.id).filter { $0.hasPrefix(prefix) && !existingItemIDs.contains($0) })
            if first.isEmpty || second.isEmpty || !first.isDisjoint(with: second) {
                return true
            }
        }
        for offer in base.contracts.offers {
            if !incoming.contracts.offers.contains(where: { $0.id == offer.id }),
               !existing.contracts.offers.contains(where: { $0.id == offer.id }) {
                return true
            }
        }
        let sharedSpireIDs = Set(incoming.spires.highestClearedFloorBySpireID.keys)
            .intersection(existing.spires.highestClearedFloorBySpireID.keys)
        for spireID in sharedSpireIDs {
            let baseFloor = base.spires.highestClearedFloor(for: spireID)
            if incoming.spires.highestClearedFloor(for: spireID) > baseFloor,
               existing.spires.highestClearedFloor(for: spireID) > baseFloor {
                return true
            }
        }
        if hasSharedNodeClaim(incoming: incoming, existing: existing, base: base, onlyCombat: true) {
            return true
        }
        if hasSharedNodeClaim(incoming: incoming, existing: existing, base: base, onlyCombat: false),
           !distinctNewItems(incoming: incoming, existing: existing, priorIDs: existingItemIDs) {
            return true
        }
        if hasSharedShopPurchase(incoming: incoming, existing: existing, base: base) {
            return true
        }
        if base.inventory.items.contains(where: { item in
            ItemSalvage.isEligible(item)
                && incoming.inventory.item(matching: item.id) == nil
                && existing.inventory.item(matching: item.id) == nil
        }) {
            return true
        }
        return false
    }

    private static func hasSharedShopPurchase(incoming: PlayerSave, existing: PlayerSave, base: PlayerSave) -> Bool {
        let stages = Set(incoming.journey.shopPayloads.keys).intersection(existing.journey.shopPayloads.keys)
        if stages.contains(where: { id in
            hasSharedPurchase(
                base: base.journey.shopPayloads[id],
                incoming: incoming.journey.shopPayloads[id],
                existing: existing.journey.shopPayloads[id],
            )
        }) {
            return true
        }
        if sharesLabyrinthMap(incoming: incoming, existing: existing, base: base) {
            let nodes = Set(incoming.labyrinth.nodes.keys).intersection(existing.labyrinth.nodes.keys)
            if nodes.contains(where: { id in
                hasSharedPurchase(
                    base: base.labyrinth.nodes[id]?.shopPayload,
                    incoming: incoming.labyrinth.nodes[id]?.shopPayload,
                    existing: existing.labyrinth.nodes[id]?.shopPayload,
                )
            }) {
                return true
            }
        }
        if let run = base.voyage.activeRun,
           incoming.voyage.activeRun?.id == run.id,
           existing.voyage.activeRun?.id == run.id {
            return run.nodes.contains { node in
                hasSharedPurchase(
                    base: node.shopPayload,
                    incoming: incoming.voyage.node(runID: run.id, nodeID: node.id)?.shopPayload,
                    existing: existing.voyage.node(runID: run.id, nodeID: node.id)?.shopPayload,
                )
            }
        }
        return false
    }

    private static func hasSharedPurchase(base: Data?, incoming: Data?, existing: Data?) -> Bool {
        let prior = ShopStockPersistence.purchasedOfferIDs(in: base)
        let first = ShopStockPersistence.purchasedOfferIDs(in: incoming).subtracting(prior)
        let second = ShopStockPersistence.purchasedOfferIDs(in: existing).subtracting(prior)
        return !first.isDisjoint(with: second)
    }

    private static func hasSharedNodeClaim(
        incoming: PlayerSave, existing: PlayerSave, base: PlayerSave, onlyCombat: Bool,
    ) -> Bool {
        if sharesLabyrinthMap(incoming: incoming, existing: existing, base: base) {
            for (id, node) in incoming.labyrinth.nodes where node.isCleared && node.type != .entrance
                && (!onlyCombat || node.type.isCombat) {
                if base.labyrinth.nodes[id]?.isCleared != true,
                   existing.labyrinth.nodes[id]?.isCleared == true {
                    return true
                }
            }
        }
        guard let run = incoming.voyage.activeRun,
              let otherRun = existing.voyage.activeRun,
              otherRun.id == run.id,
              base.voyage.activeRun?.id == run.id || base.voyage.offers.contains(where: { $0.id == run.id })
        else { return false }
        return run.nodes.contains { node in
            node.isCleared && (!onlyCombat || node.type.isCombat)
                && base.voyage.node(runID: run.id, nodeID: node.id)?.isCleared != true
                && otherRun.node(id: node.id)?.isCleared == true
        }
    }

    private static func distinctNewItems(
        incoming: PlayerSave, existing: PlayerSave, priorIDs: Set<String>,
    ) -> Bool {
        let first = Set(incoming.inventory.items.map(\.id)).subtracting(priorIDs)
        let second = Set(existing.inventory.items.map(\.id)).subtracting(priorIDs)
        return !first.isEmpty && !second.isEmpty && first.isDisjoint(with: second)
    }

    private static func sharesLabyrinthMap(incoming: PlayerSave, existing: PlayerSave, base: PlayerSave) -> Bool {
        incoming.labyrinth.worldSeed == existing.labyrinth.worldSeed
            && (base.labyrinth.hasMap ? base.labyrinth.worldSeed : base.worldSeed) == incoming.labyrinth.worldSeed
    }
}
