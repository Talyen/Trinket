import Foundation
import TrinketContent

extension CloudSaveMerge {
    static func hasNewCorruptionAltarCompletion(in save: PlayerSave, base: PlayerSave?) -> Bool {
        guard let base else { return false }
        func isAltar(_ eventID: String?) -> Bool {
            guard let eventID else { return false }
            return eventID == GameContent.corruptionAltarEventID
                || GameContent.mysteryEvent(matching: eventID)?.choices.contains { $0.effects.contains(.corruptItem) } == true
        }
        if save.journey.claimedRewardStageIDs.contains(where: {
            !base.journey.claimedRewardStageIDs.contains($0) && isAltar(save.journey.pinnedMysteryEventIDs[$0])
        }) {
            return true
        }
        if save.labyrinth.worldSeed == (base.labyrinth.hasMap ? base.labyrinth.worldSeed : base.worldSeed),
           save.labyrinth.nodes.values.contains(where: {
               $0.isCleared && base.labyrinth.nodes[$0.id]?.isCleared != true && isAltar($0.mysteryEventID)
           }) {
            return true
        }
        let runs = [save.voyage.activeRun, base.voyage.activeRun].lazy.compactMap(\.self)
        return runs.contains { run in
            run.nodes.contains { node in
                base.voyage.node(runID: run.id, nodeID: node.id)?.isCleared != true
                    && (save.voyage.node(runID: run.id, nodeID: node.id)?.isCleared == true
                        || save.voyage.completedRunIDs?.contains(run.id) == true)
                    && isAltar(node.mysteryEventID)
            }
        }
    }

    static func sharedMysteryCompletionCount(branches: Branches) -> Int {
        guard let base = branches.base else { return 0 }
        let first = branches.incoming
        let second = branches.existing
        var count = first.journey.claimedRewardStageIDs.count { id in
            guard !base.journey.claimedRewardStageIDs.contains(id),
                  second.journey.claimedRewardStageIDs.contains(id),
                  let stage = GameContent.stage(id: id) else { return false }
            switch stage.encounter {
            case .mysteryEvent, .recruit: return true
            default: return false
            }
        }
        if sharesLabyrinthMap(incoming: first, existing: second, base: base) {
            count += first.labyrinth.nodes.values.count { node in
                (node.type == .mystery || node.type == .recruit) && node.isCleared
                    && base.labyrinth.nodes[node.id]?.isCleared != true
                    && second.labyrinth.nodes[node.id]?.isCleared == true
            }
        }
        var seen: Set<String> = []
        for run in [first.voyage.activeRun, second.voyage.activeRun, base.voyage.activeRun].lazy.compactMap(\.self)
            where seen.insert(run.id).inserted {
            count += run.nodes.count { node in
                (node.type == .mystery || node.type == .recruit)
                    && base.voyage.node(runID: run.id, nodeID: node.id)?.isCleared != true
                    && (first.voyage.node(runID: run.id, nodeID: node.id)?.isCleared == true
                        || first.voyage.completedRunIDs?.contains(run.id) == true)
                    && (second.voyage.node(runID: run.id, nodeID: node.id)?.isCleared == true
                        || second.voyage.completedRunIDs?.contains(run.id) == true)
            }
        }
        return count
    }

    static func hasDuplicateClaim(incoming: PlayerSave, existing: PlayerSave, base: PlayerSave?) -> Bool {
        guard let base else { return true }
        if hasSharedContractClaim(incoming: incoming, existing: existing, base: base)
            || hasSharedSpireClaim(incoming: incoming, existing: existing, base: base) {
            return true
        }
        let baseItemIDs = Set(base.inventory.items.lazy.map(\.id))
        let incomingItemIDs = Set(incoming.inventory.items.lazy.map(\.id))
        let existingItemIDs = Set(existing.inventory.items.lazy.map(\.id))
        let incomingNewItemIDs = incomingItemIDs.subtracting(baseItemIDs)
        let existingNewItemIDs = existingItemIDs.subtracting(baseItemIDs)
        if hasSharedJourneyClaim(
            incoming: incoming, existing: existing, base: base,
            incomingNewItemIDs: incomingNewItemIDs, existingNewItemIDs: existingNewItemIDs,
        ) {
            return true
        }
        let distinctNewItems = !incomingNewItemIDs.isEmpty && !existingNewItemIDs.isEmpty
            && incomingNewItemIDs.isDisjoint(with: existingNewItemIDs)
        // Different noncombat choices can grant separate items. Combat claims
        // still overlap even when the two devices rolled different loot.
        if hasSharedNodeClaim(incoming: incoming, existing: existing, base: base, onlyCombat: distinctNewItems) {
            return true
        }
        if hasSharedShopPurchase(incoming: incoming, existing: existing, base: base) {
            return true
        }
        if base.inventory.items.contains(where: { item in
            ItemSalvage.isEligible(item)
                && !incomingItemIDs.contains(item.id)
                && !existingItemIDs.contains(item.id)
        }) {
            return true
        }
        return false
    }

    private static func hasSharedJourneyClaim(
        incoming: PlayerSave, existing: PlayerSave, base: PlayerSave,
        incomingNewItemIDs: Set<String>, existingNewItemIDs: Set<String>,
    ) -> Bool {
        incoming.journey.claimedRewardStageIDs.contains { stageID in
            guard !base.journey.claimedRewardStageIDs.contains(stageID),
                  existing.journey.claimedRewardStageIDs.contains(stageID) else { return false }
            let prefix = "\(stageID)-"
            var hasIncoming = false
            for id in incomingNewItemIDs where id.hasPrefix(prefix) {
                hasIncoming = true
                if existingNewItemIDs.contains(id) {
                    return true
                }
            }
            return !hasIncoming || !existingNewItemIDs.contains { $0.hasPrefix(prefix) }
        }
    }

    private static func hasSharedContractClaim(incoming: PlayerSave, existing: PlayerSave, base: PlayerSave) -> Bool {
        if let starting = base.contracts.completedOfferIDs,
           let first = incoming.contracts.completedOfferIDs, let second = existing.contracts.completedOfferIDs {
            return first.contains { !starting.contains($0) && second.contains($0) }
        }
        // Older peers lack receipts; retain conservative overlap detection for them.
        return base.contracts.offers.contains { offer in
            !incoming.contracts.offers.contains { $0.id == offer.id }
                && !existing.contracts.offers.contains { $0.id == offer.id }
        }
    }

    private static func hasSharedSpireClaim(incoming: PlayerSave, existing: PlayerSave, base: PlayerSave) -> Bool {
        incoming.spires.highestClearedFloorBySpireID.keys.contains { spireID in
            guard existing.spires.highestClearedFloorBySpireID[spireID] != nil else { return false }
            let baseFloor = base.spires.highestClearedFloor(for: spireID)
            return incoming.spires.highestClearedFloor(for: spireID) > baseFloor
                && existing.spires.highestClearedFloor(for: spireID) > baseFloor
        }
    }

    static func hasSharedShopPurchase(incoming: PlayerSave, existing: PlayerSave, base: PlayerSave) -> Bool {
        if incoming.journey.shopPayloads.keys.contains(where: { id in
            existing.journey.shopPayloads[id] != nil && ShopStockPersistence.hasSharedNewPurchase(
                base: base.journey.shopPayloads[id],
                incoming: incoming.journey.shopPayloads[id],
                existing: existing.journey.shopPayloads[id],
            )
        }) {
            return true
        }
        if sharesLabyrinthMap(incoming: incoming, existing: existing, base: base) {
            if incoming.labyrinth.nodes.keys.contains(where: { id in
                existing.labyrinth.nodes[id] != nil && ShopStockPersistence.hasSharedNewPurchase(
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
                ShopStockPersistence.hasSharedNewPurchase(
                    base: node.shopPayload,
                    incoming: incoming.voyage.node(runID: run.id, nodeID: node.id)?.shopPayload,
                    existing: existing.voyage.node(runID: run.id, nodeID: node.id)?.shopPayload,
                )
            }
        }
        return false
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
        let incomingCompleted = (incoming.voyage.completedRunIDs ?? []).subtracting(base.voyage.completedRunIDs ?? [])
        let existingCompleted = (existing.voyage.completedRunIDs ?? []).subtracting(base.voyage.completedRunIDs ?? [])
        if !incomingCompleted.isDisjoint(with: existingCompleted) {
            return true
        }
        return [incoming.voyage.activeRun, existing.voyage.activeRun].lazy.compactMap(\.self).contains { run in
            guard base.voyage.activeRun?.id == run.id || base.voyage.offers.contains(where: { $0.id == run.id })
            else { return false }
            return run.nodes.contains { node in
                (!onlyCombat || node.type.isCombat)
                    && base.voyage.node(runID: run.id, nodeID: node.id)?.isCleared != true
                    && (incoming.voyage.node(runID: run.id, nodeID: node.id)?.isCleared == true
                        || incomingCompleted.contains(run.id))
                    && (existing.voyage.node(runID: run.id, nodeID: node.id)?.isCleared == true
                        || existingCompleted.contains(run.id))
            }
        }
    }

    private static func sharesLabyrinthMap(incoming: PlayerSave, existing: PlayerSave, base: PlayerSave) -> Bool {
        incoming.labyrinth.worldSeed == existing.labyrinth.worldSeed
            && (base.labyrinth.hasMap ? base.labyrinth.worldSeed : base.worldSeed) == incoming.labyrinth.worldSeed
    }
}
