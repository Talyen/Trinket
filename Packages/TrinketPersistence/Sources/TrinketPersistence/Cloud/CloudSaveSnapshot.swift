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
        corruptionAltarCooldownRemaining = save.corruptionAltarCooldownRemaining
    }

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
            inventory: PlayerInventoryState(items: inventory.map { try $0.restored() }),
            homestead: homestead,
            spires: spires,
            labyrinth: labyrinth,
            contracts: contracts,
            corruptionAltarCooldownRemaining: corruptionAltarCooldownRemaining,
        )
        guard !labyrinth.isMapPayloadUnreadable else { throw CloudSaveError.unsupportedSave }
        let sanitized = PlayerSaveSanitizer.sanitize(save)
        try PlayerSaveSanitizer.validate(sanitized)
        return sanitized
    }

    var hasProgress: Bool {
        starterSelection.phase != .chooseHero
            || !journey.completedStageIDs.isEmpty
            || !inventory.isEmpty
            || !homestead.nodeTiers.isEmpty
            || roster.gold > 0
            || labyrinth.hasEntered
            || !spires.highestClearedFloorBySpireID.isEmpty
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

struct CloudItemSnapshot: Codable, Equatable, Sendable {
    let id: String
    let templateID: String
    let baseTypeID: String
    let rarity: Rarity
    let displayName: String
    let affixes: [Affix]
    let isCorrupted: Bool
    let affixPowers: [ItemAffixPower]?

    struct Affix: Codable, Equatable, Sendable {
        let id: String
        let title: String
        let description: String
        let keywords: Set<Keyword>
        let isCorrupted: Bool
    }

    init(_ item: InventoryItem) {
        id = item.id
        templateID = item.templateID
        baseTypeID = item.baseType.id
        rarity = item.rarity
        displayName = item.displayName
        affixes = item.affixes.map {
            Affix(
                id: $0.id,
                title: $0.title,
                description: $0.description,
                keywords: $0.keywords,
                isCorrupted: $0.isCorrupted,
            )
        }
        isCorrupted = item.isCorrupted
        affixPowers = item.affixPowers
    }

    func restored() throws -> InventoryItem {
        guard let base = GameContent.itemBaseType(matching: baseTypeID) else { throw CloudSaveError.unsupportedSave }
        return InventoryItem(
            id: id,
            templateID: templateID,
            baseType: base,
            rarity: rarity,
            displayName: displayName,
            affixes: affixes.map {
                ItemAffix(
                    id: $0.id,
                    title: $0.title,
                    description: $0.description,
                    keywords: $0.keywords,
                    isCorrupted: $0.isCorrupted,
                )
            },
            isCorrupted: isCorrupted,
            affixPowers: affixPowers,
        )
    }
}
