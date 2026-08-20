import Foundation
import TrinketCore

/// Catalog modifier shown by title only in player UI (no umbrella noun).
public struct LabyrinthModifierID: RawRepresentable, Hashable, Codable, Sendable, Identifiable {
    public let rawValue: String

    public var id: String {
        rawValue
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public enum LabyrinthModifierEffect: Hashable, Sendable {
    case damageDealt(keyword: Keyword, amount: Int)
    case goldRewardPercent(Int)
    case astralChancePercent(Int)

    public var description: String {
        switch self {
        case let .damageDealt(keyword, amount):
            "\(keyword.rawValue.capitalized) damage is increased by \(amount)."
        case let .goldRewardPercent(percent):
            "Increases Gold rewards by \(percent)%."
        case let .astralChancePercent(percent):
            "Increases chance to find Astral items by \(percent)%."
        }
    }
}

public struct LabyrinthModifierDefinition: Identifiable, Hashable, Sendable {
    public let id: LabyrinthModifierID
    public let title: String
    public let effect: LabyrinthModifierEffect
    public let nodeTypes: Set<LabyrinthNodeType>

    public init(
        id: LabyrinthModifierID,
        title: String,
        effect: LabyrinthModifierEffect,
        nodeTypes: Set<LabyrinthNodeType>
    ) {
        self.id = id
        self.title = title
        self.effect = effect
        self.nodeTypes = nodeTypes
    }

    public func applies(to type: LabyrinthNodeType) -> Bool {
        nodeTypes.contains(type.canonical)
    }

    public var damageDealtKeyword: Keyword? {
        if case let .damageDealt(keyword, _) = effect {
            return keyword
        }
        return nil
    }
}

public enum LabyrinthNodeType: String, Hashable, Sendable, CaseIterable, Codable {
    case battle
    case boss
    case shop
    case rest
    case mystery
    case recruit
    /// Legacy save value; sanitized to `.mystery`. Do not generate new event nodes.
    case event
    case craft
    case entrance

    /// Canonical type after collapsing legacy `.event` into mystery encounters.
    public var canonical: Self {
        self == .event ? .mystery : self
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if rawValue == "elite" {
            self = .battle
            return
        }
        // Legacy saves encoded boss nodes as "warden" and entrance as "gate".
        if rawValue == "warden" {
            self = .boss
            return
        }
        if rawValue == "gate" {
            self = .entrance
            return
        }
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown Labyrinth node type: \(rawValue)"
            )
        }
        self = value
    }

    public var title: String {
        switch canonical {
        case .battle: "Battle"
        case .boss: "Boss"
        case .shop: "Merchant's Shop"
        case .rest: "Shrine"
        case .mystery, .event: "Mystery"
        case .recruit: "Recruit"
        case .craft: "Crafting Altar"
        case .entrance: "Labyrinth Entrance"
        }
    }

    public var symbolName: String {
        switch canonical {
        case .battle: StageTypeSymbol.battle
        case .boss: StageTypeSymbol.boss
        case .shop: StageTypeSymbol.shop
        case .rest: StageTypeSymbol.rest
        case .mystery, .event: StageTypeSymbol.mystery
        case .recruit: GameContent.recruitEncounterSymbolName(forEventID: nil)
        case .craft: StageTypeSymbol.craft
        case .entrance: StageTypeSymbol.entrance
        }
    }

    public var primaryActionTitle: String {
        switch canonical {
        case .battle, .boss:
            "Fight"
        case .shop:
            "Visit"
        case .rest:
            "Rest"
        case .mystery, .event:
            "Approach"
        case .recruit:
            "Recruit"
        case .craft:
            "Forge"
        case .entrance:
            "Enter"
        }
    }

    public var isCombat: Bool {
        switch canonical {
        case .battle, .boss:
            true
        case .shop, .rest, .mystery, .event, .recruit, .craft, .entrance:
            false
        }
    }
}

/// Stable axial hex-grid position for a Labyrinth node within one floor.
public struct LabyrinthGridPosition: Hashable, Codable, Sendable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    /// Axial projected half-column: `2 * column + row`.
    public var projectedHalfColumn: Int {
        2 * column + row
    }

    /// True when the two hexes share an edge. Single source of truth for Labyrinth
    /// hex adjacency — generation, reachability, and save sanitizing must not
    /// re-implement this.
    public func isAdjacent(to other: Self) -> Bool {
        let rowDelta = other.row - row
        let columnDelta = other.column - column
        return (rowDelta == 0 && abs(columnDelta) == 1)
            || (rowDelta == 1 && (columnDelta == 0 || columnDelta == -1))
            || (rowDelta == -1 && (columnDelta == 0 || columnDelta == 1))
    }

    /// Row-major ordering used for stable floor layout (single source of truth for
    /// Labyrinth node ordering).
    public static func isOrderedBefore(_ lhs: Self, _ rhs: Self) -> Bool {
        lhs.row == rhs.row ? lhs.column < rhs.column : lhs.row < rhs.row
    }
}

/// Shared floor-width contract for Labyrinth generation and map UI.
///
/// Floors stay within three full hex columns so portrait layout can size seals
/// edge-to-edge for that worst case.
public enum LabyrinthMapLayout {
    /// Inclusive half-column bound: projected indices in `-max...max`.
    public static let maxProjectedHalfColumn = 2
    /// `max − min` of projected half-columns across a valid floor.
    public static let maxProjectedSpan = maxProjectedHalfColumn * 2
    /// Full hex columns that fit the projected half-column window.
    public static let fullColumnsAcross = maxProjectedHalfColumn + 1
}

public struct LabyrinthNode: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let type: LabyrinthNodeType
    public let enemyID: String?
    public let depth: Int
    public let clusterID: String
    public let gridPosition: LabyrinthGridPosition?
    public let modifierIDs: [LabyrinthModifierID]
    /// Concealed recruit event payload; the map exposes only the Recruit type.
    public let recruitEventID: String?
    /// Pinned mystery event so reopen stays stable with inventory-gated picks.
    public var mysteryEventID: String?
    /// Outgoing edge node ids within the same or next cluster.
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
        modifierIDs: [LabyrinthModifierID] = [],
        recruitEventID: String? = nil,
        mysteryEventID: String? = nil,
        outgoingIDs: [String] = [],
        isCleared: Bool = false,
        isRevealed: Bool = false
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
        modifierIDs = try container.decodeIfPresent([LabyrinthModifierID].self, forKey: .modifierIDs) ?? []
        recruitEventID = try container.decodeIfPresent(String.self, forKey: .recruitEventID)
        mysteryEventID = try container.decodeIfPresent(String.self, forKey: .mysteryEventID)
        outgoingIDs = try container.decodeIfPresent([String].self, forKey: .outgoingIDs) ?? []
        isCleared = try container.decodeIfPresent(Bool.self, forKey: .isCleared) ?? false
        isRevealed = try container.decodeIfPresent(Bool.self, forKey: .isRevealed) ?? false
    }

    /// Whether the two nodes share a hex edge (delegates to `LabyrinthGridPosition`).
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
        nodeIDs: [String]
    ) {
        self.id = id
        self.depthBand = depthBand
        self.nodeIDs = nodeIDs
    }
}

/// Aggregated combat/reward modifiers for one Labyrinth node.
public struct LabyrinthModifierEffects: Equatable, Sendable {
    public var damageDealtBonus: [Keyword: Int]
    public var goldPercent: Int
    public var astralChanceBonusPercent: Int

    public static let zero = Self(
        damageDealtBonus: [:],
        goldPercent: 0,
        astralChanceBonusPercent: 0
    )

    public init(
        damageDealtBonus: [Keyword: Int],
        goldPercent: Int,
        astralChanceBonusPercent: Int
    ) {
        self.damageDealtBonus = damageDealtBonus
        self.goldPercent = goldPercent
        self.astralChanceBonusPercent = astralChanceBonusPercent
    }

    public static func combining(_ modifiers: [LabyrinthModifierDefinition]) -> Self {
        var effects = Self.zero
        for modifier in modifiers {
            switch modifier.effect {
            case let .damageDealt(keyword, amount):
                effects.damageDealtBonus[keyword, default: 0] += amount
            case let .goldRewardPercent(percent):
                effects.goldPercent += percent
            case let .astralChancePercent(percent):
                effects.astralChanceBonusPercent += percent
            }
        }
        return effects
    }
}
