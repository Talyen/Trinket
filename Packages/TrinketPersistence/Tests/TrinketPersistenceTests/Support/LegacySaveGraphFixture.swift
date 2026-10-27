import SwiftData
@testable import TrinketPersistence

/// Copies a rich fixture into the distributed model types.
/// Current model instances cannot be inserted into a frozen schema's container.
@MainActor
enum LegacySaveGraphFixture {
    private typealias Legacy = PlayerSaveSchemaV3

    static func root(from save: PlayerSave, in legacyContext: ModelContext) throws -> PlayerSaveSchemaV3.PlayerSaveRoot {
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
        legacyContext.insert(root)
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
        root.journey = source.journey.map { journey($0, in: legacyContext) }
        root.roster = source.roster.map { roster($0, in: legacyContext) }
        root.inventory = source.inventory.map { inventory($0, in: legacyContext) }
        root.homestead = source.homestead.map { homestead($0, in: legacyContext) }
        root.spires = source.spires.map { spires($0, in: legacyContext) }
        root.labyrinth = source.labyrinth.map { inserted(labyrinth($0), in: legacyContext) }
        return root
    }

    private static func journey(_ source: JourneyProgressModel, in context: ModelContext) -> Legacy.JourneyProgressModel {
        let model = Legacy.JourneyProgressModel()
        context.insert(model)
        model.activeChapterID = source.activeChapterID
        model.activeStageID = source.activeStageID
        model.stages = source.stages?.map { source in
            let stage = Legacy.JourneyStageProgressModel(
                stageID: source.stageID, isCompleted: source.isCompleted,
                rewardsClaimed: source.rewardsClaimed, mysteryEventID: source.mysteryEventID,
            )
            context.insert(stage)
            stage.mysteryOffersPayload = source.mysteryOffersPayload
            stage.shopPayload = source.shopPayload
            return stage
        }
        return model
    }

    private static func roster(_ source: RosterModel, in context: ModelContext) -> Legacy.RosterModel {
        let model = Legacy.RosterModel()
        context.insert(model)
        model.activeHeroID = source.activeHeroID
        model.activeCompanionID = source.activeCompanionID
        model.gold = source.gold
        model.unlockedCombatants = source.unlockedCombatants?.map {
            inserted(Legacy.UnlockedCombatantModel(combatantID: $0.combatantID, role: $0.role), in: context)
        }
        model.progressions = source.progressions?.map { source in
            let progression = Legacy.CombatantProgressionModel(combatantID: source.combatantID)
            context.insert(progression)
            progression.level = source.level
            progression.currentXP = source.currentXP
            progression.requiredXP = source.requiredXP
            return progression
        }
        model.abilityLoadouts = source.abilityLoadouts?.map { source in
            let loadout = Legacy.AbilityLoadoutModel(combatantID: source.combatantID)
            context.insert(loadout)
            loadout.basicID = source.basicID
            loadout.skillID = source.skillID
            loadout.ultimateID = source.ultimateID
            return loadout
        }
        model.equipmentLoadouts = source.equipmentLoadouts?.map { source in
            let loadout = Legacy.EquipmentLoadoutModel(combatantID: source.combatantID)
            context.insert(loadout)
            loadout.slots = source.slots?.map {
                inserted(Legacy.EquipmentSlotModel(slotID: $0.slotID, itemID: $0.itemID), in: context)
            }
            return loadout
        }
        model.talentLoadouts = source.talentLoadouts?.map { source in
            let loadout = Legacy.TalentLoadoutModel(combatantID: source.combatantID)
            context.insert(loadout)
            loadout.unlockedNodes = source.unlockedNodes?.map {
                inserted(Legacy.TalentNodeUnlockModel(nodeID: $0.nodeID), in: context)
            }
            return loadout
        }
        return model
    }

    private static func inventory(_ source: InventoryModel, in context: ModelContext) -> Legacy.InventoryModel {
        let model = Legacy.InventoryModel()
        context.insert(model)
        model.items = source.items?.map { source in
            let item = Legacy.InventoryItemModel()
            context.insert(item)
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
                context.insert(affix)
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

    private static func homestead(_ source: HomesteadModel, in context: ModelContext) -> Legacy.HomesteadModel {
        let model = Legacy.HomesteadModel()
        context.insert(model)
        model.lastProductionAt = source.lastProductionAt
        model.goldRewardRemainder = source.goldRewardRemainder
        model.gemsRewardRemainder = source.gemsRewardRemainder
        model.resources = source.resources?.map {
            inserted(Legacy.HomesteadResourceBalanceModel(resourceID: $0.resourceID, quantity: $0.quantity), in: context)
        }
        model.pendingProduction = source.pendingProduction?.map {
            inserted(Legacy.HomesteadPendingProductionModel(resourceID: $0.resourceID, quantity: $0.quantity), in: context)
        }
        model.nodeTiers = source.nodeTiers?.map {
            inserted(Legacy.HomesteadNodeTierModel(nodeID: $0.nodeID, tier: $0.tier), in: context)
        }
        return model
    }

    private static func spires(_ source: SpiresProgressModel, in context: ModelContext) -> Legacy.SpiresProgressModel {
        let model = Legacy.SpiresProgressModel()
        context.insert(model)
        model.floors = source.floors?
            .map { inserted(Legacy.SpireFloorProgressModel(spireID: $0.spireID, highestClearedFloor: $0.highestClearedFloor), in: context) }
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

    private static func inserted<Model: PersistentModel>(_ model: Model, in context: ModelContext) -> Model {
        context.insert(model)
        return model
    }
}
