import Foundation
import TrinketContent
import TrinketCore

struct PlayerSaveSnapshot: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var modifiedAt: Date
    var worldSeed: UInt64
    var starterSelection: StarterSelectionState
    var journey: JourneyProgressState
    var roster: StoredRosterSnapshot
    var inventory: [StoredInventoryItem]
    var homestead: PlayerHomesteadState
    var spires: PlayerSpiresState
    var labyrinth: PlayerLabyrinthState
    var voyagePayload: Data?
    var library: PlayerLibraryState?
    var contracts: PlayerContractsState
    var corruptionAltarCooldownRemaining: Int

    init(_ save: PlayerSave) {
        library = save.library
        schemaVersion = save.schemaVersion
        modifiedAt = save.modifiedAt
        worldSeed = save.worldSeed
        starterSelection = save.starterSelection
        journey = save.journey
        roster = StoredRosterSnapshot(save.roster)
        inventory = save.inventory.items.map(StoredInventoryItem.init)
        homestead = save.homestead
        spires = save.spires
        labyrinth = save.labyrinth
        contracts = save.contracts
        voyagePayload = save.voyage.encodedPayload
        corruptionAltarCooldownRemaining = save.corruptionAltarCooldownRemaining
    }

    /// Decode storage values without applying cloud admission policy. Local
    /// startup owns repair, including regeneration of an unreadable Labyrinth.
    func decodedSave() throws -> PlayerSave {
        guard PlayerSave.supportedSchemaVersions.contains(schemaVersion), modifiedAt.timeIntervalSince1970.isFinite else {
            throw PlayerSavePersistenceError.invalidSave("Unsupported save snapshot.")
        }
        return PlayerSave(
            schemaVersion: PlayerSave.currentSchemaVersion,
            modifiedAt: modifiedAt,
            worldSeed: worldSeed,
            starterSelection: starterSelection,
            journey: journey,
            roster: roster.restored(),
            inventory: PlayerInventoryState(items: inventory.compactMap { $0.resolved() }),
            homestead: homestead,
            spires: spires,
            labyrinth: labyrinth,
            contracts: contracts,
            voyage: PlayerVoyageState.decodePayload(voyagePayload),
            corruptionAltarCooldownRemaining: corruptionAltarCooldownRemaining,
            library: library ?? .init(),
        )
    }
}

struct StoredRosterSnapshot: Codable, Equatable, Sendable {
    var activeHeroID: String
    var activeCompanionID: String
    var unlockedHeroIDs: Set<String>
    var unlockedCompanionIDs: Set<String>
    var abilityLoadouts: [String: RosterHydration.AbilityLoadoutIDs]
    var progressions: [String: CombatantProgression]
    var equipment: [String: [String: String]]
    var unlockedTalents: [String: Set<String>]
    var gold: Int

    init(_ roster: PlayerRosterState) {
        activeHeroID = roster.activeHeroID
        activeCompanionID = roster.activeCompanionID
        unlockedHeroIDs = roster.unlockedHeroIDs
        unlockedCompanionIDs = roster.unlockedCompanionIDs
        abilityLoadouts = roster.abilityLoadouts.mapValues {
            .init(basicID: $0.basic?.id, skillID: $0.skill?.id, ultimateID: $0.ultimate?.id)
        }
        progressions = roster.progressions
        equipment = roster.equipmentLoadouts.mapValues {
            Dictionary(uniqueKeysWithValues: $0.itemIDsBySlot.lazy.map { ($0.key.rawValue, $0.value) })
        }
        unlockedTalents = roster.unlockedTalents
        gold = roster.gold
    }

    func restored() -> PlayerRosterState {
        PlayerRosterState(
            activeHeroID: activeHeroID,
            activeCompanionID: activeCompanionID,
            unlockedHeroIDs: unlockedHeroIDs,
            unlockedCompanionIDs: unlockedCompanionIDs,
            abilityLoadouts: RosterHydration.rawAbilityLoadouts(from: abilityLoadouts),
            progressions: progressions,
            equipmentLoadouts: equipment.mapValues { slots in
                EquipmentLoadout(itemIDsBySlot: Dictionary(uniqueKeysWithValues: slots.lazy.compactMap { key, value in
                    ItemSlot(rawValue: key).map { ($0, value) }
                }))
            },
            unlockedTalents: unlockedTalents,
            gold: gold,
        )
    }
}
