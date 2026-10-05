import Foundation
import TrinketContent
import TrinketCore

/// Reconciles independent save branches within one account and reset epoch.
/// The common ancestor makes resource deltas meaningful; unrelated older saves
/// use the larger balance because their shared rewards cannot be identified.
enum CloudSaveMerge {
    /// One reconciliation decision shared by every save slice.
    struct Branches {
        let incoming: PlayerSave
        let existing: PlayerSave
        let base: PlayerSave?
        let recent: PlayerSave
        let other: PlayerSave
        /// Overlapping claims may describe the same payout on both branches.
        let canCombineIndependentRewards: Bool

        init(incoming: PlayerSave, existing: PlayerSave, base: PlayerSave?, preferIncoming: Bool, reconcileEconomy: Bool = true) {
            self.incoming = incoming
            self.existing = existing
            self.base = base
            let prefersIncoming = incoming.modifiedAt == existing.modifiedAt
                ? preferIncoming : incoming.modifiedAt > existing.modifiedAt
            recent = prefersIncoming ? incoming : existing
            other = prefersIncoming ? existing : incoming
            canCombineIndependentRewards = reconcileEconomy && base != nil
                && !CloudSaveMerge.hasDuplicateClaim(incoming: incoming, existing: existing, base: base)
        }

        func selected<Value: Equatable>(_ value: (PlayerSave) -> Value) -> Value {
            let preferred = value(recent)
            // Only an unchanged preferred field yields to the other branch.
            // Optional fields retain nil as a real value, including in the base.
            guard let base, preferred == value(base) else { return preferred }
            return value(other)
        }
    }

    static func merge(
        incoming: PlayerSave, existing: PlayerSave, base: PlayerSave?, preferIncoming: Bool,
        reconcileEconomy: Bool = true,
    ) -> PlayerSave {
        let branches = Branches(
            incoming: incoming,
            existing: existing,
            base: base,
            preferIncoming: preferIncoming,
            reconcileEconomy: reconcileEconomy,
        )
        var merged = branches.recent

        mergeJourney(into: &merged, from: branches.other)
        mergeRoster(into: &merged, branches: branches)
        mergeSelections(into: &merged, branches: branches)
        mergeInventory(into: &merged, from: branches.other, base: branches.base)
        preserveRecentWeaponPairs(into: &merged, recent: branches.recent, base: branches.base)
        if reconcileEconomy {
            mergeEconomy(into: &merged, branches: branches)
        } else {
            merged.homestead.nodeTiers = incoming.homestead.nodeTiers.merging(existing.homestead.nodeTiers, uniquingKeysWith: max)
            merged.homestead.lastProductionAt = max(incoming.homestead.lastProductionAt, existing.homestead.lastProductionAt)
        }
        mergeExploration(into: &merged, branches: branches)
        mergeContracts(into: &merged, branches: branches)
        mergeCorruptionAltarCooldown(into: &merged, branches: branches)
        merged.modifiedAt = max(incoming.modifiedAt, existing.modifiedAt)
        return merged
    }

    private static func mergeCorruptionAltarCooldown(into merged: inout PlayerSave, branches: Branches) {
        let incoming = branches.incoming.corruptionAltarCooldownRemaining
        let existing = branches.existing.corruptionAltarCooldownRemaining
        if let reset = [branches.recent, branches.other].first(where: {
            hasNewCorruptionAltarCompletion(in: $0, base: branches.base)
        }) {
            merged.corruptionAltarCooldownRemaining = reset.corruptionAltarCooldownRemaining
            return
        }
        if let base = branches.base?.corruptionAltarCooldownRemaining,
           incoming < base, existing < base {
            let shared = min(sharedMysteryCompletionCount(branches: branches), base - incoming, base - existing)
            let completed = SaturatedArithmetic.saturatingAdd(base - incoming, base - existing) - shared
            merged.corruptionAltarCooldownRemaining = max(0, base - completed)
        } else {
            merged.corruptionAltarCooldownRemaining = branches.selected(\.corruptionAltarCooldownRemaining)
        }
    }

    private static func mergeJourney(into merged: inout PlayerSave, from other: PlayerSave) {
        merged.journey.completedStageIDs.formUnion(other.journey.completedStageIDs)
        merged.journey.claimedRewardStageIDs.formUnion(other.journey.claimedRewardStageIDs)
        merged.journey.pinnedMysteryEventIDs.merge(other.journey.pinnedMysteryEventIDs) { current, _ in current }
        merged.journey.mysteryOfferPayloads.merge(other.journey.mysteryOfferPayloads) { current, peer in
            MysteryOfferPersistence.mergedPayload(preferred: current, other: peer) ?? current
        }
        for (id, payload) in other.journey.shopPayloads {
            merged.journey.shopPayloads[id] = ShopStockPersistence.mergedPayload(
                preferred: merged.journey.shopPayloads[id], other: payload,
            )
        }
        if let last = GameContent.chapters.flatMap(\.stages).last(where: { merged.journey.completedStageIDs.contains($0.id) }) {
            merged.journey.complete(last, in: GameContent.chapters)
        }
    }

    private static func mergeContracts(into merged: inout PlayerSave, branches: Branches) {
        let offers = ContractDifficulty.allCases.compactMap { difficulty in
            branches.selected { $0.contracts.offer(for: difficulty) }
        }
        merged.contracts = PlayerContractsState(
            offers: offers,
            refreshAvailable: branches.selected(\.contracts.refreshAvailable),
            highestWonEncounterLevel: max(
                branches.incoming.contracts.highestWonEncounterLevel,
                branches.existing.contracts.highestWonEncounterLevel,
            ),
        )
        if branches.incoming.contracts.completedOfferIDs != nil || branches.existing.contracts.completedOfferIDs != nil {
            merged.contracts.completedOfferIDs = (branches.incoming.contracts.completedOfferIDs ?? [])
                .union(branches.existing.contracts.completedOfferIDs ?? [])
        } else {
            merged.contracts.completedOfferIDs = nil
        }
        merged.contracts = merged.contracts.sanitized()
        if !offers.isEmpty {
            merged.contracts.ensureBoard(eligibleModifiers: ContractsCompletion.eligibleModifiers(in: merged.inventory))
        }
    }

    private static func mergeRoster(into merged: inout PlayerSave, branches: Branches) {
        let other = branches.other
        merged.roster.unlockedHeroIDs.formUnion(other.roster.unlockedHeroIDs)
        merged.roster.unlockedCompanionIDs.formUnion(other.roster.unlockedCompanionIDs)
        let talentCombatantIDs = Set(branches.incoming.roster.unlockedTalents.keys)
            .union(branches.existing.roster.unlockedTalents.keys)
        for id in talentCombatantIDs {
            let incoming = branches.incoming.roster.unlockedTalents(for: id)
            let existing = branches.existing.roster.unlockedTalents(for: id)
            var talents = incoming.union(existing)
            if let base = branches.base?.roster.unlockedTalents[id] {
                // Reset removes shared purchases; independently purchased talents still survive.
                talents.subtract(base.subtracting(incoming).union(base.subtracting(existing)))
            }
            merged.roster.unlockedTalents[id] = talents.isEmpty ? nil : talents
        }
        for (id, progression) in other.roster.progressions {
            if let current = merged.roster.progressions[id] {
                merged.roster.progressions[id] = mergedProgression(
                    branches.incoming.roster.progressions[id], branches.existing.roster.progressions[id],
                    // Recruiting starts at level one with no XP, even when the shared save has no row yet.
                    base: branches.canCombineIndependentRewards ? (branches.base?.roster.progressions[id] ?? .initial) : nil,
                    fallback: maxProgression(current, progression),
                )
            } else {
                merged.roster.progressions[id] = progression
            }
        }
    }

    private static func mergeInventory(
        into merged: inout PlayerSave, from other: PlayerSave,
        base: PlayerSave?,
    ) {
        let baseByID = Dictionary(
            (base?.inventory.items ?? []).lazy.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first },
        )
        if !baseByID.isEmpty {
            let otherByID = Dictionary(
                other.inventory.items.lazy.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first },
            )
            merged.inventory.items = merged.inventory.items.compactMap { item in
                guard let original = baseByID[item.id] else { return item }
                // A shared physical item cannot survive its salvage on either device.
                guard let changed = otherByID[item.id] else { return nil }
                return item == original ? changed : item
            }
        }
        let retainedIDs = Set(merged.inventory.items.lazy.map(\.id))
        let candidates = other.inventory.items.lazy.filter {
            baseByID[$0.id] == nil || retainedIDs.contains($0.id)
        }
        InventoryDuplicatePolicy.appendUniqueItems(candidates, to: &merged.inventory.items)
    }

    private static func mergeSelections(into merged: inout PlayerSave, branches: Branches) {
        merged.roster.activeHeroID = branches.selected(\.roster.activeHeroID)
        merged.roster.activeCompanionID = branches.selected(\.roster.activeCompanionID)
        let combatantIDs = Set(branches.recent.roster.equipmentLoadouts.keys)
            .union(branches.other.roster.equipmentLoadouts.keys)
        for id in combatantIDs {
            var slots: [ItemSlot: String] = [:]
            for slot in ItemSlot.allCases {
                slots[slot] = branches.selected { $0.roster.equipmentLoadouts[id]?.itemID(for: slot) }
            }
            merged.roster.equipmentLoadouts[id] = EquipmentLoadout(itemIDsBySlot: slots)
        }
        // Index the recent assignments retained by field selection, then remove
        // conflicting placements in one pass before roster sanitization.
        var preferredAssignments: [String: (ownerID: String, slot: ItemSlot)] = [:]
        for (ownerID, recentLoadout) in branches.recent.roster.equipmentLoadouts {
            for (slot, itemID) in recentLoadout.itemIDsBySlot
                where merged.roster.equipmentLoadouts[ownerID]?.itemID(for: slot) == itemID {
                preferredAssignments[itemID] = (ownerID, slot)
            }
        }
        for (ownerID, loadout) in merged.roster.equipmentLoadouts {
            merged.roster.equipmentLoadouts[ownerID] = EquipmentLoadout(itemIDsBySlot: loadout.itemIDsBySlot.filter { slot, itemID in
                guard let preferred = preferredAssignments[itemID] else { return true }
                return preferred.ownerID == ownerID && preferred.slot == slot
            })
        }
        let abilityIDs = Set(branches.recent.roster.abilityLoadouts.keys).union(branches.other.roster.abilityLoadouts.keys)
        for id in abilityIDs {
            merged.roster.abilityLoadouts[id] = branches.selected { $0.roster.abilityLoadouts[id] }
        }
    }

    private static func preserveRecentWeaponPairs(into merged: inout PlayerSave, recent: PlayerSave, base: PlayerSave?) {
        for (id, recentLoadout) in recent.roster.equipmentLoadouts {
            guard let secondaryID = recentLoadout.itemID(for: .secondaryWeapon),
                  base == nil || base?.roster.equipmentLoadouts[id]?.itemID(for: .secondaryWeapon) != secondaryID,
                  var chosen = merged.roster.equipmentLoadouts[id],
                  chosen.itemID(for: .secondaryWeapon) == secondaryID,
                  let combatant = GameContent.combatant(matching: id),
                  chosen.sanitized(for: combatant, inventory: merged.inventory.items)
                  .itemID(for: .secondaryWeapon) != secondaryID,
                  recentLoadout.sanitized(for: combatant, inventory: merged.inventory.items)
                  .itemID(for: .secondaryWeapon) == secondaryID
            else { continue }
            // The other branch's primary made this newer secondary unusable.
            chosen.itemIDsBySlot[.weapon] = recentLoadout.itemID(for: .weapon)
            // Reclaim the restored primary from any older assignment on another combatant.
            merged.roster.setEquipmentLoadout(chosen, for: combatant)
        }
    }

    private static func mergeExploration(into merged: inout PlayerSave, branches: Branches) {
        let other = branches.other
        for (id, floor) in other.spires.highestClearedFloorBySpireID {
            merged.spires.highestClearedFloorBySpireID[id] = max(
                merged.spires.highestClearedFloorBySpireID[id, default: 0], floor,
            )
        }
        mergeLabyrinth(into: &merged, from: other)
        mergeVoyage(into: &merged, branches: branches)
    }

    private static func preferredVoyage(branches: Branches) -> PlayerVoyageState {
        let peers = [
            (candidate: branches.existing.voyage, other: branches.incoming.voyage),
            (candidate: branches.incoming.voyage, other: branches.existing.voyage),
        ]
        // Retirement outranks a stale active route, before considering the shared base.
        for (candidate, other) in peers where !candidate.isUnreadable {
            if let runID = other.activeRun?.id,
               candidate.completedRunIDs?.contains(runID) == true || candidate.abandonedRunIDs?.contains(runID) == true {
                return candidate
            }
        }
        if let baseRunID = branches.base?.voyage.activeRun?.id {
            for (candidate, other) in peers where !candidate.isUnreadable {
                if other.activeRun?.id == baseRunID, candidate.activeRun?.id != baseRunID {
                    return candidate
                }
            }
        }
        return branches.selected(\.voyage)
    }

    private static func mergeVoyage(into merged: inout PlayerSave, branches: Branches) {
        let selectedVoyage = preferredVoyage(branches: branches)
        let alternateVoyage = selectedVoyage == branches.incoming.voyage
            ? branches.existing.voyage : branches.incoming.voyage
        merged.voyage = selectedVoyage
        var mergeVoyage = alternateVoyage
        let currentVoyageCleared = merged.voyage.activeRun?.nodes.filter(\.isCleared).count ?? 0
        let otherVoyageCleared = alternateVoyage.activeRun?.nodes.filter(\.isCleared).count ?? 0
        if merged.voyage.activeRun?.id == alternateVoyage.activeRun?.id,
           otherVoyageCleared > currentVoyageCleared {
            merged.voyage = alternateVoyage
            mergeVoyage = selectedVoyage
        }
        if branches.incoming.voyage.completedRunIDs != nil || branches.existing.voyage.completedRunIDs != nil {
            merged.voyage.completedRunIDs = (branches.incoming.voyage.completedRunIDs ?? [])
                .union(branches.existing.voyage.completedRunIDs ?? [])
        }
        if branches.incoming.voyage.abandonedRunIDs != nil || branches.existing.voyage.abandonedRunIDs != nil {
            merged.voyage.abandonedRunIDs = (branches.incoming.voyage.abandonedRunIDs ?? [])
                .union(branches.existing.voyage.abandonedRunIDs ?? [])
        }
        if let run = merged.voyage.activeRun, let otherRun = mergeVoyage.activeRun, run.id == otherRun.id {
            // Both routes replay the same linear encounters. Retain earned totals
            // per resource without paying their shared encounters twice.
            merged.voyage.activeRun?.earnedGold = max(run.earnedGold, otherRun.earnedGold)
            for (resource, amount) in otherRun.earnedMaterials {
                merged.voyage.activeRun?.earnedMaterials[resource] = max(run.earnedMaterials[resource, default: 0], amount)
            }
            for node in otherRun.nodes {
                merged.voyage.updateNode(runID: run.id, nodeID: node.id) { current in
                    current.isCleared = current.isCleared || node.isCleared
                    current.shopPayload = ShopStockPersistence.mergedPayload(
                        preferred: current.shopPayload, other: node.shopPayload,
                    )
                    current.mysteryEventID = current.mysteryEventID ?? node.mysteryEventID
                    current.mysteryOffersPayload = MysteryOfferPersistence.mergedPayload(
                        preferred: current.mysteryOffersPayload, other: node.mysteryOffersPayload,
                    )
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
        let existingClusterIDs = Set(merged.labyrinth.clusters.map(\.id))
        merged.labyrinth.clusters.append(contentsOf: other.labyrinth.clusters.filter {
            !existingClusterIDs.contains($0.id)
        })
        for (id, node) in other.labyrinth.nodes {
            guard var current = merged.labyrinth.nodes[id] else {
                merged.labyrinth.nodes[id] = node
                continue
            }
            current.isCleared = current.isCleared || node.isCleared
            current.isRevealed = current.isRevealed || node.isRevealed
            for successor in node.outgoingIDs where !current.outgoingIDs.contains(successor) {
                current.outgoingIDs.append(successor)
            }
            current.shopPayload = ShopStockPersistence.mergedPayload(preferred: current.shopPayload, other: node.shopPayload)
            current.mysteryEventID = current.mysteryEventID ?? node.mysteryEventID
            current.mysteryOffersPayload = MysteryOfferPersistence.mergedPayload(
                preferred: current.mysteryOffersPayload, other: node.mysteryOffersPayload,
            )
            merged.labyrinth.nodes[id] = current
        }
    }
}

private extension CloudSaveMerge {
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
        let starting = base.totalEarnedExperience
        let left = max(0, SaturatedArithmetic.saturatingSub(incoming.totalEarnedExperience, starting))
        let right = max(0, SaturatedArithmetic.saturatingSub(existing.totalEarnedExperience, starting))
        return base.addingExperience(SaturatedArithmetic.saturatingAdd(left, right))
    }
}
