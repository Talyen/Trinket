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

    mutating func includeAccepted(_ mutations: CloudSaveJournal) {
        for mutation in mutations {
            for receipt in mutation.receipts ?? [] {
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
        head.formatVersion = 2
        head.productionClaims = productionClaims
        head.retiredItemIDs = retiredItems.isEmpty ? nil : retiredItems
    }

    mutating func apply(
        _ receipts: [SaveEconomicReceipt], mutation: CloudSaveMutation,
        before: PlayerSave, after: PlayerSave, existing: PlayerSave, merged: inout PlayerSave,
    ) throws {
        merged.roster.gold = existing.roster.gold
        merged.homestead.resources = existing.homestead.resources
        merged.homestead.rewardRemainders = existing.homestead.rewardRemainders
        for id in Set(receipts.flatMap(\.effects.experience.keys)) {
            merged.roster.progressions[id] = existing.roster.progressions[id] ?? .initial
        }
        var existingProduction = existing.homestead
        existingProduction.settleProduction(at: merged.homestead.lastProductionAt, roster: existing.roster)
        merged.homestead.pendingProduction = existingProduction.pendingProduction
        try applyEffects(receipts, before: before, existing: existing, merged: &merged)
        reconcileProduction(receipts, mutation: mutation, after: after, merged: &merged)
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
            } else if !receipt.isDuplicate(in: existing, since: before),
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
        _ receipts: [SaveEconomicReceipt], mutation: CloudSaveMutation,
        after: PlayerSave, merged: inout PlayerSave,
    ) {
        var localPositions = mutation.collectionPositions ?? [:]
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
        localProduction.settleProduction(at: merged.homestead.lastProductionAt, roster: after.roster)
        for (resource, credit) in localProduction.pendingProduction {
            let consumed = productionClaims.covered(resource, after: localPositions[resource, default: 0])
            let retained = max(0, credit - Double(consumed))
            if retained > merged.homestead.pendingProduction[resource, default: 0] {
                merged.homestead.pendingProduction[resource] = retained
            }
        }
    }

    func retireItems(in save: inout PlayerSave) {
        for item in save.inventory.items where retiredItems.contains(item.id) {
            save.roster.unequip(itemID: item.id)
        }
        save.inventory.items.removeAll { retiredItems.contains($0.id) }
    }
}
