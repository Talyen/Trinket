import Foundation
import SwiftData
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

/// Builds only frozen model types; registering a current graph alongside the
/// legacy container can replace SwiftData metadata on iOS 18.
@MainActor
enum LegacySaveGraphFixture {
    private typealias Legacy = PlayerSaveSchemaV3

    static func root(from save: PlayerSave, in legacyContext: ModelContext) throws -> PlayerSaveSchemaV3.PlayerSaveRoot {
        let write = try PlayerSaveGraphWrite(save: save, slices: .all)
        let root = Legacy.PlayerSaveRoot()
        legacyContext.insert(root)
        root.schemaVersion = 18
        root.modifiedAt = save.modifiedAt
        root.sessionGeneration = save.sessionGeneration
        root.worldSeed = save.worldSeed
        root.starterSelectionPhaseRawValue = save.starterSelection.phase.rawValue
        root.starterHeroID = save.starterSelection.heroID
        root.corruptionAltarCooldownRemaining = save.corruptionAltarCooldownRemaining
        root.contractsPayload = write.contractsPayload
        root.voyagePayload = write.voyagePayload
        root.journey = journey(save.journey, in: legacyContext)
        root.roster = roster(save.roster, in: legacyContext)
        root.inventory = inventory(save.inventory, powers: write.itemPowerPayloads, in: legacyContext)
        root.homestead = homestead(save.homestead, in: legacyContext)
        root.spires = spires(save.spires, in: legacyContext)
        let labyrinth = inserted(Legacy.LabyrinthProgressModel(), in: legacyContext)
        labyrinth.worldSeed = save.labyrinth.worldSeed
        labyrinth.mapVersion = save.labyrinth.mapVersion
        labyrinth.hasEntered = save.labyrinth.hasEntered
        if case let .replace(payload) = write.labyrinthPayload {
            labyrinth.mapPayload = payload
        }
        root.labyrinth = labyrinth
        return root
    }

    private static func journey(_ source: JourneyProgressState, in context: ModelContext) -> Legacy.JourneyProgressModel {
        let model = Legacy.JourneyProgressModel()
        context.insert(model)
        model.activeChapterID = source.activeChapterID
        model.activeStageID = source.activeStageID
        let stageIDs = source.completedStageIDs.union(source.claimedRewardStageIDs)
            .union(source.pinnedMysteryEventIDs.keys).union(source.mysteryOfferPayloads.keys).union(source.shopPayloads.keys)
        model.stages = stageIDs.sorted().map { id in
            let stage = Legacy.JourneyStageProgressModel(
                stageID: id, isCompleted: source.completedStageIDs.contains(id),
                rewardsClaimed: source.claimedRewardStageIDs.contains(id), mysteryEventID: source.pinnedMysteryEventIDs[id],
            )
            context.insert(stage)
            stage.mysteryOffersPayload = source.mysteryOfferPayloads[id]
            stage.shopPayload = source.shopPayloads[id]
            return stage
        }
        return model
    }

    private static func roster(_ source: PlayerRosterState, in context: ModelContext) -> Legacy.RosterModel {
        let model = Legacy.RosterModel()
        context.insert(model)
        model.activeHeroID = source.activeHeroID
        model.activeCompanionID = source.activeCompanionID
        model.gold = source.gold
        model.unlockedCombatants = source.unlockedHeroIDs.sorted().map {
            inserted(Legacy.UnlockedCombatantModel(combatantID: $0, role: "hero"), in: context)
        } + source.unlockedCompanionIDs.sorted().map {
            inserted(Legacy.UnlockedCombatantModel(combatantID: $0, role: "companion"), in: context)
        }
        model.progressions = source.progressions.sorted { $0.key < $1.key }.map { id, value in
            let progression = inserted(Legacy.CombatantProgressionModel(combatantID: id), in: context)
            progression.level = value.level
            progression.currentXP = value.currentXP
            progression.requiredXP = value.requiredXP
            return progression
        }
        model.abilityLoadouts = source.abilityLoadouts.sorted { $0.key < $1.key }.map { id, value in
            let loadout = inserted(Legacy.AbilityLoadoutModel(combatantID: id), in: context)
            loadout.basicID = value.basic?.id
            loadout.skillID = value.skill?.id
            loadout.ultimateID = value.ultimate?.id
            return loadout
        }
        model.equipmentLoadouts = source.equipmentLoadouts.sorted { $0.key < $1.key }.map { id, value in
            let loadout = inserted(Legacy.EquipmentLoadoutModel(combatantID: id), in: context)
            loadout.slots = value.itemIDsBySlot.sorted { $0.key.rawValue < $1.key.rawValue }.map {
                inserted(Legacy.EquipmentSlotModel(slotID: $0.key.rawValue, itemID: $0.value), in: context)
            }
            return loadout
        }
        model.talentLoadouts = source.unlockedTalents.sorted { $0.key < $1.key }.map { id, value in
            let loadout = inserted(Legacy.TalentLoadoutModel(combatantID: id), in: context)
            loadout.unlockedNodes = value.sorted().map {
                inserted(Legacy.TalentNodeUnlockModel(nodeID: $0), in: context)
            }
            return loadout
        }
        return model
    }

    private static func inventory(
        _ source: PlayerInventoryState, powers: [String: Data], in context: ModelContext,
    ) -> Legacy.InventoryModel {
        let model = Legacy.InventoryModel()
        context.insert(model)
        model.items = source.items.enumerated().map { index, source in
            let item = Legacy.InventoryItemModel()
            context.insert(item)
            item.id = source.id
            item.templateID = source.templateID
            item.baseTypeID = source.baseType.id
            item.rarityID = source.rarity.rawValue
            item.displayName = source.displayName
            item.sortIndex = index
            item.isCorrupted = source.isCorrupted
            item.affixPowersJSON = powers[source.id]
            item.affixes = source.affixes.enumerated().map { index, source in
                let affix = Legacy.ItemAffixModel()
                context.insert(affix)
                affix.id = source.id
                affix.title = source.title
                affix.affixDescription = source.description
                affix.keywordRawValues = source.keywords.map(\.rawValue).sorted()
                affix.isCorrupted = source.isCorrupted
                affix.sortIndex = index
                return affix
            }
            return item
        }
        return model
    }

    private static func homestead(_ source: PlayerHomesteadState, in context: ModelContext) -> Legacy.HomesteadModel {
        let model = Legacy.HomesteadModel()
        context.insert(model)
        model.lastProductionAt = source.lastProductionAt
        model.goldRewardRemainder = source.rewardRemainders?.gold ?? 0
        model.gemsRewardRemainder = source.rewardRemainders?.gems ?? 0
        model.resources = source.resources.sorted { $0.key.rawValue < $1.key.rawValue }.map {
            inserted(Legacy.HomesteadResourceBalanceModel(resourceID: $0.key.rawValue, quantity: $0.value), in: context)
        }
        model.pendingProduction = source.validPendingProduction.sorted { $0.key.rawValue < $1.key.rawValue }.map {
            inserted(Legacy.HomesteadPendingProductionModel(resourceID: $0.key.rawValue, quantity: $0.value), in: context)
        }
        model.nodeTiers = source.nodeTiers.sorted { $0.key.rawValue < $1.key.rawValue }.map {
            inserted(Legacy.HomesteadNodeTierModel(nodeID: $0.key.rawValue, tier: $0.value), in: context)
        }
        return model
    }

    private static func spires(_ source: PlayerSpiresState, in context: ModelContext) -> Legacy.SpiresProgressModel {
        let model = Legacy.SpiresProgressModel()
        context.insert(model)
        model.floors = source.highestClearedFloorBySpireID.sorted { $0.key < $1.key }.map { id, floor in
            inserted(Legacy.SpireFloorProgressModel(spireID: id, highestClearedFloor: max(0, floor)), in: context)
        }
        return model
    }

    private static func inserted<Model: PersistentModel>(_ model: Model, in context: ModelContext) -> Model {
        context.insert(model)
        return model
    }
}
