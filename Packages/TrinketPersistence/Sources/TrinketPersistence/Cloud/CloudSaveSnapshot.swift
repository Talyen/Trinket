import Foundation
import TrinketContent
import TrinketCore

struct CloudSaveSnapshot: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let modifiedAt: Date
    let worldSeed: UInt64
    let starterSelection: StarterSelectionState
    let journey: JourneyProgressState
    let roster: CloudRosterSnapshot
    let inventory: [CloudItemSnapshot]
    let homestead: PlayerHomesteadState
    let spires: PlayerSpiresState
    let labyrinth: PlayerLabyrinthState
    let voyagePayload: Data?
    let contracts: PlayerContractsState
    let corruptionAltarCooldownRemaining: Int

    init(_ save: PlayerSave) {
        schemaVersion = save.schemaVersion
        modifiedAt = save.modifiedAt
        worldSeed = save.worldSeed
        starterSelection = save.starterSelection
        journey = save.journey
        roster = CloudRosterSnapshot(save.roster)
        inventory = save.inventory.items.map(CloudItemSnapshot.init)
        homestead = save.homestead
        spires = save.spires
        labyrinth = save.labyrinth
        contracts = save.contracts
        voyagePayload = save.voyage.encodedPayload
        corruptionAltarCooldownRemaining = save.corruptionAltarCooldownRemaining
    }

    /// Restores a sanitized, validated save. `sessionGeneration` is excluded
    /// from cloud coding by design (local coordination only); every install
    /// path must re-stamp it via `commitCloudState` (which bumps on external
    /// change) or `PendingSaveRecovery.Record.restoredSave`. Never install a
    /// raw `restored()` result without stamping.
    func restored() throws -> PlayerSave {
        guard schemaVersion == PlayerSave.currentSchemaVersion, modifiedAt.timeIntervalSince1970.isFinite else {
            throw CloudSaveError.unsupportedSave
        }
        let save = try PlayerSave(
            schemaVersion: schemaVersion,
            modifiedAt: modifiedAt,
            worldSeed: worldSeed,
            starterSelection: starterSelection,
            journey: journey,
            roster: roster.restored(),
            inventory: PlayerInventoryState(items: inventory.compactMap { $0.restored() }),
            homestead: homestead,
            spires: spires,
            labyrinth: labyrinth,
            contracts: contracts,
            voyage: PlayerVoyageState.decodePayload(voyagePayload),
            corruptionAltarCooldownRemaining: corruptionAltarCooldownRemaining,
        )
        guard !labyrinth.isMapPayloadUnreadable else { throw CloudSaveError.unsupportedSave }
        return try PlayerSaveSanitizer.sanitizeAndValidate(save)
    }

    /// Fresh-install tie-break input: whether either side holds real player
    /// progress. Contracts offers are excluded deliberately (regenerable
    /// board state, not progress); talents are included (spent points).
    var hasProgress: Bool {
        if starterSelection.phase != .chooseHero
            || !journey.completedStageIDs.isEmpty
            || !inventory.isEmpty
            || !homestead.nodeTiers.isEmpty
            || roster.gold > 0
            || !roster.unlockedTalents.isEmpty
            || labyrinth.hasEntered
            || !spires.highestClearedFloorBySpireID.isEmpty
            || contracts.highestWonEncounterLevel > 0 {
            return true
        }
        let voyage = PlayerVoyageState.decodePayload(voyagePayload)
        return voyage.activeRun != nil || voyage.isUnreadable
    }

    var campaignRank: Int {
        GameContent.chapters.flatMap(\.stages).enumerated()
            .filter { journey.completedStageIDs.contains($0.element.id) }
            .map { $0.offset + 1 }.max() ?? 0
    }
}

struct CloudRosterSnapshot: Codable, Equatable, Sendable {
    let activeHeroID: String
    let activeCompanionID: String
    let unlockedHeroIDs: Set<String>
    let unlockedCompanionIDs: Set<String>
    let abilityLoadouts: [String: RosterHydration.AbilityLoadoutIDs]
    let progressions: [String: CombatantProgression]
    let equipment: [String: [String: String]]
    let unlockedTalents: [String: Set<String>]
    let gold: Int

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
            Dictionary(uniqueKeysWithValues: $0.itemIDsBySlot.map { ($0.key.rawValue, $0.value) })
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
                EquipmentLoadout(itemIDsBySlot: Dictionary(uniqueKeysWithValues: slots.compactMap { key, value in
                    ItemSlot(rawValue: key).map { ($0, value) }
                }))
            },
            unlockedTalents: unlockedTalents,
            gold: gold,
        )
    }
}
