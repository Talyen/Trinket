import Foundation
import SwiftData
import TrinketCore

struct PlayerSaveSlice: OptionSet {
    let rawValue: UInt8

    static let root = Self(rawValue: 1 << 0)
    static let journey = Self(rawValue: 1 << 1)
    static let roster = Self(rawValue: 1 << 2)
    static let inventory = Self(rawValue: 1 << 3)
    static let homestead = Self(rawValue: 1 << 4)
    static let spires = Self(rawValue: 1 << 5)
    static let labyrinth = Self(rawValue: 1 << 6)
    static let all: Self = [.root, .journey, .roster, .inventory, .homestead, .spires, .labyrinth]

    static func changed(between snapshot: PlayerSave, and candidate: PlayerSave) -> Self {
        var slices: Self = []
        if snapshot.schemaVersion != candidate.schemaVersion
            || snapshot.modifiedAt != candidate.modifiedAt
            || snapshot.sessionGeneration != candidate.sessionGeneration
            || snapshot.worldSeed != candidate.worldSeed
            || snapshot.starterSelection != candidate.starterSelection
            || snapshot.corruptionAltarCooldownRemaining != candidate.corruptionAltarCooldownRemaining {
            slices.insert(.root)
        }
        if snapshot.journey != candidate.journey {
            slices.insert(.journey)
        }
        if snapshot.roster != candidate.roster {
            slices.insert(.roster)
        }
        if snapshot.inventory != candidate.inventory {
            slices.insert(.inventory)
        }
        if snapshot.homestead != candidate.homestead {
            slices.insert(.homestead)
        }
        if snapshot.spires != candidate.spires {
            slices.insert(.spires)
        }
        if snapshot.labyrinth != candidate.labyrinth {
            slices.insert(.labyrinth)
        }
        return slices
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
            journey: journey?.toJourneyProgressState() ?? .initial,
            roster: roster?.toPlayerRosterState(
                inventory: inventoryState,
                schemaVersion: schemaVersion
            ) ?? .freshStart,
            inventory: inventoryState,
            homestead: homestead?.toPlayerHomesteadState() ?? .freshStart,
            spires: spires?.toPlayerSpiresState() ?? .freshStart,
            labyrinth: labyrinth?.toPlayerLabyrinthState() ?? .freshStart,
            corruptionAltarCooldownRemaining: corruptionAltarCooldownRemaining
        )
    }
}

extension PlayerSaveRoot {
    func repairSlices(for sanitizedSave: PlayerSave) -> PlayerSaveSlice {
        var slices = PlayerSaveSlice.changed(between: toPlayerSave(), and: sanitizedSave)

        if journey == nil || hasDuplicateKeys(journey?.stages ?? [], key: \.stageID) {
            slices.insert(.journey)
        }
        if roster == nil || rosterHasDuplicateChildren {
            slices.insert(.roster)
        }
        if inventory == nil || inventoryHasDuplicateChildren {
            slices.insert(.inventory)
        }
        if homestead == nil || homesteadHasDuplicateChildren {
            slices.insert(.homestead)
        }
        if spires == nil || hasDuplicateKeys(spires?.floors ?? [], key: \.spireID) {
            slices.insert(.spires)
        }
        if labyrinth == nil {
            slices.insert(.labyrinth)
        }
        return slices
    }

    private var rosterHasDuplicateChildren: Bool {
        guard let roster else { return false }
        return hasDuplicateKeys(roster.unlockedCombatants ?? []) { "\($0.role):\($0.combatantID)" }
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
            model.update(from: save.labyrinth)
            labyrinth = model
            model.root = self
        }
    }
}

private extension PlayerSaveRoot {
    var mappedStarterSelection: StarterSelectionState {
        guard schemaVersion >= PlayerSave.Schema.persistedStarterSelection else { return .complete }
        guard let phase = StarterSelectionPhase(rawValue: starterSelectionPhaseRawValue) else {
            return .fresh
        }
        return StarterSelectionState(phase: phase, heroID: starterHeroID)
    }
}

private func hasDuplicateKeys<Element, Key: Hashable>(
    _ values: [Element],
    key: (Element) -> Key
) -> Bool {
    var seen: Set<Key> = []
    return values.contains { !seen.insert(key($0)).inserted }
}
