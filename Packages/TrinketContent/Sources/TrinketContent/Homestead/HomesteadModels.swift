import TrinketCore

public struct HomesteadBonus: Hashable, Sendable {
    public let title: String
    public let description: String

    public init(title: String, description: String) {
        self.title = title
        self.description = description
    }
}

/// A tier contributes the same fields that the combined Homestead effects expose.
public typealias HomesteadTierCombatBonus = HomesteadEffects

public struct HomesteadNodeTier: Hashable, Sendable {
    public let tier: Int
    public let stageName: String
    public let cost: [ResourceAmount]
    public let bonus: HomesteadBonus
    public let combatBonus: HomesteadTierCombatBonus
    public let production: [ResourceAmount]

    public init(
        tier: Int,
        stageName: String,
        cost: [ResourceAmount],
        bonus: HomesteadBonus,
        combatBonus: HomesteadTierCombatBonus = .empty,
        production: [ResourceAmount] = [],
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
    public let iconID: String
    public let category: HomesteadNodeCategory
    public let tiers: [HomesteadNodeTier]

    public init(
        id: HomesteadNodeID,
        title: String,
        summary: String,
        iconID: String,
        category: HomesteadNodeCategory,
        tiers: [HomesteadNodeTier],
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.iconID = iconID
        self.category = category
        self.tiers = tiers
    }

    public var maxTier: Int {
        tiers.last?.tier ?? 0
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
