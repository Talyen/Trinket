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
            "Reduced Gold Prices"
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

/// Resolved encounter rules. Combat uses the same modifier language as equipment
/// and talents, so launch and headless simulations cannot translate it differently.
public struct NodeModifierEffects: Equatable, Sendable {
    public private(set) var combatModifiers: [AffixModifier] = []
    public var goldFoundPercent = 0
    public var experienceEarnedPercent = 0
    public var materialsFoundPercent = 0
    public var shopDiscountPercent = 0
    public var astralShopOffers = false
    public var rewardModifier: RewardModifier?

    public static let zero = Self()

    public static func combining(_ modifiers: [NodeModifierDefinition]) -> Self {
        guard !modifiers.isEmpty else { return .zero }
        var effects = Self.zero
        var combat = NodeCombatBonuses()
        for modifier in modifiers {
            switch modifier.effect {
            case let .damageDealt(keyword, amount):
                combat.damageDealtBonus[keyword, default: 0] += amount
            case let .damageTakenReduction(keyword, percent):
                combat.damageTakenReduction[keyword, default: 0] += percent
            case let .blockGained(amount):
                combat.blockGainedBonus += amount
            case let .leechGainedPercent(percent):
                combat.leechGainedPercent += percent
            case let .startBattleBlock(amount):
                combat.startBattleBlock += amount
            case .attackLeech:
                combat.attackLeech = true
            case let .attackBlockRemoval(amount):
                combat.attackBlockRemoval += amount
            case let .attackPurge(count):
                combat.attackPurgeCount += count
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
        effects.combatModifiers = combat.modifiers
        return effects
    }
}

/// Aggregate before converting percentages, preserve stable keyword order, and
/// grant attack Leech once even when multiple definitions supply it.
private struct NodeCombatBonuses {
    var damageDealtBonus: [Keyword: Int] = [:]
    var damageTakenReduction: [Keyword: Int] = [:]
    var blockGainedBonus = 0
    var leechGainedPercent = 0
    var startBattleBlock = 0
    var attackLeech = false
    var attackBlockRemoval = 0
    var attackPurgeCount = 0

    var modifiers: [AffixModifier] {
        var result: [AffixModifier] = []
        if !damageDealtBonus.isEmpty {
            result.append(contentsOf: damageDealtBonus.sorted { $0.key.rawValue < $1.key.rawValue }
                .lazy.map { AffixModifier.damageDealt($0.key, $0.value) })
        }
        if !damageTakenReduction.isEmpty {
            result.append(contentsOf: damageTakenReduction.sorted { $0.key.rawValue < $1.key.rawValue }
                .lazy.map { AffixModifier.damageTakenPercent($0.key, Double($0.value) / 100) })
        }
        if blockGainedBonus != 0 {
            result.append(.blockGained(blockGainedBonus))
        }
        if leechGainedPercent != 0 {
            result.append(.leechGainedPercent(Double(leechGainedPercent) / 100))
        }
        if startBattleBlock != 0 {
            result.append(.startBattleBlock(startBattleBlock))
        }
        if attackLeech {
            result.append(.attackLeechPercent(Effect.abilityLeechPercent))
        }
        if attackBlockRemoval != 0 {
            result.append(.attackBlockRemoval(attackBlockRemoval))
        }
        if attackPurgeCount != 0 {
            result.append(.attackPurgeCount(attackPurgeCount))
        }
        return result
    }
}
