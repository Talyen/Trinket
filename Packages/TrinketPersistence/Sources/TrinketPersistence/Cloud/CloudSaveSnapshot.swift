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
            corruptionAltarCooldownRemaining: corruptionAltarCooldownRemaining,
        )
        guard !labyrinth.isMapPayloadUnreadable else { throw CloudSaveError.unsupportedSave }
        return try PlayerSaveSanitizer.sanitizeAndValidate(save)
    }

    /// Fresh-install tie-break input: whether either side holds real player
    /// progress. Contracts offers are excluded deliberately (regenerable
    /// board state, not progress); talents are included (spent points).
    var hasProgress: Bool {
        starterSelection.phase != .chooseHero
            || !journey.completedStageIDs.isEmpty
            || !inventory.isEmpty
            || !homestead.nodeTiers.isEmpty
            || roster.gold > 0
            || !roster.unlockedTalents.isEmpty
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

    private enum CodingKeys: String, CodingKey {
        case id, templateID, baseTypeID, rarity, displayName, affixes, isCorrupted, affixPowers
    }

    struct Affix: Codable, Equatable, Sendable {
        let id: String
        let title: String
        let description: String
        let keywords: Set<Keyword>
        let isCorrupted: Bool

        init(id: String, title: String, description: String, keywords: Set<Keyword>, isCorrupted: Bool) {
            self.id = id
            self.title = title
            self.description = description
            self.keywords = keywords
            self.isCorrupted = isCorrupted
        }

        private enum CodingKeys: String, CodingKey {
            case id, title, description, keywords, isCorrupted
        }

        /// Lossy keyword decode: removed keywords are stripped instead of
        /// failing the whole cloud snapshot (see `ItemResolution`).
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            title = try container.decode(String.self, forKey: .title)
            description = try container.decode(String.self, forKey: .description)
            keywords = try ItemResolution.decodeKeywordSet(from: container, forKey: .keywords)
            isCorrupted = try container.decode(Bool.self, forKey: .isCorrupted)
        }
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

    /// Lossy rarity decode matching `ItemResolution`: an unknown rarity string
    /// falls back to `.basic` instead of failing the whole cloud snapshot.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        templateID = try container.decode(String.self, forKey: .templateID)
        baseTypeID = try container.decode(String.self, forKey: .baseTypeID)
        let rarityRawValue = try container.decode(String.self, forKey: .rarity)
        rarity = ItemResolution.rarity(matching: rarityRawValue)
        displayName = try container.decode(String.self, forKey: .displayName)
        affixes = try container.decode([Affix].self, forKey: .affixes)
        isCorrupted = try container.decode(Bool.self, forKey: .isCorrupted)
        affixPowers = try container.decodeIfPresent([ItemAffixPower].self, forKey: .affixPowers)
    }

    /// Non-throwing by design: an unknown base drops the item (nil + log),
    /// matching the local SwiftData codec, instead of rejecting the whole
    /// cloud snapshot for one sunset item family.
    func restored() -> InventoryItem? {
        guard let base = ItemResolution.baseType(matching: baseTypeID, itemID: id) else { return nil }
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
