import SwiftData
@testable import TrinketPersistence

/// Copies a rich fixture into the distributed model types before insertion.
/// Current model instances cannot be inserted into a frozen schema's container.
@MainActor
enum LegacySaveGraphFixture {
    private typealias Legacy = PlayerSaveSchemaV3

    static func root(from save: PlayerSave) throws -> PlayerSaveSchemaV3.PlayerSaveRoot {
        // Register current model relationships before copying into the frozen schema.
        let schema = PlayerSaveGraph.schema
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none),
        )
        let context = ModelContext(container)
        let source = PlayerSaveRoot()
        context.insert(source)
        try source.update(from: save, context: context)
        let root = Legacy.PlayerSaveRoot(id: source.id)
        root.schemaVersion = 18
        root.modifiedAt = source.modifiedAt
        root.sessionGeneration = source.sessionGeneration
        root.worldSeed = source.worldSeed
        root.starterSelectionPhaseRawValue = source.starterSelectionPhaseRawValue
        root.starterHeroID = source.starterHeroID
        root.corruptionAltarCooldownRemaining = source.corruptionAltarCooldownRemaining
        root.contractsPayload = source.contractsPayload
        root.voyagePayload = source.voyagePayload
        root.cloudStatePayload = source.cloudStatePayload
        root.journey = source.journey.map(journey)
        root.roster = source.roster.map(roster)
        root.inventory = source.inventory.map(inventory)
        root.homestead = source.homestead.map(homestead)
        root.spires = source.spires.map(spires)
        root.labyrinth = source.labyrinth.map(labyrinth)
        return root
    }

    private static func journey(_ source: JourneyProgressModel) -> Legacy.JourneyProgressModel {
        let model = Legacy.JourneyProgressModel()
        model.activeChapterID = source.activeChapterID
        model.activeStageID = source.activeStageID
        model.stages = source.stages?.map { source in
            let stage = Legacy.JourneyStageProgressModel(
                stageID: source.stageID, isCompleted: source.isCompleted,
                rewardsClaimed: source.rewardsClaimed, mysteryEventID: source.mysteryEventID,
            )
            stage.mysteryOffersPayload = source.mysteryOffersPayload
            stage.shopPayload = source.shopPayload
            return stage
        }
        return model
    }

    private static func roster(_ source: RosterModel) -> Legacy.RosterModel {
        let model = Legacy.RosterModel()
        model.activeHeroID = source.activeHeroID
        model.activeCompanionID = source.activeCompanionID
        model.gold = source.gold
        model.unlockedCombatants = source.unlockedCombatants?.map {
            Legacy.UnlockedCombatantModel(combatantID: $0.combatantID, role: $0.role)
        }
        model.progressions = source.progressions?.map { source in
            let progression = Legacy.CombatantProgressionModel(combatantID: source.combatantID)
            progression.level = source.level
            progression.currentXP = source.currentXP
            progression.requiredXP = source.requiredXP
            return progression
        }
        model.abilityLoadouts = source.abilityLoadouts?.map { source in
            let loadout = Legacy.AbilityLoadoutModel(combatantID: source.combatantID)
            loadout.basicID = source.basicID
            loadout.skillID = source.skillID
            loadout.ultimateID = source.ultimateID
            return loadout
        }
        model.equipmentLoadouts = source.equipmentLoadouts?.map { source in
            let loadout = Legacy.EquipmentLoadoutModel(combatantID: source.combatantID)
            loadout.slots = source.slots?.map { Legacy.EquipmentSlotModel(slotID: $0.slotID, itemID: $0.itemID) }
            return loadout
        }
        model.talentLoadouts = source.talentLoadouts?.map { source in
            let loadout = Legacy.TalentLoadoutModel(combatantID: source.combatantID)
            loadout.unlockedNodes = source.unlockedNodes?.map { Legacy.TalentNodeUnlockModel(nodeID: $0.nodeID) }
            return loadout
        }
        return model
    }

    private static func inventory(_ source: InventoryModel) -> Legacy.InventoryModel {
        let model = Legacy.InventoryModel()
        model.items = source.items?.map { source in
            let item = Legacy.InventoryItemModel()
            item.id = source.id
            item.templateID = source.templateID
            item.baseTypeID = source.baseTypeID
            item.rarityID = source.rarityID
            item.displayName = source.displayName
            item.sortIndex = source.sortIndex
            item.isCorrupted = source.isCorrupted
            item.affixPowersJSON = source.affixPowersJSON
            item.affixes = source.affixes?.map { source in
                let affix = Legacy.ItemAffixModel()
                affix.id = source.id
                affix.title = source.title
                affix.affixDescription = source.affixDescription
                affix.keywordRawValues = source.keywordRawValues
                affix.isCorrupted = source.isCorrupted
                affix.sortIndex = source.sortIndex
                return affix
            }
            return item
        }
        return model
    }

    private static func homestead(_ source: HomesteadModel) -> Legacy.HomesteadModel {
        let model = Legacy.HomesteadModel()
        model.lastProductionAt = source.lastProductionAt
        model.goldRewardRemainder = source.goldRewardRemainder
        model.gemsRewardRemainder = source.gemsRewardRemainder
        model.resources = source.resources?.map { Legacy.HomesteadResourceBalanceModel(resourceID: $0.resourceID, quantity: $0.quantity) }
        model.pendingProduction = source.pendingProduction?.map {
            Legacy.HomesteadPendingProductionModel(resourceID: $0.resourceID, quantity: $0.quantity)
        }
        model.nodeTiers = source.nodeTiers?.map { Legacy.HomesteadNodeTierModel(nodeID: $0.nodeID, tier: $0.tier) }
        return model
    }

    private static func spires(_ source: SpiresProgressModel) -> Legacy.SpiresProgressModel {
        let model = Legacy.SpiresProgressModel()
        model.floors = source.floors?
            .map { Legacy.SpireFloorProgressModel(spireID: $0.spireID, highestClearedFloor: $0.highestClearedFloor) }
        return model
    }

    private static func labyrinth(_ source: LabyrinthProgressModel) -> Legacy.LabyrinthProgressModel {
        let model = Legacy.LabyrinthProgressModel()
        model.worldSeed = source.worldSeed
        model.mapVersion = source.mapVersion
        model.hasEntered = source.hasEntered
        model.mapPayload = source.mapPayload
        return model
    }
}
