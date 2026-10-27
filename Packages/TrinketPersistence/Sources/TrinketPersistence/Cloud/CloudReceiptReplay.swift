import TrinketContent
import TrinketCore

/// Explicit receipt replay state travels with one remote head. Snapshot merging
/// retains navigation/selection policy; this owner reconciles committed economics.
struct CloudReceiptReplay {
    var productionClaims: CloudProductionClaims
    var retiredItems: Set<String>

    init(head: CloudSaveHead) {
        productionClaims = head.productionClaims ?? CloudProductionClaims()
        retiredItems = head.retiredItemIDs ?? []
    }

    mutating func includeAccepted(_ mutations: CloudSaveJournal) throws {
        for mutation in mutations {
            var receipts = mutation.receipts ?? []
            var previous = mutation.before
            for record in mutation.actions ?? [] {
                try Task.checkCancellation()
                // resolve() validates operations before first attachment.
                let action = try record.resolved(following: previous, finalSnapshot: mutation.after)
                receipts.append(action.receipt)
                previous = action.after
            }
            for receipt in receipts {
                if case let .collection(collection) = receipt.kind {
                    for (resource, amount) in receipt.collectionAmounts {
                        if let start = collection.positions?[resource] {
                            _ = productionClaims.claim(resource, start: start, quantity: amount)
                        }
                    }
                }
                if case let .salvage(id) = receipt.effects.claim {
                    retiredItems.insert(id)
                }
            }
        }
    }

    func install(into head: inout CloudSaveHead) {
        // Older writers must reject the head instead of dropping its identities.
        head.formatVersion = max(2, head.formatVersion)
        head.productionClaims = productionClaims
        head.retiredItemIDs = retiredItems.isEmpty ? nil : retiredItems
    }

    /// Resolve duplicate ownership before merging either structural or economic
    /// fields. Legacy receipt replay remains isolated below for historical rows.
    mutating func apply(
        _ action: ResolvedSaveAction, collectionPositions: [HomesteadResource: UInt64], onto existing: PlayerSave,
    ) throws -> PlayerSave {
        let before = try action.before.restored()
        let after = try action.after.restored()
        let receipt = action.receipt
        let retiredID: String? = if case let .salvage(id) = receipt.effects.claim {
            id
        } else {
            nil
        }
        if receipt.isDuplicate(in: existing, since: before, retiredItemIDs: retiredItems)
            || retiredID.map({ retiredItems.contains($0) }) == true {
            var retained = existing
            retireItems(in: &retained)
            return retained
        }
        var merged = try CloudSaveMerge.mergeChanges(from: action.before, to: action.after, into: existing)
        reconcileVoyageEarnings(action, before: before, after: after, existing: existing, merged: &merged)
        var production = existing.homestead
        production.settleProduction(at: merged.homestead.lastProductionAt, gold: existing.roster.gold)
        merged.homestead.pendingProduction = production.pendingProduction
        if case .collection = receipt.kind {
            try productionClaims.replay(receipt, onto: &merged)
        } else {
            receipt.effects.applyEffects(to: &merged)
        }
        if let retiredID {
            retiredItems.insert(retiredID)
        }
        reconcileProduction([receipt], positions: collectionPositions, after: after, merged: &merged)
        retireItems(in: &merged)
        return merged
    }

    private func reconcileVoyageEarnings(
        _ action: ResolvedSaveAction, before: PlayerSave, after: PlayerSave,
        existing: PlayerSave, merged: inout PlayerSave,
    ) {
        guard case let .voyage(runID, _) = action.claim,
              let first = before.voyage.activeRun, first.id == runID,
              let last = after.voyage.activeRun, last.id == runID,
              let retained = existing.voyage.activeRun, retained.id == runID,
              merged.voyage.activeRun?.id == runID else { return }
        // Snapshot maxima can carry an earlier rejected node's alternate payout.
        // Only this admitted action's recorded earnings enter the terminal bonus.
        merged.voyage.activeRun?.earnedGold = SaturatedArithmetic.saturatingAdd(
            retained.earnedGold, max(0, SaturatedArithmetic.saturatingSub(last.earnedGold, first.earnedGold)),
        )
        var materials = retained.earnedMaterials
        for resource in Set(first.earnedMaterials.keys).union(last.earnedMaterials.keys) {
            let delta = max(0, SaturatedArithmetic.saturatingSub(
                last.earnedMaterials[resource, default: 0], first.earnedMaterials[resource, default: 0],
            ))
            materials[resource] = SaturatedArithmetic.saturatingAdd(materials[resource, default: 0], delta)
        }
        merged.voyage.activeRun?.earnedMaterials = materials
    }

    mutating func apply(
        _ receipts: [SaveEconomicReceipt], mutation: CloudSaveMutation,
        before: PlayerSave, after: PlayerSave, existing: PlayerSave, merged: inout PlayerSave,
    ) throws {
        merged.roster.gold = existing.roster.gold
        merged.homestead.resources = existing.homestead.resources
        merged.homestead.rewardRemainders = existing.homestead.rewardRemainders
        for id in Set(receipts.lazy.flatMap(\.effects.experience.keys)) {
            merged.roster.progressions[id] = existing.roster.progressions[id] ?? .initial
        }
        var existingProduction = existing.homestead
        existingProduction.settleProduction(at: merged.homestead.lastProductionAt, gold: existing.roster.gold)
        merged.homestead.pendingProduction = existingProduction.pendingProduction
        try applyEffects(receipts, before: before, existing: existing, merged: &merged)
        reconcileProduction(receipts, positions: mutation.collectionPositions ?? [:], after: after, merged: &merged)
    }

    private mutating func applyEffects(
        _ receipts: [SaveEconomicReceipt], before: PlayerSave,
        existing: PlayerSave, merged: inout PlayerSave,
    ) throws {
        var applied: [SaveEconomicReceipt] = []
        for receipt in receipts {
            let retiredID: String? = if case let .salvage(id) = receipt.effects.claim {
                id
            } else {
                nil
            }
            let duplicateRetirement = retiredID.map { retiredItems.contains($0) } ?? false
            if case .collection = receipt.kind {
                try productionClaims.replay(receipt, onto: &merged)
            } else if !receipt.isDuplicate(in: existing, since: before, retiredItemIDs: retiredItems),
                      !duplicateRetirement,
                      !applied.contains(where: { $0.sharesClaim(with: receipt) }) {
                receipt.effects.applyEffects(to: &merged)
                applied.append(receipt)
            }
            if let retiredID {
                retiredItems.insert(retiredID)
            }
        }
    }

    private func reconcileProduction(
        _ receipts: [SaveEconomicReceipt], positions: [HomesteadResource: UInt64],
        after: PlayerSave, merged: inout PlayerSave,
    ) {
        var localPositions = positions
        for receipt in receipts {
            if case let .collection(collection) = receipt.kind {
                for (resource, start) in collection.positions ?? [:] {
                    localPositions[resource] = max(
                        localPositions[resource, default: 0],
                        start + UInt64(receipt.collectionAmounts[resource, default: 0]),
                    )
                }
            }
        }
        var localProduction = after.homestead
        localProduction.settleProduction(at: merged.homestead.lastProductionAt, gold: after.roster.gold)
        for (resource, credit) in localProduction.pendingProduction {
            let consumed = productionClaims.covered(resource, after: localPositions[resource, default: 0])
            let retained = PlayerHomesteadState.remainingProductionCredit(credit, afterCollecting: consumed)
            if retained > merged.homestead.pendingProduction[resource, default: 0] {
                merged.homestead.pendingProduction[resource] = retained
            }
        }
    }

    func retireItems(in save: inout PlayerSave) {
        guard !retiredItems.isEmpty,
              save.inventory.items.contains(where: { retiredItems.contains($0.id) }) else { return }
        for item in save.inventory.items where retiredItems.contains(item.id) {
            save.roster.unequip(itemID: item.id)
        }
        save.inventory.items.removeAll { retiredItems.contains($0.id) }
    }
}
