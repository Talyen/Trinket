import Foundation
import TrinketCore

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
    case damageTakenReduction(keyword: Keyword, percent: Int)
    case blockGained(Int)
    case leechGainedPercent(Int)
    case goldFoundPercent(Int)
    case experienceEarnedPercent(Int)
    case materialsFoundPercent(Int)
    case shopDiscountPercent(Int)
    case astralShopOffers

    public var description: String {
        switch self {
        case let .damageDealt(keyword, amount):
            "\(keyword.rawValue.capitalized) damage is increased by \(amount)"
        case let .damageTakenReduction(keyword, percent):
            "\(keyword.rawValue.capitalized) damage taken is decreased by \(percent)%"
        case let .blockGained(amount):
            "Block gained is increased by \(amount)"
        case let .leechGainedPercent(percent):
            "Leech gained is increased by \(percent)%"
        case let .goldFoundPercent(percent):
            "Gold found is increased by \(percent)%"
        case let .experienceEarnedPercent(percent):
            "XP earned is increased by \(percent)%"
        case let .materialsFoundPercent(percent):
            "Materials found are increased by \(percent)%"
        case let .shopDiscountPercent(percent):
            "Decreases Shop prices by \(percent)%"
        case .astralShopOffers:
            "Shop offers are all Astral items"
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
        nodeTypes: Set<LabyrinthNodeType>,
    ) {
        self.id = id
        self.title = title
        self.effect = effect
        self.nodeTypes = nodeTypes
    }

    public func applies(to type: LabyrinthNodeType) -> Bool {
        nodeTypes.contains(type.canonical)
    }

    public var relevantKeyword: Keyword? {
        switch effect {
        case let .damageDealt(keyword, _):
            keyword
        case let .damageTakenReduction(keyword, _):
            keyword
        default:
            nil
        }
    }
}

public enum LabyrinthNodeType: String, Hashable, Sendable, CaseIterable, Codable {
    case battle
    case boss
    case shop
    case rest
    case mystery
    case recruit
    case event
    case craft
    case entrance

    public var canonical: Self {
        self == .event || self == .craft || self == .rest ? .mystery : self
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if rawValue == "elite" {
            self = .battle
            return
        }
        if rawValue == "warden" {
            self = .boss
            return
        }
        if rawValue == "gate" {
            self = .entrance
            return
        }
        if rawValue == "rest" {
            self = .mystery
            return
        }
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown Labyrinth node type: \(rawValue)",
            )
        }
        self = value
    }

    public var title: String {
        switch canonical {
        case .battle: "Battle"
        case .boss: "Boss"
        case .shop: "Merchant's Shop"
        case .mystery, .event, .craft, .rest: "Mystery"
        case .recruit: "Recruit"
        case .entrance: "Labyrinth Entrance"
        }
    }

    public var symbolName: String {
        switch canonical {
        case .battle: StageTypeSymbol.battle
        case .boss: StageTypeSymbol.boss
        case .shop: StageTypeSymbol.shop
        case .mystery, .event, .craft, .rest: StageTypeSymbol.mystery
        case .recruit: GameContent.recruitEncounterSymbolName(forEventID: nil)
        case .entrance: StageTypeSymbol.entrance
        }
    }

    public var primaryActionTitle: String {
        switch canonical {
        case .battle, .boss:
            "Fight"
        case .shop:
            "Visit"
        case .mystery, .event, .craft, .rest:
            "Approach"
        case .recruit:
            "Recruit"
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
    public let modifierIDs: [LabyrinthModifierID]
    public let recruitEventID: String?
    public var mysteryEventID: String?
    public var mysteryOffersPayload: Data?
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
        mysteryOffersPayload: Data? = nil,
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
        mysteryOffersPayload = try container.decodeIfPresent(Data.self, forKey: .mysteryOffersPayload)
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

public struct LabyrinthModifierEffects: Equatable, Sendable {
    public var damageDealtBonus: [Keyword: Int]
    public var damageTakenReduction: [Keyword: Int]
    public var blockGainedBonus: Int
    public var leechGainedPercent: Int
    public var goldFoundPercent: Int
    public var experienceEarnedPercent: Int
    public var materialsFoundPercent: Int
    public var shopDiscountPercent: Int
    public var astralShopOffers: Bool

    public static let zero = Self(
        damageDealtBonus: [:],
        damageTakenReduction: [:],
        blockGainedBonus: 0,
        leechGainedPercent: 0,
        goldFoundPercent: 0,
        experienceEarnedPercent: 0,
        materialsFoundPercent: 0,
        shopDiscountPercent: 0,
        astralShopOffers: false,
    )

    public init(
        damageDealtBonus: [Keyword: Int],
        damageTakenReduction: [Keyword: Int] = [:],
        blockGainedBonus: Int = 0,
        leechGainedPercent: Int = 0,
        goldFoundPercent: Int = 0,
        experienceEarnedPercent: Int = 0,
        materialsFoundPercent: Int = 0,
        shopDiscountPercent: Int = 0,
        astralShopOffers: Bool = false,
    ) {
        self.damageDealtBonus = damageDealtBonus
        self.damageTakenReduction = damageTakenReduction
        self.blockGainedBonus = blockGainedBonus
        self.leechGainedPercent = leechGainedPercent
        self.goldFoundPercent = goldFoundPercent
        self.experienceEarnedPercent = experienceEarnedPercent
        self.materialsFoundPercent = materialsFoundPercent
        self.shopDiscountPercent = shopDiscountPercent
        self.astralShopOffers = astralShopOffers
    }

    public static func combining(_ modifiers: [LabyrinthModifierDefinition]) -> Self {
        var effects = Self.zero
        for modifier in modifiers {
            switch modifier.effect {
            case let .damageDealt(keyword, amount):
                effects.damageDealtBonus[keyword, default: 0] += amount
            case let .damageTakenReduction(keyword, percent):
                effects.damageTakenReduction[keyword, default: 0] += percent
            case let .blockGained(amount):
                effects.blockGainedBonus += amount
            case let .leechGainedPercent(percent):
                effects.leechGainedPercent += percent
            case let .goldFoundPercent(percent):
                effects.goldFoundPercent += percent
            case let .experienceEarnedPercent(percent):
                effects.experienceEarnedPercent += percent
            case let .materialsFoundPercent(percent):
                effects.materialsFoundPercent += percent
            case let .shopDiscountPercent(percent):
                effects.shopDiscountPercent += percent
            case .astralShopOffers:
                effects.astralShopOffers = true
            }
        }
        return effects
    }
}
