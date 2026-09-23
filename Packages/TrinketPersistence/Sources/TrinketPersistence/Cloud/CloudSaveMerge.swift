import Foundation
import TrinketContent
import TrinketCore

/// Reconciles independent save branches within one account and reset epoch.
/// The common ancestor makes resource deltas meaningful; unrelated older saves
/// use the larger balance because their shared rewards cannot be identified.
enum CloudSaveMerge {
    static func merge(
        incoming: PlayerSave, existing: PlayerSave, base: PlayerSave?, preferIncoming: Bool,
    ) -> PlayerSave {
        let incomingIsRecent = incoming.modifiedAt == existing.modifiedAt
            ? preferIncoming : incoming.modifiedAt > existing.modifiedAt
        let recent = incomingIsRecent ? incoming : existing
        let other = incomingIsRecent ? existing : incoming
        let duplicateClaim = hasDuplicateClaim(incoming: incoming, existing: existing, base: base)
        var merged = recent

        mergeJourney(into: &merged, from: other)
        mergeRoster(into: &merged, from: other, incoming: incoming, existing: existing, base: base, duplicateClaim: duplicateClaim)
        mergeSelections(into: &merged, incoming: incoming, existing: existing, base: base, preferIncoming: incomingIsRecent)
        mergeInventory(into: &merged, from: other, base: base)
        mergeEconomy(into: &merged, incoming: incoming, existing: existing, base: base, duplicateClaim: duplicateClaim)
        mergeExploration(into: &merged, from: other)
        merged.contracts.recordVictory(encounterLevel: other.contracts.highestWonEncounterLevel)
        merged.contracts.reconcileRefreshAvailability(selected(
            incoming.contracts.refreshAvailable, existing.contracts.refreshAvailable,
            base: base?.contracts.refreshAvailable, preferIncoming: incomingIsRecent,
        ) ?? merged.contracts.refreshAvailable)
        merged.corruptionAltarCooldownRemaining = max(
            merged.corruptionAltarCooldownRemaining, other.corruptionAltarCooldownRemaining,
        )
        merged.modifiedAt = max(incoming.modifiedAt, existing.modifiedAt)
        return merged
    }

    private static func mergeJourney(into merged: inout PlayerSave, from other: PlayerSave) {
        merged.journey.completedStageIDs.formUnion(other.journey.completedStageIDs)
        merged.journey.claimedRewardStageIDs.formUnion(other.journey.claimedRewardStageIDs)
        merged.journey.pinnedMysteryEventIDs.merge(other.journey.pinnedMysteryEventIDs) { current, _ in current }
        merged.journey.mysteryOfferPayloads.merge(other.journey.mysteryOfferPayloads) { current, _ in current }
        for (id, payload) in other.journey.shopPayloads {
            merged.journey.shopPayloads[id] = ShopStockPersistence.mergedPayload(
                preferred: merged.journey.shopPayloads[id], other: payload,
            )
        }
        if let last = GameContent.chapters.flatMap(\.stages).last(where: { merged.journey.completedStageIDs.contains($0.id) }) {
            merged.journey.complete(last, in: GameContent.chapters)
        }
    }

    private static func mergeRoster(
        into merged: inout PlayerSave, from other: PlayerSave,
        incoming: PlayerSave, existing: PlayerSave, base: PlayerSave?, duplicateClaim: Bool,
    ) {
        merged.roster.unlockedHeroIDs.formUnion(other.roster.unlockedHeroIDs)
        merged.roster.unlockedCompanionIDs.formUnion(other.roster.unlockedCompanionIDs)
        for (id, talents) in other.roster.unlockedTalents {
            merged.roster.unlockedTalents[id, default: []].formUnion(talents)
        }
        for (id, progression) in other.roster.progressions {
            if let current = merged.roster.progressions[id] {
                merged.roster.progressions[id] = mergedProgression(
                    incoming.roster.progressions[id], existing.roster.progressions[id],
                    base: duplicateClaim ? nil : base?.roster.progressions[id],
                    fallback: maxProgression(current, progression),
                )
            } else {
                merged.roster.progressions[id] = progression
            }
        }
        for (id, loadout) in other.roster.abilityLoadouts where merged.roster.abilityLoadouts[id] == nil {
            merged.roster.abilityLoadouts[id] = loadout
        }
        for (id, loadout) in other.roster.equipmentLoadouts where merged.roster.equipmentLoadouts[id] == nil {
            merged.roster.equipmentLoadouts[id] = loadout
        }
    }

    private static func mergeInventory(
        into merged: inout PlayerSave, from other: PlayerSave,
        base: PlayerSave?,
    ) {
        if let base {
            for item in base.inventory.items {
                guard let index = merged.inventory.items.firstIndex(where: { $0.id == item.id }),
                      merged.inventory.items[index] == item else { continue }
                if let changed = other.inventory.item(matching: item.id) {
                    merged.inventory.items[index] = changed
                } else {
                    merged.inventory.removeItem(id: item.id)
                }
            }
        }
        for item in other.inventory.items {
            if let base, base.inventory.item(matching: item.id) != nil,
               merged.inventory.item(matching: item.id) == nil {
                continue
            }
            merged.inventory.appendUniqueItem(item)
        }
    }

    private static func mergeSelections(
        into merged: inout PlayerSave, incoming: PlayerSave, existing: PlayerSave,
        base: PlayerSave?, preferIncoming: Bool,
    ) {
        merged.roster.activeHeroID = selected(
            incoming.roster.activeHeroID, existing.roster.activeHeroID,
            base: base?.roster.activeHeroID, preferIncoming: preferIncoming,
        ) ?? merged.roster.activeHeroID
        merged.roster.activeCompanionID = selected(
            incoming.roster.activeCompanionID, existing.roster.activeCompanionID,
            base: base?.roster.activeCompanionID, preferIncoming: preferIncoming,
        ) ?? merged.roster.activeCompanionID
        let combatantIDs = Set(incoming.roster.equipmentLoadouts.keys)
            .union(existing.roster.equipmentLoadouts.keys)
        for id in combatantIDs {
            var slots: [ItemSlot: String] = [:]
            for slot in ItemSlot.allCases {
                let chosen = selected(
                    incoming.roster.equipmentLoadouts[id]?.itemID(for: slot),
                    existing.roster.equipmentLoadouts[id]?.itemID(for: slot),
                    base: base?.roster.equipmentLoadouts[id]?.itemID(for: slot),
                    preferIncoming: preferIncoming,
                )
                slots[slot] = chosen
            }
            merged.roster.equipmentLoadouts[id] = EquipmentLoadout(itemIDsBySlot: slots)
        }
        let abilityIDs = Set(incoming.roster.abilityLoadouts.keys).union(existing.roster.abilityLoadouts.keys)
        for id in abilityIDs {
            merged.roster.abilityLoadouts[id] = selected(
                incoming.roster.abilityLoadouts[id], existing.roster.abilityLoadouts[id],
                base: base?.roster.abilityLoadouts[id], preferIncoming: preferIncoming,
            )
        }
    }

    private static func selected<Value: Equatable>(
        _ incoming: Value?, _ existing: Value?, base: Value?, preferIncoming: Bool,
    ) -> Value? {
        guard base != nil else { return preferIncoming ? incoming : existing }
        if incoming == base {
            return existing
        }
        if existing == base {
            return incoming
        }
        return preferIncoming ? incoming : existing
    }

    private static func mergeEconomy(
        into merged: inout PlayerSave, incoming: PlayerSave, existing: PlayerSave,
        base: PlayerSave?, duplicateClaim: Bool,
    ) {
        let overlappingProduction = base.map {
            incoming.homestead.lastProductionAt > $0.homestead.lastProductionAt
                && existing.homestead.lastProductionAt > $0.homestead.lastProductionAt
        } ?? false
        let overlappingUpgrade = base.map { base in
            HomesteadNodeID.allCases.contains { id in
                incoming.homestead.tier(for: id) > base.homestead.tier(for: id)
                    && existing.homestead.tier(for: id) > base.homestead.tier(for: id)
            }
        } ?? false
        let canCombine = base != nil && !duplicateClaim
        let repeatedGold = overlappingProduction
            && incoming.roster.gold > (base?.roster.gold ?? 0)
            && existing.roster.gold > (base?.roster.gold ?? 0)
        merged.roster.gold = balance(
            incoming.roster.gold, existing.roster.gold, base: base?.roster.gold,
            combine: canCombine && !repeatedGold,
        )
        for resource in HomesteadResource.allCases where resource != .gold {
            let first = incoming.homestead.resources[resource, default: 0]
            let second = existing.homestead.resources[resource, default: 0]
            let starting = base?.homestead.resources[resource, default: 0]
            let repeated = overlappingProduction && first > (starting ?? 0) && second > (starting ?? 0)
            merged.homestead.resources[resource] = balance(
                first, second, base: starting, combine: canCombine && !overlappingUpgrade && !repeated,
            )
        }
        for (id, tier) in incoming.homestead.nodeTiers.merging(existing.homestead.nodeTiers, uniquingKeysWith: max) {
            merged.homestead.nodeTiers[id] = tier
        }
        merged.homestead.lastProductionAt = max(incoming.homestead.lastProductionAt, existing.homestead.lastProductionAt)
        mergePendingProduction(
            into: &merged, incoming: incoming, existing: existing,
            base: base, overlappingProduction: overlappingProduction,
        )
    }

    private static func mergePendingProduction(
        into merged: inout PlayerSave, incoming: PlayerSave, existing: PlayerSave,
        base: PlayerSave?, overlappingProduction: Bool,
    ) {
        for resource in HomesteadResource.allCases {
            let current = incoming.homestead.pendingProduction[resource, default: 0]
            let amount = existing.homestead.pendingProduction[resource, default: 0]
            let baseBalance = resource == .gold ? base?.roster.gold : base?.homestead.resources[resource, default: 0]
            let incomingBalance = resource == .gold ? incoming.roster.gold : incoming.homestead.resources[resource, default: 0]
            let existingBalance = resource == .gold ? existing.roster.gold : existing.homestead.resources[resource, default: 0]
            let collected = overlappingProduction && baseBalance.map {
                incomingBalance > $0 || existingBalance > $0
            } == true
            let pending = collected ? min(current, amount) : max(current, amount)
            if pending > 0 {
                merged.homestead.pendingProduction[resource] = pending
            } else {
                merged.homestead.pendingProduction.removeValue(forKey: resource)
            }
        }
    }

    private static func mergeExploration(into merged: inout PlayerSave, from other: PlayerSave) {
        for (id, floor) in other.spires.highestClearedFloorBySpireID {
            merged.spires.highestClearedFloorBySpireID[id] = max(
                merged.spires.highestClearedFloorBySpireID[id, default: 0], floor,
            )
        }
        mergeLabyrinth(into: &merged, from: other)
        let currentVoyageCleared = merged.voyage.activeRun?.nodes.filter(\.isCleared).count ?? 0
        let otherVoyageCleared = other.voyage.activeRun?.nodes.filter(\.isCleared).count ?? 0
        if otherVoyageCleared > currentVoyageCleared {
            merged.voyage = other.voyage
        }
        if let run = merged.voyage.activeRun, let otherRun = other.voyage.activeRun, run.id == otherRun.id {
            for node in otherRun.nodes {
                merged.voyage.updateNode(runID: run.id, nodeID: node.id) { current in
                    current.isCleared = current.isCleared || node.isCleared
                    current.shopPayload = ShopStockPersistence.mergedPayload(
                        preferred: current.shopPayload, other: node.shopPayload,
                    )
                    current.mysteryOffersPayload = current.mysteryOffersPayload ?? node.mysteryOffersPayload
                }
            }
        }
    }

    private static func mergeLabyrinth(into merged: inout PlayerSave, from other: PlayerSave) {
        guard merged.labyrinth.worldSeed == other.labyrinth.worldSeed else {
            let currentRank = (merged.labyrinth.currentFloorNumber, merged.labyrinth.nodes.values.filter(\.isCleared).count)
            let otherRank = (other.labyrinth.currentFloorNumber, other.labyrinth.nodes.values.filter(\.isCleared).count)
            if otherRank.0 > currentRank.0 || (otherRank.0 == currentRank.0 && otherRank.1 > currentRank.1) {
                merged.labyrinth = other.labyrinth
            }
            return
        }
        merged.labyrinth.hasEntered = merged.labyrinth.hasEntered || other.labyrinth.hasEntered
        for (id, node) in other.labyrinth.nodes {
            guard var current = merged.labyrinth.nodes[id] else {
                merged.labyrinth.nodes[id] = node
                continue
            }
            current.isCleared = current.isCleared || node.isCleared
            current.isRevealed = current.isRevealed || node.isRevealed
            current.shopPayload = ShopStockPersistence.mergedPayload(preferred: current.shopPayload, other: node.shopPayload)
            current.mysteryOffersPayload = current.mysteryOffersPayload ?? node.mysteryOffersPayload
            merged.labyrinth.nodes[id] = current
        }
    }
}

private extension CloudSaveMerge {
    static func balance(_ lhs: Int, _ rhs: Int, base: Int?, combine: Bool) -> Int {
        guard combine, let base else { return max(lhs, rhs) }
        let left = SaturatedArithmetic.saturatingSub(lhs, base)
        let right = SaturatedArithmetic.saturatingSub(rhs, base)
        return max(0, SaturatedArithmetic.saturatingAdd(base, SaturatedArithmetic.saturatingAdd(left, right)))
    }

    private static func hasDuplicateClaim(incoming: PlayerSave, existing: PlayerSave, base: PlayerSave?) -> Bool {
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
        for (spireID, floor) in base.spires.highestClearedFloorBySpireID {
            if incoming.spires.highestClearedFloorBySpireID[spireID, default: 0] > floor,
               existing.spires.highestClearedFloorBySpireID[spireID, default: 0] > floor {
                return true
            }
        }
        if hasSharedNodeClaim(incoming: incoming, existing: existing, base: base),
           !distinctNewItems(incoming: incoming, existing: existing, priorIDs: existingItemIDs) {
            return true
        }
        if hasSharedShopPurchase(incoming: incoming, existing: existing, base: base) {
            return true
        }
        return false
    }

    private static func hasSharedShopPurchase(incoming: PlayerSave, existing: PlayerSave, base: PlayerSave) -> Bool {
        let stages = Set(incoming.journey.shopPayloads.keys).intersection(existing.journey.shopPayloads.keys)
        for id in stages {
            let prior = ShopStockPersistence.purchasedOfferIDs(in: base.journey.shopPayloads[id])
            let first = ShopStockPersistence.purchasedOfferIDs(in: incoming.journey.shopPayloads[id]).subtracting(prior)
            let second = ShopStockPersistence.purchasedOfferIDs(in: existing.journey.shopPayloads[id]).subtracting(prior)
            if !first.isDisjoint(with: second) {
                return true
            }
        }
        if base.labyrinth.worldSeed == incoming.labyrinth.worldSeed,
           base.labyrinth.worldSeed == existing.labyrinth.worldSeed {
            let nodes = Set(incoming.labyrinth.nodes.keys).intersection(existing.labyrinth.nodes.keys)
            for id in nodes {
                let prior = ShopStockPersistence.purchasedOfferIDs(in: base.labyrinth.nodes[id]?.shopPayload)
                let first = ShopStockPersistence.purchasedOfferIDs(in: incoming.labyrinth.nodes[id]?.shopPayload).subtracting(prior)
                let second = ShopStockPersistence.purchasedOfferIDs(in: existing.labyrinth.nodes[id]?.shopPayload).subtracting(prior)
                if !first.isDisjoint(with: second) {
                    return true
                }
            }
        }
        if let run = base.voyage.activeRun,
           incoming.voyage.activeRun?.id == run.id,
           existing.voyage.activeRun?.id == run.id {
            for node in run.nodes {
                let prior = ShopStockPersistence.purchasedOfferIDs(in: node.shopPayload)
                let first = ShopStockPersistence.purchasedOfferIDs(
                    in: incoming.voyage.node(runID: run.id, nodeID: node.id)?.shopPayload,
                ).subtracting(prior)
                let second = ShopStockPersistence.purchasedOfferIDs(
                    in: existing.voyage.node(runID: run.id, nodeID: node.id)?.shopPayload,
                ).subtracting(prior)
                if !first.isDisjoint(with: second) {
                    return true
                }
            }
        }
        return false
    }

    private static func hasSharedNodeClaim(incoming: PlayerSave, existing: PlayerSave, base: PlayerSave) -> Bool {
        if base.labyrinth.worldSeed == incoming.labyrinth.worldSeed,
           base.labyrinth.worldSeed == existing.labyrinth.worldSeed {
            for (id, node) in base.labyrinth.nodes where !node.isCleared {
                if incoming.labyrinth.nodes[id]?.isCleared == true,
                   existing.labyrinth.nodes[id]?.isCleared == true {
                    return true
                }
            }
        }
        guard let run = base.voyage.activeRun,
              incoming.voyage.activeRun?.id == run.id,
              existing.voyage.activeRun?.id == run.id else { return false }
        return run.nodes.contains { node in
            !node.isCleared && incoming.voyage.activeRun?.nodes.contains { $0.id == node.id && $0.isCleared } == true
                && existing.voyage.activeRun?.nodes.contains { $0.id == node.id && $0.isCleared } == true
        }
    }

    private static func distinctNewItems(
        incoming: PlayerSave, existing: PlayerSave, priorIDs: Set<String>,
    ) -> Bool {
        let first = Set(incoming.inventory.items.map(\.id)).subtracting(priorIDs)
        let second = Set(existing.inventory.items.map(\.id)).subtracting(priorIDs)
        return !first.isEmpty && !second.isEmpty && first.isDisjoint(with: second)
    }

    private static func maxProgression(_ lhs: CombatantProgression, _ rhs: CombatantProgression) -> CombatantProgression {
        if lhs.level != rhs.level {
            return lhs.level > rhs.level ? lhs : rhs
        }
        return lhs.currentXP >= rhs.currentXP ? lhs : rhs
    }

    private static func mergedProgression(
        _ incoming: CombatantProgression?, _ existing: CombatantProgression?,
        base: CombatantProgression?, fallback: CombatantProgression,
    ) -> CombatantProgression {
        guard let incoming, let existing, let base else { return fallback }
        let starting = totalExperience(base)
        let left = max(0, SaturatedArithmetic.saturatingSub(totalExperience(incoming), starting))
        let right = max(0, SaturatedArithmetic.saturatingSub(totalExperience(existing), starting))
        return base.addingExperience(SaturatedArithmetic.saturatingAdd(left, right))
    }

    private static func totalExperience(_ progression: CombatantProgression) -> Int {
        guard progression.level > 1 else { return max(0, progression.currentXP) }
        var total = max(0, progression.currentXP)
        for level in 1 ..< progression.level {
            total = SaturatedArithmetic.saturatingAdd(total, CombatantProgression.requiredXP(forLevel: level))
            if total == Int.max {
                break
            }
        }
        return total
    }
}
