import Foundation
import SwiftData
import TrinketContent
import TrinketCore

/// Slice hub: `changed`, sanitize/persist targets, `prepareCandidate`, and
/// root apply/repair live here. Per-slice read/write lives beside it in
/// `PlayerSaveModelMapping.swift` and the `*SaveModels.swift` rows; value
/// rules live in `PlayerSaveSanitizer*.swift` and `LabyrinthSanitizer.swift`.
///
/// `cloudStatePayload` is intentionally outside the slice set: it is local
/// sync metadata committed with the graph transaction, never uploaded
/// wholesale (see `PlayerSaveStore`). Each section is handled by exhaustive
/// switches for comparison, graph writes, and observation.
/// Declaration order keeps section iteration stable; sanitizer dependencies
/// are sequenced explicitly by `PlayerSaveSanitizer`. Raw values retain the
/// existing slice bits.
enum PlayerSaveSection: Int, CaseIterable {
    case root = 0
    case inventory = 3
    case roster = 2
    case homestead = 4
    case journey = 1
    case spires = 5
    case voyage = 8
    case contracts = 7
    case labyrinth = 6

    var slice: PlayerSaveSlice {
        PlayerSaveSlice(rawValue: 1 << rawValue)
    }

    func differs(between snapshot: PlayerSave, and candidate: PlayerSave) -> Bool {
        switch self {
        case .root:
            snapshot.schemaVersion != candidate.schemaVersion
                || snapshot.modifiedAt != candidate.modifiedAt
                || snapshot.sessionGeneration != candidate.sessionGeneration
                || snapshot.worldSeed != candidate.worldSeed
                || snapshot.starterSelection != candidate.starterSelection
                || snapshot.corruptionAltarCooldownRemaining != candidate.corruptionAltarCooldownRemaining
        case .journey: snapshot.journey != candidate.journey
        case .roster: snapshot.roster != candidate.roster
        case .inventory: snapshot.inventory != candidate.inventory
        case .homestead: snapshot.homestead != candidate.homestead
        case .spires: snapshot.spires != candidate.spires
        case .labyrinth: snapshot.labyrinth != candidate.labyrinth
        case .contracts: snapshot.contracts != candidate.contracts
        case .voyage: snapshot.voyage != candidate.voyage
        }
    }

    func copy(from source: PlayerSave, into destination: inout PlayerSave) {
        switch self {
        case .root: destination.applyRootFields(from: source)
        case .journey: destination.journey = source.journey
        case .roster: destination.roster = source.roster
        case .inventory: destination.inventory = source.inventory
        case .homestead: destination.homestead = source.homestead
        case .spires: destination.spires = source.spires
        case .labyrinth: destination.labyrinth = source.labyrinth
        case .contracts: destination.contracts = source.contracts
        case .voyage: destination.voyage = source.voyage
        }
    }
}

struct PlayerSaveSlice: OptionSet {
    let rawValue: UInt16

    static let root = PlayerSaveSection.root.slice
    static let journey = PlayerSaveSection.journey.slice
    static let roster = PlayerSaveSection.roster.slice
    static let inventory = PlayerSaveSection.inventory.slice
    static let homestead = PlayerSaveSection.homestead.slice
    static let spires = PlayerSaveSection.spires.slice
    static let labyrinth = PlayerSaveSection.labyrinth.slice
    static let contracts = PlayerSaveSection.contracts.slice
    static let voyage = PlayerSaveSection.voyage.slice
    static let all = PlayerSaveSection.allCases.reduce(into: Self(rawValue: 0)) { $0.insert($1.slice) }

    var sections: [PlayerSaveSection] {
        PlayerSaveSection.allCases.filter { contains($0.slice) }
    }

    static func changed(
        between snapshot: PlayerSave,
        and candidate: PlayerSave,
        within candidates: Self = .all,
    ) -> Self {
        var slices: Self = []
        for section in candidates.sections where section.differs(between: snapshot, and: candidate) {
            slices.insert(section.slice)
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
            voyage: PlayerVoyageState.decodePayload(voyagePayload),
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
        for section in slices.sections {
            switch section {
            case .root:
                schemaVersion = save.schemaVersion
                modifiedAt = save.modifiedAt
                sessionGeneration = save.sessionGeneration
                worldSeed = save.worldSeed
                starterSelectionPhaseRawValue = save.starterSelection.phase.rawValue
                starterHeroID = save.starterSelection.heroID
                corruptionAltarCooldownRemaining = save.corruptionAltarCooldownRemaining
            case .journey:
                let model = journey ?? JourneyProgressModel()
                model.update(from: save.journey, context: context)
                journey = model
                model.root = self
            case .roster:
                let model = roster ?? RosterModel()
                model.update(from: save.roster, context: context)
                roster = model
                model.root = self
            case .inventory:
                let model = inventory ?? InventoryModel()
                model.update(from: save.inventory, context: context)
                inventory = model
                model.root = self
            case .homestead:
                let model = homestead ?? HomesteadModel()
                model.update(from: save.homestead, context: context)
                homestead = model
                model.root = self
            case .spires:
                let model = spires ?? SpiresProgressModel()
                model.update(from: save.spires, context: context)
                spires = model
                model.root = self
            case .labyrinth:
                let model = labyrinth ?? LabyrinthProgressModel()
                model.update(from: save.labyrinth, context: context)
                labyrinth = model
                model.root = self
            case .contracts:
                contractsPayload = save.contracts.encodedPayload
            case .voyage:
                voyagePayload = save.voyage.encodedPayload
            }
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
