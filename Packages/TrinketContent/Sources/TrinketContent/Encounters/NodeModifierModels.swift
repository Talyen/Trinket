import Foundation
import TrinketCore

public struct NodeModifierID: RawRepresentable, Hashable, Codable, Sendable, Identifiable {
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

public enum NodeModifierEffect: Hashable, Sendable {
    case damageDealt(keyword: Keyword, amount: Int)
    case damageTakenReduction(keyword: Keyword, percent: Int)
    case blockGained(Int)
    case leechGainedPercent(Int)
    case startBattleBlock(Int)
    case attackLeech
    case attackBlockRemoval(Int)
    case attackPurge(Int)
    case reward(RewardModifier)
    case shopDiscountPercent(Int)
    case astralShopOffers

    /// Map and detail copy intentionally names the effect without exposing its numeric bonus.
    public var description: String {
        switch self {
        case let .damageDealt(keyword, _):
            "Increased \(keyword.rawValue) Damage"
        case let .damageTakenReduction(keyword, _):
            "\(keyword.rawValue) Resistance"
        case .blockGained:
            "Increased Block"
        case .leechGainedPercent:
            "Increased Leech"
        case .startBattleBlock:
            "Starts with Block"
        case .attackLeech:
            "Attacks Leech"
        case .attackBlockRemoval:
            "Destroys Block"
        case .attackPurge:
            "Attacks Purge"
        case let .reward(modifier):
            modifier.description
        case .shopDiscountPercent:
            "Price Discount"
        case .astralShopOffers:
            "Astral inventory"
        }
    }
}

public struct NodeModifierDefinition: Identifiable, Hashable, Sendable {
    public let id: NodeModifierID
    public let title: String
    public let effect: NodeModifierEffect
    public let nodeTypes: Set<LabyrinthNodeType>

    public init(
        id: NodeModifierID,
        title: String,
        effect: NodeModifierEffect,
        nodeTypes: Set<LabyrinthNodeType>,
    ) {
        self.id = id
        self.title = title
        self.effect = effect
        self.nodeTypes = nodeTypes
    }

    public func applies(to type: LabyrinthNodeType) -> Bool {
        nodeTypes.contains(type)
    }

    public var relevantKeyword: Keyword? {
        switch effect {
        case let .damageDealt(keyword, _):
            keyword
        default:
            nil
        }
    }
}

public struct NodeModifierEffects: Equatable, Sendable {
    public var damageDealtBonus: [Keyword: Int]
    public var damageTakenReduction: [Keyword: Int]
    public var blockGainedBonus: Int
    public var leechGainedPercent: Int
    public var startBattleBlock: Int
    public var attackLeech: Bool
    public var attackBlockRemoval: Int
    public var attackPurgeCount: Int
    public var goldFoundPercent: Int
    public var experienceEarnedPercent: Int
    public var materialsFoundPercent: Int
    public var shopDiscountPercent: Int
    public var astralShopOffers: Bool
    public var rewardModifier: RewardModifier?

    public static let zero = Self(
        damageDealtBonus: [:],
        damageTakenReduction: [:],
        blockGainedBonus: 0,
        leechGainedPercent: 0,
        startBattleBlock: 0,
        attackLeech: false,
        attackBlockRemoval: 0,
        attackPurgeCount: 0,
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
        startBattleBlock: Int = 0,
        attackLeech: Bool = false,
        attackBlockRemoval: Int = 0,
        attackPurgeCount: Int = 0,
        goldFoundPercent: Int = 0,
        experienceEarnedPercent: Int = 0,
        materialsFoundPercent: Int = 0,
        shopDiscountPercent: Int = 0,
        astralShopOffers: Bool = false,
        rewardModifier: RewardModifier? = nil,
    ) {
        self.damageDealtBonus = damageDealtBonus
        self.damageTakenReduction = damageTakenReduction
        self.blockGainedBonus = blockGainedBonus
        self.leechGainedPercent = leechGainedPercent
        self.startBattleBlock = startBattleBlock
        self.attackLeech = attackLeech
        self.attackBlockRemoval = attackBlockRemoval
        self.attackPurgeCount = attackPurgeCount
        self.goldFoundPercent = goldFoundPercent
        self.experienceEarnedPercent = experienceEarnedPercent
        self.materialsFoundPercent = materialsFoundPercent
        self.shopDiscountPercent = shopDiscountPercent
        self.astralShopOffers = astralShopOffers
        self.rewardModifier = rewardModifier
    }

    public static func combining(_ modifiers: [NodeModifierDefinition]) -> Self {
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
            case let .startBattleBlock(amount):
                effects.startBattleBlock += amount
            case .attackLeech:
                effects.attackLeech = true
            case let .attackBlockRemoval(amount):
                effects.attackBlockRemoval += amount
            case let .attackPurge(count):
                effects.attackPurgeCount += count
            case let .reward(modifier):
                effects.rewardModifier = modifier
                effects.goldFoundPercent += modifier.goldBonusPercent
                effects.experienceEarnedPercent += modifier.experienceBonusPercent
                effects.materialsFoundPercent += modifier.materialsBonusPercent
            case let .shopDiscountPercent(percent):
                effects.shopDiscountPercent += percent
            case .astralShopOffers:
                effects.astralShopOffers = true
            }
        }
        return effects
    }
}
