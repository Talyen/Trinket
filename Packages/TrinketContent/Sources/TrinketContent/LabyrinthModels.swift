import Foundation
import TrinketCore

/// Stable biome identifier for The Labyrinth clusters.
public struct LabyrinthBiomeID: RawRepresentable, Hashable, Codable, Sendable, Identifiable {
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

    public static let ironGalleries = LabyrinthBiomeID("ironGalleries")
    public static let cinderGalleries = LabyrinthBiomeID("cinderGalleries")
    public static let serpentSump = LabyrinthBiomeID("serpentSump")
    public static let scarCatacombs = LabyrinthBiomeID("scarCatacombs")
    public static let aureateCrypt = LabyrinthBiomeID("aureateCrypt")
    public static let rimeDescent = LabyrinthBiomeID("rimeDescent")
    public static let stormCulvert = LabyrinthBiomeID("stormCulvert")
    public static let gildedFault = LabyrinthBiomeID("gildedFault")
    public static let heartwellGrotto = LabyrinthBiomeID("heartwellGrotto")
}

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

public struct LabyrinthBiomeDefinition: Identifiable, Hashable, Sendable {
    public let id: LabyrinthBiomeID
    public let title: String
    public let epithet: String
    public let keywordBias: Keyword
    public let enemyPool: [String]
    public let bossEnemyID: String

    public init(
        id: LabyrinthBiomeID,
        title: String,
        epithet: String,
        keywordBias: Keyword,
        enemyPool: [String],
        bossEnemyID: String
    ) {
        self.id = id
        self.title = title
        self.epithet = epithet
        self.keywordBias = keywordBias
        self.enemyPool = enemyPool
        self.bossEnemyID = bossEnemyID
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
    public var canonical: LabyrinthNodeType {
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
}

public struct LabyrinthCluster: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let biomeID: LabyrinthBiomeID
    public let depthBand: Int
    public let modifierIDs: [LabyrinthModifierID]
    public var nodeIDs: [String]

    public init(
        id: String,
        biomeID: LabyrinthBiomeID,
        depthBand: Int,
        modifierIDs: [LabyrinthModifierID],
        nodeIDs: [String]
    ) {
        self.id = id
        self.biomeID = biomeID
        self.depthBand = depthBand
        self.modifierIDs = modifierIDs
        self.nodeIDs = nodeIDs
    }
}

/// Aggregated combat/reward modifiers for one Labyrinth node.
public struct LabyrinthModifierEffects: Equatable, Sendable {
    public var damageDealtBonus: [Keyword: Int]
    public var goldPercent: Int
    public var astralChanceBonusPercent: Int
    public var keywordBiases: Set<Keyword>

    public static let zero = LabyrinthModifierEffects(
        damageDealtBonus: [:],
        goldPercent: 0,
        astralChanceBonusPercent: 0,
        keywordBiases: []
    )

    public init(
        damageDealtBonus: [Keyword: Int],
        goldPercent: Int,
        astralChanceBonusPercent: Int,
        keywordBiases: Set<Keyword>
    ) {
        self.damageDealtBonus = damageDealtBonus
        self.goldPercent = goldPercent
        self.astralChanceBonusPercent = astralChanceBonusPercent
        self.keywordBiases = keywordBiases
    }

    public static func combining(
        _ modifiers: [LabyrinthModifierDefinition],
        biomeBias: Keyword
    ) -> LabyrinthModifierEffects {
        var effects = LabyrinthModifierEffects.zero
        effects.keywordBiases.insert(biomeBias)
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
