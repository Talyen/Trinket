import SwiftData
import TrinketCore

extension PlayerSaveRoot {
    package convenience init(save: PlayerSave, id: String = "primary") throws {
        self.init(id: id)
        try update(from: save)
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
    func update(from save: PlayerSave, context: ModelContext? = nil) throws {
        try apply(PlayerSaveGraphWrite(save: save, slices: .all), context: context)
    }

    func apply(_ write: PlayerSaveGraphWrite, context: ModelContext? = nil) {
        let save = write.save
        for section in write.slices.sections {
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
                model.update(from: save.inventory, powerPayloads: write.itemPowerPayloads, context: context)
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
                model.apply(save.labyrinth, payload: write.labyrinthPayload, preservingPayload: write.preservesLabyrinthPayload)
                labyrinth = model
                model.root = self
            case .contracts:
                contractsPayload = write.contractsPayload
            case .voyage:
                voyagePayload = write.voyagePayload
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
