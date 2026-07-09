import Foundation
import SwiftData
import TrinketCore

@Model
public final class PlayerSaveRoot {
    public var id: String = "primary"
    public var schemaVersion: Int = PlayerSave.currentSchemaVersion
    public var modifiedAt: Date = Date()
    public var sessionGeneration: UInt64 = 0

    @Relationship(deleteRule: .cascade, inverse: \JourneyProgressModel.root)
    public var journey: JourneyProgressModel?
    @Relationship(deleteRule: .cascade, inverse: \RosterModel.root)
    public var roster: RosterModel?
    @Relationship(deleteRule: .cascade, inverse: \InventoryModel.root)
    public var inventory: InventoryModel?
    @Relationship(deleteRule: .cascade, inverse: \HomesteadModel.root)
    public var homestead: HomesteadModel?
    @Relationship(deleteRule: .cascade, inverse: \CollectionAttentionModel.root)
    public var collectionAttention: CollectionAttentionModel?
    @Relationship(deleteRule: .cascade, inverse: \AspectsProgressModel.root)
    public var aspects: AspectsProgressModel?
    @Relationship(deleteRule: .cascade, inverse: \LabyrinthProgressModel.root)
    public var labyrinth: LabyrinthProgressModel?

    public init(id: String = "primary") {
        self.id = id
    }
}

public enum PlayerSaveGraph {
    public static let schema = Schema([
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
        CollectionAttentionModel.self,
        AspectsProgressModel.self,
        AspectFloorProgressModel.self,
        LabyrinthProgressModel.self
    ])
}
