import Foundation
import SwiftData
import TrinketContent
import TrinketCore

/// Frozen distributed graph before Library history. Keep every relationship's
/// inverse within this schema; later model edits must not change its checksum.
enum PlayerSaveSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static let models: [any PersistentModel.Type] = [
        PlayerSaveRoot.self,
        HomesteadModel.self,
        HomesteadResourceBalanceModel.self,
        HomesteadPendingProductionModel.self,
        HomesteadNodeTierModel.self,
        InventoryModel.self,
        InventoryItemModel.self,
        ItemAffixModel.self,
        JourneyProgressModel.self,
        JourneyStageProgressModel.self,
        LabyrinthProgressModel.self,
        RosterModel.self,
        TalentLoadoutModel.self,
        TalentNodeUnlockModel.self,
        UnlockedCombatantModel.self,
        CombatantProgressionModel.self,
        AbilityLoadoutModel.self,
        EquipmentLoadoutModel.self,
        EquipmentSlotModel.self,
        SpiresProgressModel.self,
        SpireFloorProgressModel.self,
        CloudOutboxRecord.self,
    ]

    @Model
    final class PlayerSaveRoot {
        var id: String = "primary"
        var schemaVersion: Int = 18
        var modifiedAt: Date = Date()
        var sessionGeneration: UInt64 = 0
        var worldSeed: UInt64 = 0
        var starterSelectionPhaseRawValue: String = StarterSelectionPhase.complete.rawValue
        var starterHeroID: String?
        var corruptionAltarCooldownRemaining: Int = 0
        var contractsPayload: Data?
        var voyagePayload: Data?
        var cloudStatePayload: Data?

        @Relationship(deleteRule: .cascade, inverse: \JourneyProgressModel.root)
        var journey: JourneyProgressModel?
        @Relationship(deleteRule: .cascade, inverse: \RosterModel.root)
        var roster: RosterModel?
        @Relationship(deleteRule: .cascade, inverse: \InventoryModel.root)
        var inventory: InventoryModel?
        @Relationship(deleteRule: .cascade, inverse: \HomesteadModel.root)
        var homestead: HomesteadModel?
        @Relationship(deleteRule: .cascade, inverse: \SpiresProgressModel.root)
        var spires: SpiresProgressModel?
        @Relationship(deleteRule: .cascade, inverse: \LabyrinthProgressModel.root)
        var labyrinth: LabyrinthProgressModel?

        init(id: String = "primary") {
            self.id = id
        }
    }

    @Model
    final class HomesteadModel {
        var root: PlayerSaveRoot?

        @Relationship(deleteRule: .cascade, inverse: \HomesteadResourceBalanceModel.homestead)
        var resources: [HomesteadResourceBalanceModel]?
        @Relationship(deleteRule: .cascade, inverse: \HomesteadPendingProductionModel.homestead)
        var pendingProduction: [HomesteadPendingProductionModel]?
        @Relationship(deleteRule: .cascade, inverse: \HomesteadNodeTierModel.homestead)
        var nodeTiers: [HomesteadNodeTierModel]?
        var lastProductionAt: Date = Date()
        var goldRewardRemainder: Int = 0
        var gemsRewardRemainder: Int = 0

        init() {}
    }

    @Model
    final class HomesteadResourceBalanceModel {
        var resourceID: String = ""
        var quantity: Int = 0
        var homestead: HomesteadModel?

        init(resourceID: String = "", quantity: Int = 0) {
            self.resourceID = resourceID
            self.quantity = quantity
        }
    }

    @Model
    final class HomesteadPendingProductionModel {
        var resourceID: String = ""
        var quantity: Double = 0
        var homestead: HomesteadModel?

        init(resourceID: String = "", quantity: Double = 0) {
            self.resourceID = resourceID
            self.quantity = quantity
        }
    }

    @Model
    final class HomesteadNodeTierModel {
        var nodeID: String = ""
        var tier: Int = 0
        var homestead: HomesteadModel?

        init(nodeID: String = "", tier: Int = 0) {
            self.nodeID = nodeID
            self.tier = tier
        }
    }

    @Model
    final class InventoryModel {
        var root: PlayerSaveRoot?

        @Relationship(deleteRule: .cascade, inverse: \InventoryItemModel.inventory)
        var items: [InventoryItemModel]?

        init() {}
    }

    @Model
    final class InventoryItemModel {
        var id: String = ""
        var templateID: String = ""
        var baseTypeID: String = ""
        var rarityID: String = Rarity.basic.rawValue
        var displayName: String = ""
        var sortIndex: Int = 0
        var isCorrupted: Bool = false
        var affixPowersJSON: Data?
        var inventory: InventoryModel?

        @Relationship(deleteRule: .cascade, inverse: \ItemAffixModel.item)
        var affixes: [ItemAffixModel]?

        init() {}
    }

    @Model
    final class ItemAffixModel {
        var id: String = ""
        var title: String = ""
        var affixDescription: String = ""
        var keywordRawValues: [String] = []
        var isCorrupted: Bool = false
        var sortIndex: Int = 0
        var item: InventoryItemModel?

        init() {}
    }

    @Model
    final class JourneyProgressModel {
        var activeChapterID: String = JourneyProgressState.initial.activeChapterID
        var activeStageID: String?
        var root: PlayerSaveRoot?

        @Relationship(deleteRule: .cascade, inverse: \JourneyStageProgressModel.journey)
        var stages: [JourneyStageProgressModel]?

        init() {}
    }

    @Model
    final class JourneyStageProgressModel {
        var stageID: String = ""
        var isCompleted: Bool = false
        var rewardsClaimed: Bool = false
        var mysteryEventID: String?
        var mysteryOffersPayload: Data?
        var shopPayload: Data?
        var journey: JourneyProgressModel?

        init(
            stageID: String = "",
            isCompleted: Bool = false,
            rewardsClaimed: Bool = false,
            mysteryEventID: String? = nil,
        ) {
            self.stageID = stageID
            self.isCompleted = isCompleted
            self.rewardsClaimed = rewardsClaimed
            self.mysteryEventID = mysteryEventID
        }
    }

    @Model
    final class LabyrinthProgressModel {
        var root: PlayerSaveRoot?
        var worldSeed: UInt64 = 0
        var mapVersion: Int = LabyrinthGenerator.currentMapVersion
        var hasEntered: Bool = false
        var mapPayload: Data?

        init() {}
    }

    @Model
    final class RosterModel {
        var activeHeroID: String = PlayerRosterState.starterHeroID
        var activeCompanionID: String = PlayerRosterState.starterCompanionID
        var gold: Int = 0
        var root: PlayerSaveRoot?

        @Relationship(deleteRule: .cascade, inverse: \UnlockedCombatantModel.roster)
        var unlockedCombatants: [UnlockedCombatantModel]?
        @Relationship(deleteRule: .cascade, inverse: \CombatantProgressionModel.roster)
        var progressions: [CombatantProgressionModel]?
        @Relationship(deleteRule: .cascade, inverse: \AbilityLoadoutModel.roster)
        var abilityLoadouts: [AbilityLoadoutModel]?
        @Relationship(deleteRule: .cascade, inverse: \EquipmentLoadoutModel.roster)
        var equipmentLoadouts: [EquipmentLoadoutModel]?
        @Relationship(deleteRule: .cascade, inverse: \TalentLoadoutModel.roster)
        var talentLoadouts: [TalentLoadoutModel]?

        init() {}
    }

    @Model
    final class TalentLoadoutModel {
        var combatantID: String = ""
        var roster: RosterModel?

        @Relationship(deleteRule: .cascade, inverse: \TalentNodeUnlockModel.loadout)
        var unlockedNodes: [TalentNodeUnlockModel]?

        init(combatantID: String = "") {
            self.combatantID = combatantID
        }
    }

    @Model
    final class TalentNodeUnlockModel {
        var nodeID: String = ""
        var loadout: TalentLoadoutModel?

        init(nodeID: String = "") {
            self.nodeID = nodeID
        }
    }

    @Model
    final class UnlockedCombatantModel {
        var combatantID: String = ""
        var role: String = ""
        var roster: RosterModel?

        /// Shared by persisted rows and incoming unlocks during reconciliation.
        static func key(role: String, combatantID: String) -> String {
            "\(role):\(combatantID)"
        }

        var compositeKey: String {
            Self.key(role: role, combatantID: combatantID)
        }

        init(combatantID: String = "", role: String = "") {
            self.combatantID = combatantID
            self.role = role
        }
    }

    @Model
    final class CombatantProgressionModel {
        var combatantID: String = ""
        var level: Int = 1
        var currentXP: Int = 0
        var requiredXP: Int = CombatantProgression.requiredXP(forLevel: 1)
        var roster: RosterModel?

        init(combatantID: String = "", progression: CombatantProgression = .initial) {
            self.combatantID = combatantID
            level = progression.level
            currentXP = progression.currentXP
            requiredXP = progression.requiredXP
        }
    }

    @Model
    final class AbilityLoadoutModel {
        var combatantID: String = ""
        var basicID: String?
        var skillID: String?
        var ultimateID: String?
        var roster: RosterModel?

        init(combatantID: String = "", loadout: AbilityLoadout = AbilityLoadout()) {
            self.combatantID = combatantID
            basicID = loadout.basic?.id
            skillID = loadout.skill?.id
            ultimateID = loadout.ultimate?.id
        }
    }

    @Model
    final class EquipmentLoadoutModel {
        var combatantID: String = ""
        var roster: RosterModel?

        @Relationship(deleteRule: .cascade, inverse: \EquipmentSlotModel.loadout)
        var slots: [EquipmentSlotModel]?

        init(combatantID: String = "") {
            self.combatantID = combatantID
        }
    }

    @Model
    final class EquipmentSlotModel {
        var slotID: String = ""
        var itemID: String = ""
        var loadout: EquipmentLoadoutModel?

        init(slotID: String = "", itemID: String = "") {
            self.slotID = slotID
            self.itemID = itemID
        }
    }

    @Model
    final class SpiresProgressModel {
        var root: PlayerSaveRoot?
        @Relationship(deleteRule: .cascade, inverse: \SpireFloorProgressModel.spires)
        var floors: [SpireFloorProgressModel]?

        init() {}
    }

    @Model
    final class SpireFloorProgressModel {
        var spireID: String = ""
        var highestClearedFloor: Int = 0
        var spires: SpiresProgressModel?

        init(spireID: String = "", highestClearedFloor: Int = 0) {
            self.spireID = spireID
            self.highestClearedFloor = highestClearedFloor
        }
    }

    @Model
    final class CloudOutboxRecord {
        var journalID: String = ""
        var index: Int = -1
        var payload: Data = Data()

        init(journalID: String, index: Int, payload: Data) {
            self.journalID = journalID
            self.index = index
            self.payload = payload
        }
    }
}
