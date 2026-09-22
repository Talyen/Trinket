import Foundation
import TrinketCore

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
    public var goldFindFlat: Int
    public var experienceBonus: Int
    public var gemsFindBonus: Int

    public static let empty = Self()

    public init(
        heroModifiers: [AffixModifier] = [],
        companionModifiers: [AffixModifier] = [],
        astralChanceBonusPercent: Int = 0,
        goldFindPercent: Int = 0,
        goldFindFlat: Int = 0,
        experienceBonus: Int = 0,
        gemsFindBonus: Int = 0,
    ) {
        self.heroModifiers = heroModifiers
        self.companionModifiers = companionModifiers
        self.astralChanceBonusPercent = astralChanceBonusPercent
        self.goldFindPercent = goldFindPercent
        self.goldFindFlat = goldFindFlat
        self.experienceBonus = experienceBonus
        self.gemsFindBonus = gemsFindBonus
    }
}

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
