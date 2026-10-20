import Foundation
import SwiftData
import TrinketCore

@Model
package final class PlayerSaveRoot {
    package var id: String = "primary"
    var schemaVersion: Int = PlayerSave.currentSchemaVersion
    var modifiedAt: Date = Date()
    var sessionGeneration: UInt64 = 0
    var worldSeed: UInt64 = 0
    var starterSelectionPhaseRawValue: String = StarterSelectionPhase.complete.rawValue
    var starterHeroID: String?
    var corruptionAltarCooldownRemaining: Int = 0
    var contractsPayload: Data?
    var voyagePayload: Data?
    var libraryPayload: Data?
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

enum PlayerSaveSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static let models = PlayerSaveSchemaV3.models.filter { $0 != PlayerSaveSchemaV3.CloudOutboxRecord.self }
}

enum PlayerSaveSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)
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
}

enum PlayerSaveMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [
        PlayerSaveSchemaV2.self,
        PlayerSaveSchemaV3.self,
        PlayerSaveSchemaV4.self,
        PlayerSaveSchema.self,
    ]
    static let stages = [
        MigrationStage.lightweight(fromVersion: PlayerSaveSchemaV2.self, toVersion: PlayerSaveSchemaV3.self),
        MigrationStage.lightweight(fromVersion: PlayerSaveSchemaV3.self, toVersion: PlayerSaveSchemaV4.self),
        MigrationStage.lightweight(fromVersion: PlayerSaveSchemaV4.self, toVersion: PlayerSaveSchema.self),
    ]
}

package enum PlayerSaveGraph {
    package static let schema = Schema(versionedSchema: PlayerSaveSchema.self)
}
