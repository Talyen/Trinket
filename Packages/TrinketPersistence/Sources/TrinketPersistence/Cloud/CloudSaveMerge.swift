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
        let prefersIncoming: Bool
        /// Overlapping claims may describe the same payout on both branches.
        let canCombineIndependentRewards: Bool

        init(incoming: PlayerSave, existing: PlayerSave, base: PlayerSave?, preferIncoming: Bool) {
            self.incoming = incoming
            self.existing = existing
            self.base = base
            prefersIncoming = incoming.modifiedAt == existing.modifiedAt
                ? preferIncoming : incoming.modifiedAt > existing.modifiedAt
            recent = prefersIncoming ? incoming : existing
            other = prefersIncoming ? existing : incoming
            canCombineIndependentRewards = base != nil
                && !CloudSaveMerge.hasDuplicateClaim(incoming: incoming, existing: existing, base: base)
        }

        func selected<Value: Equatable>(_ incoming: Value?, _ existing: Value?, base: Value?) -> Value? {
            // A missing field is still a meaningful baseline when the shared save exists.
            guard self.base != nil else { return prefersIncoming ? incoming : existing }
            if incoming == base {
                return existing
            }
            if existing == base {
                return incoming
            }
            return prefersIncoming ? incoming : existing
        }
    }

    static func merge(
        incoming: PlayerSave, existing: PlayerSave, base: PlayerSave?, preferIncoming: Bool,
    ) -> PlayerSave {
        let branches = Branches(incoming: incoming, existing: existing, base: base, preferIncoming: preferIncoming)
        var merged = branches.recent

        mergeJourney(into: &merged, from: branches.other)
        mergeRoster(into: &merged, branches: branches)
        mergeSelections(into: &merged, branches: branches)
        mergeInventory(into: &merged, from: branches.other, base: branches.base)
        preserveRecentWeaponPairs(into: &merged, recent: branches.recent, base: branches.base)
        mergeEconomy(into: &merged, branches: branches)
        mergeExploration(into: &merged, branches: branches)
        mergeContracts(into: &merged, branches: branches)
        merged.corruptionAltarCooldownRemaining = branches.selected(
            incoming.corruptionAltarCooldownRemaining, existing.corruptionAltarCooldownRemaining,
            base: base?.corruptionAltarCooldownRemaining,
        ) ?? merged.corruptionAltarCooldownRemaining
        merged.modifiedAt = max(incoming.modifiedAt, existing.modifiedAt)
        return merged
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
            branches.selected(
                branches.incoming.contracts.offer(for: difficulty),
                branches.existing.contracts.offer(for: difficulty),
                base: branches.base?.contracts.offer(for: difficulty),
            )
        }
        merged.contracts = PlayerContractsState(
            offers: offers,
            refreshAvailable: branches.selected(
                branches.incoming.contracts.refreshAvailable,
                branches.existing.contracts.refreshAvailable,
                base: branches.base?.contracts.refreshAvailable,
            ) ?? merged.contracts.refreshAvailable,
            highestWonEncounterLevel: max(
                branches.incoming.contracts.highestWonEncounterLevel,
                branches.existing.contracts.highestWonEncounterLevel,
            ),
        ).sanitized()
        if !offers.isEmpty {
            merged.contracts.ensureBoard(eligibleModifiers: ContractsCompletion.eligibleModifiers(in: merged.inventory))
        }
    }

    private static func mergeRoster(into merged: inout PlayerSave, branches: Branches) {
        let other = branches.other
        merged.roster.unlockedHeroIDs.formUnion(other.roster.unlockedHeroIDs)
        merged.roster.unlockedCompanionIDs.formUnion(other.roster.unlockedCompanionIDs)
        for (id, talents) in other.roster.unlockedTalents {
            merged.roster.unlockedTalents[id, default: []].formUnion(talents)
        }
        for (id, progression) in other.roster.progressions {
            if let current = merged.roster.progressions[id] {
                merged.roster.progressions[id] = mergedProgression(
                    branches.incoming.roster.progressions[id], branches.existing.roster.progressions[id],
                    base: branches.canCombineIndependentRewards ? branches.base?.roster.progressions[id] : nil,
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

    private static func mergeSelections(into merged: inout PlayerSave, branches: Branches) {
        let incoming = branches.incoming
        let existing = branches.existing
        let base = branches.base
        merged.roster.activeHeroID = branches.selected(
            incoming.roster.activeHeroID, existing.roster.activeHeroID,
            base: base?.roster.activeHeroID,
        ) ?? merged.roster.activeHeroID
        merged.roster.activeCompanionID = branches.selected(
            incoming.roster.activeCompanionID, existing.roster.activeCompanionID,
            base: base?.roster.activeCompanionID,
        ) ?? merged.roster.activeCompanionID
        let combatantIDs = Set(incoming.roster.equipmentLoadouts.keys)
            .union(existing.roster.equipmentLoadouts.keys)
        for id in combatantIDs {
            var slots: [ItemSlot: String] = [:]
            for slot in ItemSlot.allCases {
                let chosen = branches.selected(
                    incoming.roster.equipmentLoadouts[id]?.itemID(for: slot),
                    existing.roster.equipmentLoadouts[id]?.itemID(for: slot),
                    base: base?.roster.equipmentLoadouts[id]?.itemID(for: slot),
                )
                slots[slot] = chosen
            }
            merged.roster.equipmentLoadouts[id] = EquipmentLoadout(itemIDsBySlot: slots)
        }
        // Two branches can place one item in different slots or on different heroes.
        // Keep the recent assignment before roster sanitization deduplicates by ID order.
        for (ownerID, recentLoadout) in branches.recent.roster.equipmentLoadouts {
            guard var chosenLoadout = merged.roster.equipmentLoadouts[ownerID] else { continue }
            for slot in ItemSlot.allCases {
                guard let itemID = recentLoadout.itemID(for: slot), chosenLoadout.itemID(for: slot) == itemID else { continue }
                for otherSlot in ItemSlot.allCases where otherSlot != slot && chosenLoadout.itemID(for: otherSlot) == itemID {
                    chosenLoadout.unequip(otherSlot)
                }
            }
            merged.roster.equipmentLoadouts[ownerID] = chosenLoadout
            let retained = Set(recentLoadout.itemIDsBySlot.values)
                .intersection(chosenLoadout.itemIDsBySlot.values)
            guard !retained.isEmpty else { continue }
            for otherID in combatantIDs where otherID != ownerID {
                guard var loadout = merged.roster.equipmentLoadouts[otherID] else { continue }
                for slot in ItemSlot.allCases where loadout.itemID(for: slot).map(retained.contains) == true {
                    loadout.unequip(slot)
                }
                merged.roster.equipmentLoadouts[otherID] = loadout
            }
        }
        let abilityIDs = Set(incoming.roster.abilityLoadouts.keys).union(existing.roster.abilityLoadouts.keys)
        for id in abilityIDs {
            merged.roster.abilityLoadouts[id] = branches.selected(
                incoming.roster.abilityLoadouts[id], existing.roster.abilityLoadouts[id],
                base: base?.roster.abilityLoadouts[id],
            )
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
            merged.roster.equipmentLoadouts[id] = chosen
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
        let selectedVoyage: PlayerVoyageState = if let baseRunID = branches.base?.voyage.activeRun?.id,
                                                   branches.incoming.voyage.activeRun?.id == baseRunID,
                                                   branches.existing.voyage.activeRun?.id != baseRunID,
                                                   !branches.existing.voyage.isUnreadable {
            branches.existing.voyage
        } else if let baseRunID = branches.base?.voyage.activeRun?.id,
                  branches.existing.voyage.activeRun?.id == baseRunID,
                  branches.incoming.voyage.activeRun?.id != baseRunID,
                  !branches.incoming.voyage.isUnreadable {
            branches.incoming.voyage
        } else {
            branches.selected(
                branches.incoming.voyage, branches.existing.voyage, base: branches.base?.voyage,
            ) ?? merged.voyage
        }
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
        if let run = merged.voyage.activeRun, let otherRun = mergeVoyage.activeRun, run.id == otherRun.id {
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
