import Foundation
import TrinketCore

public struct HomesteadNodeRequirement: Hashable, Sendable {
    public let nodeID: HomesteadNodeID
    public let minimumTier: Int

    public init(_ nodeID: HomesteadNodeID, tier: Int = 1) {
        self.nodeID = nodeID
        minimumTier = tier
    }
}

public struct HomesteadBonus: Hashable, Sendable {
    public let title: String
    public let description: String

    public init(title: String, description: String) {
        self.title = title
        self.description = description
    }
}

public struct HomesteadTierCombatBonus: Equatable, Hashable, Sendable {
    public var heroModifiers: [AffixModifier]
    public var companionModifiers: [AffixModifier]
    public var astralChanceBonusPercent: Int
    public var goldFindPercent: Int

    public static let empty = Self()

    public init(
        heroModifiers: [AffixModifier] = [],
        companionModifiers: [AffixModifier] = [],
        astralChanceBonusPercent: Int = 0,
        goldFindPercent: Int = 0,
    ) {
        self.heroModifiers = heroModifiers
        self.companionModifiers = companionModifiers
        self.astralChanceBonusPercent = astralChanceBonusPercent
        self.goldFindPercent = goldFindPercent
    }
}

public struct HomesteadNodeTier: Hashable, Sendable {
    public let tier: Int
    public let stageName: String
    public let cost: [ResourceAmount]
    public let bonus: HomesteadBonus
    public let combatBonus: HomesteadTierCombatBonus
    public let production: ResourceAmount?

    public init(
        tier: Int,
        stageName: String,
        cost: [ResourceAmount],
        bonus: HomesteadBonus,
        combatBonus: HomesteadTierCombatBonus = .empty,
        production: ResourceAmount? = nil,
    ) {
        self.tier = tier
        self.stageName = stageName
        self.cost = cost
        self.bonus = bonus
        self.combatBonus = combatBonus
        self.production = production
    }
}

public struct HomesteadNodeDefinition: Identifiable, Hashable, Sendable {
    public let id: HomesteadNodeID
    public let title: String
    public let summary: String
    public let symbolName: String
    public let category: HomesteadNodeCategory
    public let prerequisites: [HomesteadNodeRequirement]
    public let tiers: [HomesteadNodeTier]

    public init(
        id: HomesteadNodeID,
        title: String,
        summary: String,
        symbolName: String,
        category: HomesteadNodeCategory,
        prerequisites: [HomesteadNodeRequirement],
        tiers: [HomesteadNodeTier],
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.symbolName = symbolName
        self.category = category
        self.prerequisites = prerequisites
        self.tiers = tiers
    }

    public var maxTier: Int {
        tiers.map(\.tier).max() ?? 0
    }

    public func tier(_ value: Int) -> HomesteadNodeTier? {
        tiers.first { $0.tier == value }
    }
}

public enum HomesteadNodeCatalog {
    public static let maxTierByNodeID: [HomesteadNodeID: Int] = Dictionary(uniqueKeysWithValues: GameContent.homesteadNodes.map { (
        $0.id,
        $0.maxTier,
    ) })
}
