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

public struct HomesteadNodeTier: Hashable, Sendable {
    public let tier: Int
    public let cost: [ResourceAmount]
    public let bonus: HomesteadBonus
    public let production: ResourceAmount?

    public init(
        tier: Int,
        cost: [ResourceAmount],
        bonus: HomesteadBonus,
        production: ResourceAmount? = nil
    ) {
        self.tier = tier
        self.cost = cost
        self.bonus = bonus
        self.production = production
    }
}

public struct HomesteadNodeDefinition: Identifiable, Hashable, Sendable {
    public let id: HomesteadNodeID
    public let title: String
    public let summary: String
    public let symbolName: String
    public let tintStyle: HomesteadTint
    public let category: HomesteadNodeCategory
    public let prerequisites: [HomesteadNodeRequirement]
    public let tiers: [HomesteadNodeTier]

    public init(
        id: HomesteadNodeID,
        title: String,
        summary: String,
        symbolName: String,
        tintStyle: HomesteadTint,
        category: HomesteadNodeCategory,
        prerequisites: [HomesteadNodeRequirement],
        tiers: [HomesteadNodeTier]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.symbolName = symbolName
        self.tintStyle = tintStyle
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
        $0.maxTier
    ) })
}
