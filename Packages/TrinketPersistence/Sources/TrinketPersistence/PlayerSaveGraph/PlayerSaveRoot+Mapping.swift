import SwiftData
import TrinketCore

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
