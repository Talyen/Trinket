import Foundation
import SwiftData
import TrinketContent
import TrinketCore

/// Slice hub: `changed`, sanitize/persist targets, `prepareCandidate`, and
/// root apply/repair live here. Per-slice read/write lives beside it in
/// `PlayerSaveModelMapping.swift` and the `*SaveModels.swift` rows; value
/// rules live in `PlayerSaveSanitizer.swift`.
///
/// `cloudStatePayload` is intentionally outside the slice set: it is local
/// sync metadata committed with the graph transaction, never uploaded
/// wholesale (see `PlayerSaveStore`). Adding a slice requires updating
/// `changed`, `apply`, `installObservedSave`, and `applyRootFields` together.
struct PlayerSaveSlice: OptionSet {
    let rawValue: UInt16

    static let root = Self(rawValue: 1 << 0)
    static let journey = Self(rawValue: 1 << 1)
    static let roster = Self(rawValue: 1 << 2)
    static let inventory = Self(rawValue: 1 << 3)
    static let homestead = Self(rawValue: 1 << 4)
    static let spires = Self(rawValue: 1 << 5)
    static let labyrinth = Self(rawValue: 1 << 6)
    static let contracts = Self(rawValue: 1 << 7)
    static let all: Self = [.root, .journey, .roster, .inventory, .homestead, .spires, .labyrinth, .contracts]

    static func changed(
        between snapshot: PlayerSave,
        and candidate: PlayerSave,
        within candidates: Self = .all,
    ) -> Self {
        var slices: Self = []
        if candidates.contains(.root) {
            if snapshot.schemaVersion != candidate.schemaVersion
                || snapshot.modifiedAt != candidate.modifiedAt
                || snapshot.sessionGeneration != candidate.sessionGeneration
                || snapshot.worldSeed != candidate.worldSeed
                || snapshot.starterSelection != candidate.starterSelection
                || snapshot.corruptionAltarCooldownRemaining != candidate.corruptionAltarCooldownRemaining {
                slices.insert(.root)
            }
        }
        if candidates.contains(.journey), snapshot.journey != candidate.journey {
            slices.insert(.journey)
        }
        if candidates.contains(.roster), snapshot.roster != candidate.roster {
            slices.insert(.roster)
        }
        if candidates.contains(.inventory), snapshot.inventory != candidate.inventory {
            slices.insert(.inventory)
        }
        if candidates.contains(.homestead), snapshot.homestead != candidate.homestead {
            slices.insert(.homestead)
        }
        if candidates.contains(.spires), snapshot.spires != candidate.spires {
            slices.insert(.spires)
        }
        if candidates.contains(.labyrinth), snapshot.labyrinth != candidate.labyrinth {
            slices.insert(.labyrinth)
        }
        if candidates.contains(.contracts), snapshot.contracts != candidate.contracts {
            slices.insert(.contracts)
        }
        return slices
    }

    static func persistTargets(for sanitizeSlices: Self) -> Self {
        sanitizeSlices.union(.root)
    }

    static func sanitizeTargets(for mutationSlices: Self) -> Self {
        var targets = mutationSlices
        if targets.contains(.inventory) {
            targets.insert(.roster)
        }
        if targets.contains(.labyrinth) {
            targets.insert(.roster)
        }
        return targets
    }

    static func prepareCandidate(
        from snapshot: PlayerSave,
        candidate proposed: PlayerSave,
    ) throws -> (candidate: PlayerSave, changedSlices: Self) {
        var candidate = proposed
        let mutationSlices = changed(between: snapshot, and: candidate)
        guard !mutationSlices.isEmpty else { return (snapshot, []) }
        let sanitizeSlices = sanitizeTargets(for: mutationSlices)
        candidate = try PlayerSaveSanitizer.sanitizeAndValidate(candidate, changedSlices: sanitizeSlices)
        var changedSlices = changed(
            between: snapshot,
            and: candidate,
            within: persistTargets(for: sanitizeSlices),
        )
        if !changedSlices.isEmpty {
            candidate.modifiedAt = Date()
            changedSlices.insert(.root)
        }
        return (candidate, changedSlices)
    }
}

public extension PlayerSaveRoot {
    convenience init(save: PlayerSave, id: String = "primary") {
        self.init(id: id)
        update(from: save)
    }

    func toPlayerSave() -> PlayerSave {
        let inventoryState = inventory?.toPlayerInventoryState() ?? .freshStart
        return PlayerSave(
            schemaVersion: schemaVersion,
            modifiedAt: modifiedAt,
            sessionGeneration: sessionGeneration,
            worldSeed: worldSeed,
            starterSelection: mappedStarterSelection,
            journey: journey?.toPlayerJourneyState() ?? .initial,
            roster: roster?.toPlayerRosterState() ?? .freshStart,
            inventory: inventoryState,
            homestead: homestead?.toPlayerHomesteadState() ?? .freshStart,
            spires: spires?.toPlayerSpiresState() ?? .freshStart,
            labyrinth: labyrinth?.toPlayerLabyrinthState() ?? .freshStart,
            contracts: PlayerContractsState.decodePayload(contractsPayload),
            corruptionAltarCooldownRemaining: corruptionAltarCooldownRemaining,
        )
    }
}

extension PlayerSaveRoot {
    func repairSlices(for sanitizedSave: PlayerSave, currentSave: PlayerSave? = nil) -> PlayerSaveSlice {
        var slices = PlayerSaveSlice.changed(between: currentSave ?? toPlayerSave(), and: sanitizedSave)

        if journey == nil || hasDuplicateKeys(journey?.stages ?? [], key: \.stageID) {
            slices.insert(.journey)
        }
        if roster == nil || rosterHasDuplicateChildren || roster?.hasDanglingRosterChildren == true {
            slices.insert(.roster)
        }
        if inventory == nil || inventoryHasDuplicateChildren || hasDanglingInventoryChildren {
            slices.insert(.inventory)
        }
        if homestead == nil || homesteadHasDuplicateChildren || hasDanglingHomesteadChildren {
            slices.insert(.homestead)
        }
        if spires == nil || hasDuplicateKeys(spires?.floors ?? [], key: \.spireID)
            || (spires?.floors ?? []).contains(where: \.spireID.isEmpty) {
            slices.insert(.spires)
        }
        if labyrinth == nil {
            slices.insert(.labyrinth)
        }
        if StarterSelectionPhase(rawValue: starterSelectionPhaseRawValue) == nil {
            slices.insert(.root)
        }
        if let payload = contractsPayload,
           payload != sanitizedSave.contracts.encodedPayload,
           PlayerContractsState.decodePayload(payload) == sanitizedSave.contracts {
            slices.insert(.contracts)
        }
        return slices
    }

    private var rosterHasDuplicateChildren: Bool {
        guard let roster else { return false }
        return hasDuplicateKeys(roster.unlockedCombatants ?? [], key: \.compositeKey)
            || hasDuplicateKeys(roster.progressions ?? [], key: \.combatantID)
            || hasDuplicateKeys(roster.abilityLoadouts ?? [], key: \.combatantID)
            || hasDuplicateKeys(roster.equipmentLoadouts ?? [], key: \.combatantID)
            || (roster.equipmentLoadouts ?? []).contains {
                hasDuplicateKeys($0.slots ?? [], key: \.slotID)
            }
            || hasDuplicateKeys(roster.talentLoadouts ?? [], key: \.combatantID)
            || (roster.talentLoadouts ?? []).contains {
                hasDuplicateKeys($0.unlockedNodes ?? [], key: \.nodeID)
            }
    }

    private var inventoryHasDuplicateChildren: Bool {
        guard let inventory else { return false }
        return hasDuplicateKeys(inventory.items ?? [], key: \.id)
            || (inventory.items ?? []).contains {
                hasDuplicateKeys($0.affixes ?? [], key: \.id)
            }
    }

    private var homesteadHasDuplicateChildren: Bool {
        guard let homestead else { return false }
        return hasDuplicateKeys(homestead.resources ?? [], key: \.resourceID)
            || hasDuplicateKeys(homestead.pendingProduction ?? [], key: \.resourceID)
            || hasDuplicateKeys(homestead.nodeTiers ?? [], key: \.nodeID)
    }

    /// Rows the value read drops silently: unknown inventory base types
    /// (`restoredItem` returns nil) and unknown/`.gold` homestead rows.
    /// Value-level `changed()` never sees them, so repair must force the
    /// slice rewrite; the next `update(from:)` reconcile deletes orphans.
    private var hasDanglingInventoryChildren: Bool {
        guard let items = inventory?.items else { return false }
        return items.contains { GameContent.itemBaseType(matching: $0.baseTypeID) == nil }
    }

    private var hasDanglingHomesteadChildren: Bool {
        guard let homestead else { return false }
        if (homestead.resources ?? []).contains(where: {
            $0.resourceID == HomesteadResource.gold.rawValue
                || HomesteadResource.resolving(resourceID: $0.resourceID) == nil
        }) {
            return true
        }
        if (homestead.pendingProduction ?? []).contains(where: {
            HomesteadResource.resolving(resourceID: $0.resourceID) == nil
        }) {
            return true
        }
        if (homestead.nodeTiers ?? []).contains(where: {
            HomesteadNodeID.resolving(nodeID: $0.nodeID) == nil
        }) {
            return true
        }
        return false
    }

    func update(from save: PlayerSave, context: ModelContext? = nil) {
        apply(save, slices: .all, context: context)
    }

    func apply(_ save: PlayerSave, slices: PlayerSaveSlice, context: ModelContext? = nil) {
        if slices.contains(.root) {
            schemaVersion = save.schemaVersion
            modifiedAt = save.modifiedAt
            sessionGeneration = save.sessionGeneration
            worldSeed = save.worldSeed
            starterSelectionPhaseRawValue = save.starterSelection.phase.rawValue
            starterHeroID = save.starterSelection.heroID
            corruptionAltarCooldownRemaining = save.corruptionAltarCooldownRemaining
        }

        if slices.contains(.journey) {
            let model = journey ?? JourneyProgressModel()
            model.update(from: save.journey, context: context)
            journey = model
            model.root = self
        }

        if slices.contains(.roster) {
            let model = roster ?? RosterModel()
            model.update(from: save.roster, context: context)
            roster = model
            model.root = self
        }

        if slices.contains(.inventory) {
            let model = inventory ?? InventoryModel()
            model.update(from: save.inventory, context: context)
            inventory = model
            model.root = self
        }

        if slices.contains(.homestead) {
            let model = homestead ?? HomesteadModel()
            model.update(from: save.homestead, context: context)
            homestead = model
            model.root = self
        }

        if slices.contains(.spires) {
            let model = spires ?? SpiresProgressModel()
            model.update(from: save.spires, context: context)
            spires = model
            model.root = self
        }

        if slices.contains(.labyrinth) {
            let model = labyrinth ?? LabyrinthProgressModel()
            model.update(from: save.labyrinth, context: context)
            labyrinth = model
            model.root = self
        }
        if slices.contains(.contracts) {
            contractsPayload = save.contracts.encodedPayload
        }
    }
}

private extension PlayerSaveRoot {
    var mappedStarterSelection: StarterSelectionState {
        guard let phase = StarterSelectionPhase(rawValue: starterSelectionPhaseRawValue) else {
            return .fresh
        }
        return StarterSelectionState(phase: phase, heroID: starterHeroID)
    }
}

private func hasDuplicateKeys<Element, Key: Hashable>(
    _ values: [Element],
    key: (Element) -> Key,
) -> Bool {
    var seen: Set<Key> = []
    return values.contains { !seen.insert(key($0)).inserted }
}
