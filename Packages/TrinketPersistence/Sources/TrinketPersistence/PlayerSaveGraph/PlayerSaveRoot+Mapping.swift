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

    func apply(_ save: PlayerSave, slices: PlayerSaveSlice, context: ModelContext) {
        apply(save, slices: slices, context: Optional(context))
    }

    private func apply(_ save: PlayerSave, slices: PlayerSaveSlice, context: ModelContext?) {
        if slices.contains(.root) {
            schemaVersion = save.schemaVersion
            modifiedAt = save.modifiedAt
            sessionGeneration = save.sessionGeneration
            corruptionAltarCooldownRemaining = save.corruptionAltarCooldownRemaining
        }

        if slices.contains(.journey) {
            syncChild(\.journey, make: JourneyProgressModel()) {
                $0.update(from: save.journey, context: context)
            } setRoot: {
                $0.root = self
            }
        }

        if slices.contains(.roster) {
            syncChild(\.roster, make: RosterModel()) {
                $0.update(from: save.roster, context: context)
            } setRoot: {
                $0.root = self
            }
        }

        if slices.contains(.inventory) {
            syncChild(\.inventory, make: InventoryModel()) {
                $0.update(from: save.inventory, context: context)
            } setRoot: {
                $0.root = self
            }
        }

        if slices.contains(.homestead) {
            syncChild(\.homestead, make: HomesteadModel()) {
                $0.update(from: save.homestead, context: context)
            } setRoot: {
                $0.root = self
            }
        }

        if slices.contains(.spires) {
            syncChild(\.spires, make: SpiresProgressModel()) {
                $0.update(from: save.spires, context: context)
            } setRoot: {
                $0.root = self
            }
        }

        if slices.contains(.labyrinth) {
            syncChild(\.labyrinth, make: LabyrinthProgressModel()) {
                $0.update(from: save.labyrinth)
            } setRoot: {
                $0.root = self
            }
        }
    }

    private func syncChild<Model: AnyObject>(
        _ keyPath: ReferenceWritableKeyPath<PlayerSaveRoot, Model?>,
        make: @autoclosure @escaping () -> Model,
        update: (Model) -> Void,
        setRoot: (Model) -> Void
    ) {
        let model = self[keyPath: keyPath] ?? make()
        update(model)
        self[keyPath: keyPath] = model
        setRoot(model)
    }
}
