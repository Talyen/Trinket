import Foundation
import TrinketCore

/// Stable biome identifier for Wanderer's Labyrinth clusters.
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
    public static let wildrootHollow = LabyrinthBiomeID("wildrootHollow")
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

public enum LabyrinthModifierCategory: String, Codable, Hashable, Sendable {
    case threat
    case bounty
    case affinity
    case encounter
    case special
}

public struct LabyrinthBiomeDefinition: Identifiable, Hashable, Sendable {
    public let id: LabyrinthBiomeID
    public let title: String
    public let epithet: String
    public let keywordBias: Keyword
    public let enemyPool: [String]
    public let wardenEnemyID: String

    public init(
        id: LabyrinthBiomeID,
        title: String,
        epithet: String,
        keywordBias: Keyword,
        enemyPool: [String],
        wardenEnemyID: String
    ) {
        self.id = id
        self.title = title
        self.epithet = epithet
        self.keywordBias = keywordBias
        self.enemyPool = enemyPool
        self.wardenEnemyID = wardenEnemyID
    }
}

public struct LabyrinthModifierDefinition: Identifiable, Hashable, Sendable {
    public let id: LabyrinthModifierID
    public let title: String
    public let epithet: String
    public let category: LabyrinthModifierCategory
    /// Hidden Keyword bias for affinity / tint; nil when not affinity-flavored.
    public let keywordBias: Keyword?
    public let enemyPowerPercent: Int
    public let goldPercent: Int
    public let xpPercent: Int
    public let itemDropBonusPercent: Int
    public let astralChanceBonusPercent: Int
    public let guaranteedNodeType: LabyrinthNodeType?

    public init(
        id: LabyrinthModifierID,
        title: String,
        epithet: String,
        category: LabyrinthModifierCategory,
        keywordBias: Keyword? = nil,
        enemyPowerPercent: Int = 0,
        goldPercent: Int = 0,
        xpPercent: Int = 0,
        itemDropBonusPercent: Int = 0,
        astralChanceBonusPercent: Int = 0,
        guaranteedNodeType: LabyrinthNodeType? = nil
    ) {
        self.id = id
        self.title = title
        self.epithet = epithet
        self.category = category
        self.keywordBias = keywordBias
        self.enemyPowerPercent = enemyPowerPercent
        self.goldPercent = goldPercent
        self.xpPercent = xpPercent
        self.itemDropBonusPercent = itemDropBonusPercent
        self.astralChanceBonusPercent = astralChanceBonusPercent
        self.guaranteedNodeType = guaranteedNodeType
    }
}

public enum LabyrinthNodeType: String, Codable, Hashable, Sendable, CaseIterable {
    case battle
    case elite
    case warden
    case shop
    case rest
    case mystery
    case event
    case craft
    case gate

    public var title: String {
        switch self {
        case .battle: return "Battle"
        case .elite: return "Elite"
        case .warden: return "Warden"
        case .shop: return "Merchant's Shop"
        case .rest: return "Shrine"
        case .mystery: return "Mystery"
        case .event: return "Event"
        case .craft: return "Crafting Altar"
        case .gate: return "Depth Gate"
        }
    }

    public var symbolName: String {
        switch self {
        case .battle: return "bolt.fill"
        case .elite: return "flame.fill"
        case .warden: return "crown.fill"
        case .shop: return "bag.fill"
        case .rest: return "tent.fill"
        case .mystery: return "sparkles"
        case .event: return "questionmark.circle.fill"
        case .craft: return "hammer.fill"
        case .gate: return "arrow.down.to.line.compact"
        }
    }

    public var primaryActionTitle: String {
        switch self {
        case .battle, .elite, .warden, .gate:
            return "Fight"
        case .shop:
            return "Visit"
        case .rest:
            return "Rest"
        case .mystery:
            return "Approach"
        case .event:
            return "Continue"
        case .craft:
            return "Forge"
        }
    }

    public var isCombat: Bool {
        switch self {
        case .battle, .elite, .warden, .gate:
            return true
        case .shop, .rest, .mystery, .event, .craft:
            return false
        }
    }
}

public struct LabyrinthNode: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let type: LabyrinthNodeType
    public let enemyID: String?
    public let depth: Int
    public let clusterID: String
    /// Outgoing edge node ids within the same or next cluster.
    public var outgoingIDs: [String]
    public var isCleared: Bool
    public var isRevealed: Bool
    public var failCount: Int

    public init(
        id: String,
        type: LabyrinthNodeType,
        enemyID: String? = nil,
        depth: Int,
        clusterID: String,
        outgoingIDs: [String] = [],
        isCleared: Bool = false,
        isRevealed: Bool = false,
        failCount: Int = 0
    ) {
        self.id = id
        self.type = type
        self.enemyID = enemyID
        self.depth = depth
        self.clusterID = clusterID
        self.outgoingIDs = outgoingIDs
        self.isCleared = isCleared
        self.isRevealed = isRevealed
        self.failCount = failCount
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

/// Aggregated combat/reward modifiers for a cluster (rules-facing).
public struct LabyrinthModifierEffects: Equatable, Sendable {
    public var enemyPowerPercent: Int
    public var goldPercent: Int
    public var xpPercent: Int
    public var itemDropBonusPercent: Int
    public var astralChanceBonusPercent: Int
    public var keywordBiases: Set<Keyword>

    public static let zero = LabyrinthModifierEffects(
        enemyPowerPercent: 0,
        goldPercent: 0,
        xpPercent: 0,
        itemDropBonusPercent: 0,
        astralChanceBonusPercent: 0,
        keywordBiases: []
    )

    public init(
        enemyPowerPercent: Int,
        goldPercent: Int,
        xpPercent: Int,
        itemDropBonusPercent: Int,
        astralChanceBonusPercent: Int,
        keywordBiases: Set<Keyword>
    ) {
        self.enemyPowerPercent = enemyPowerPercent
        self.goldPercent = goldPercent
        self.xpPercent = xpPercent
        self.itemDropBonusPercent = itemDropBonusPercent
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
            effects.enemyPowerPercent += modifier.enemyPowerPercent
            effects.goldPercent += modifier.goldPercent
            effects.xpPercent += modifier.xpPercent
            effects.itemDropBonusPercent += modifier.itemDropBonusPercent
            effects.astralChanceBonusPercent += modifier.astralChanceBonusPercent
            if let bias = modifier.keywordBias {
                effects.keywordBiases.insert(bias)
            }
        }
        return effects
    }
}
