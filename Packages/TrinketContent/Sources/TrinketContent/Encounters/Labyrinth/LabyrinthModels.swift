import Foundation
import TrinketCore

public enum LabyrinthNodeType: String, Hashable, Sendable, CaseIterable, Codable {
    case battle
    case boss
    case shop
    case mystery
    case recruit
    case entrance

    public var title: String {
        switch self {
        case .battle: "Battle"
        case .boss: "Boss"
        case .shop: "Merchant's Shop"
        case .mystery: "Mystery"
        case .recruit: "Recruit"
        case .entrance: "Labyrinth Entrance"
        }
    }

    public var iconID: String {
        switch self {
        case .battle: StageTypeIconID.battle
        case .boss: StageTypeIconID.boss
        case .shop: StageTypeIconID.shop
        case .mystery: StageTypeIconID.mystery
        case .recruit: GameContent.recruitEncounterIconID(forEventID: nil)
        case .entrance: StageTypeIconID.entrance
        }
    }

    public var primaryActionTitle: String {
        switch self {
        case .battle, .boss:
            "Fight"
        case .shop:
            "Visit"
        case .mystery:
            "Approach"
        case .recruit:
            "Recruit"
        case .entrance:
            "Enter"
        }
    }

    public var isCombat: Bool {
        switch self {
        case .battle, .boss:
            true
        case .shop, .mystery, .recruit, .entrance:
            false
        }
    }
}

public struct LabyrinthGridPosition: Hashable, Codable, Sendable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    public var projectedHalfColumn: Int {
        2 * column + row
    }

    public func isAdjacent(to other: Self) -> Bool {
        let rowDelta = other.row - row
        let columnDelta = other.column - column
        return (rowDelta == 0 && abs(columnDelta) == 1)
            || (rowDelta == 1 && (columnDelta == 0 || columnDelta == -1))
            || (rowDelta == -1 && (columnDelta == 0 || columnDelta == 1))
    }

    public static func isOrderedBefore(_ lhs: Self, _ rhs: Self) -> Bool {
        lhs.row == rhs.row ? lhs.column < rhs.column : lhs.row < rhs.row
    }
}

public enum LabyrinthMapLayout {
    public static let maxProjectedHalfColumn = 2
    public static let maxProjectedSpan = maxProjectedHalfColumn * 2
    public static let fullColumnsAcross = maxProjectedHalfColumn + 1
}

public struct LabyrinthNode: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let type: LabyrinthNodeType
    public let enemyID: String?
    public let depth: Int
    public let clusterID: String
    public let gridPosition: LabyrinthGridPosition?
    public let modifierIDs: [NodeModifierID]
    public let recruitEventID: String?
    public var mysteryEventID: String?
    public var mysteryOffersPayload: Data?
    public var shopPayload: Data?
    public var outgoingIDs: [String]
    public var isCleared: Bool
    public var isRevealed: Bool

    public init(
        id: String,
        type: LabyrinthNodeType,
        enemyID: String? = nil,
        depth: Int,
        clusterID: String,
        gridPosition: LabyrinthGridPosition? = nil,
        modifierIDs: [NodeModifierID] = [],
        recruitEventID: String? = nil,
        mysteryEventID: String? = nil,
        mysteryOffersPayload: Data? = nil,
        shopPayload: Data? = nil,
        outgoingIDs: [String] = [],
        isCleared: Bool = false,
        isRevealed: Bool = false,
    ) {
        self.id = id
        self.type = type
        self.enemyID = enemyID
        self.depth = depth
        self.clusterID = clusterID
        self.gridPosition = gridPosition
        self.modifierIDs = modifierIDs
        self.recruitEventID = recruitEventID
        self.mysteryEventID = mysteryEventID
        self.mysteryOffersPayload = mysteryOffersPayload
        self.shopPayload = shopPayload
        self.outgoingIDs = outgoingIDs
        self.isCleared = isCleared
        self.isRevealed = isRevealed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(LabyrinthNodeType.self, forKey: .type)
        enemyID = try container.decodeIfPresent(String.self, forKey: .enemyID)
        depth = try container.decode(Int.self, forKey: .depth)
        clusterID = try container.decode(String.self, forKey: .clusterID)
        gridPosition = try container.decodeIfPresent(LabyrinthGridPosition.self, forKey: .gridPosition)
        modifierIDs = try container.decodeIfPresent([NodeModifierID].self, forKey: .modifierIDs) ?? []
        recruitEventID = try container.decodeIfPresent(String.self, forKey: .recruitEventID)
        mysteryEventID = try container.decodeIfPresent(String.self, forKey: .mysteryEventID)
        mysteryOffersPayload = try container.decodeIfPresent(Data.self, forKey: .mysteryOffersPayload)
        shopPayload = try container.decodeIfPresent(Data.self, forKey: .shopPayload)
        outgoingIDs = try container.decodeIfPresent([String].self, forKey: .outgoingIDs) ?? []
        isCleared = try container.decodeIfPresent(Bool.self, forKey: .isCleared) ?? false
        isRevealed = try container.decodeIfPresent(Bool.self, forKey: .isRevealed) ?? false
    }

    public func isAdjacent(to other: Self) -> Bool {
        guard let gridPosition, let otherPosition = other.gridPosition else { return false }
        return gridPosition.isAdjacent(to: otherPosition)
    }
}

public struct LabyrinthCluster: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let depthBand: Int
    public var nodeIDs: [String]

    public init(
        id: String,
        depthBand: Int,
        nodeIDs: [String],
    ) {
        self.id = id
        self.depthBand = depthBand
        self.nodeIDs = nodeIDs
    }
}
