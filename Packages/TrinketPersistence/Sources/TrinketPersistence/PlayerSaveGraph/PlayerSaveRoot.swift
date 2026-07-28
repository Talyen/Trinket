import Foundation
import SwiftData
import TrinketCore

@Model
public final class PlayerSaveRoot {
    public var id: String = "primary"
    public var schemaVersion: Int = PlayerSave.currentSchemaVersion
    public var modifiedAt: Date = Date()
    public var sessionGeneration: UInt64 = 0
    public var corruptionAltarCooldownRemaining: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \JourneyProgressModel.root)
    public var journey: JourneyProgressModel?
    @Relationship(deleteRule: .cascade, inverse: \RosterModel.root)
    public var roster: RosterModel?
    @Relationship(deleteRule: .cascade, inverse: \InventoryModel.root)
    public var inventory: InventoryModel?
    @Relationship(deleteRule: .cascade, inverse: \HomesteadModel.root)
    public var homestead: HomesteadModel?
    @Relationship(deleteRule: .cascade, inverse: \SpiresProgressModel.root)
    public var spires: SpiresProgressModel?
    @Relationship(deleteRule: .cascade, inverse: \LabyrinthProgressModel.root)
    public var labyrinth: LabyrinthProgressModel?

    public init(id: String = "primary") {
        self.id = id
    }
}

enum PlayerSaveSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static let models: [any PersistentModel.Type] = [
        PlayerSaveRoot.self,
        JourneyProgressModel.self,
        JourneyStageProgressModel.self,
        RosterModel.self,
        UnlockedCombatantModel.self,
        CombatantProgressionModel.self,
        AbilityLoadoutModel.self,
        EquipmentLoadoutModel.self,
        EquipmentSlotModel.self,
        PrimaryStatsModel.self,
        InventoryModel.self,
        InventoryItemModel.self,
        ItemAffixModel.self,
        HomesteadModel.self,
        HomesteadResourceBalanceModel.self,
        HomesteadNodeTierModel.self,
        SpiresProgressModel.self,
        SpireFloorProgressModel.self,
        LabyrinthProgressModel.self,
    ]
}

enum PlayerSaveMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [
        PlayerSaveSchemaV1.self,
    ]

    static let stages: [MigrationStage] = []
}

public enum PlayerSaveGraph {
    public static let schema = Schema(versionedSchema: PlayerSaveSchemaV1.self)
}
