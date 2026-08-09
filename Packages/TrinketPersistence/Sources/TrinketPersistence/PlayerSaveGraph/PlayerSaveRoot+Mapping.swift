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
            journey: journey?.toJourneyProgressState() ?? .initial,
            roster: roster?.toPlayerRosterState(inventory: inventoryState) ?? .freshStart,
            inventory: inventoryState,
            homestead: homestead?.toPlayerHomesteadState() ?? .freshStart,
            spires: spires?.toPlayerSpiresState() ?? .freshStart,
            labyrinth: labyrinth?.toPlayerLabyrinthState() ?? .freshStart,
            corruptionAltarCooldownRemaining: corruptionAltarCooldownRemaining
        )
    }
}

extension PlayerSaveRoot {
    func update(from save: PlayerSave, context: ModelContext? = nil) {
        apply(save, slices: .all, context: context)
    }

    func apply(_ save: PlayerSave, slices: PlayerSaveSlice, context: ModelContext? = nil) {
        if slices.contains(.root) {
            schemaVersion = save.schemaVersion
            modifiedAt = save.modifiedAt
            sessionGeneration = save.sessionGeneration
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
