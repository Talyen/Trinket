import Foundation

public enum EffectTarget: Hashable, Sendable {
    case abilityTarget
    case actor
    case enemy
    case hero
    case companion
    case lowestHealthAlly
    /// Prefer a defeated party ally (companion first, then hero).
    case defeatedAlly
}

public struct DamageComponent: Hashable, Sendable {
    public let amount: Int
    public let keyword: Keyword
    public let target: EffectTarget
    public let bonusAmount: Int
    public let condition: DamageCondition?

    public init(
        _ amount: Int,
        keyword: Keyword = .physical,
        target: EffectTarget = .abilityTarget,
        bonusAmount: Int = 0,
        condition: DamageCondition? = nil
    ) {
        self.amount = amount
        self.keyword = keyword
        self.target = target
        self.bonusAmount = bonusAmount
        self.condition = condition
    }

    /// True when this component's damage number can be raised by Mana empowerment.
    public var isManaEmpowerableBurnOrFreezeDamage: Bool {
        keyword == .burn || keyword == .freeze
    }

    /// Returns a copy with Burn/Freeze amount increased by `amount`; other keywords unchanged.
    public func withManaEmpowerment(_ amount: Int = 1) -> Self {
        guard isManaEmpowerableBurnOrFreezeDamage else { return self }
        return Self(
            self.amount + amount,
            keyword: keyword,
            target: target,
            bonusAmount: bonusAmount,
            condition: condition
        )
    }
}

public struct TargetedEffect: Hashable, Sendable {
    public let effect: Effect
    public let target: EffectTarget
    public let condition: DamageCondition?

    public init(_ effect: Effect, target: EffectTarget? = nil, condition: DamageCondition? = nil) {
        self.effect = effect
        self.target = target ?? Effect.defaultTarget(for: effect)
        self.condition = condition
    }
}

public enum Effect: Hashable, Sendable {
    case burn(Int)
    case poison(Int)
    case bleed(Int)
    case controlMeter(Keyword, Int, Int)
    /// Flat Block buffer. Stacks into a single pool; no timed duration.
    case shield(Keyword, Int)
    case instantHeal(Keyword, Int)
    case leech(Keyword, Double, Int)
    case resourceGain(Keyword, Int)
    /// Draw `Int` cards for the resolved effect target's deck (hero or companion).
    case drawCards(Int)
    case cleanse(Keyword?)
    case cleanseRandom
    case purge(Keyword?)
    case purgeRandom
    /// Halve the target's current Block pool (floor).
    case halveShield(Keyword)
    case deathsDoor
    /// Physical thorns stacks. Each stack deals 1 Physical on the next hit received, then expires.
    case thorns(Int)
    case marked(Int, Int)
    case criticalChanceBonus(Double, Int)
    case restoreManaOnHit(Int, Int)
    /// Forces outgoing damage keywords to `keyword` and adds `bonus` damage for `durationTurns`.
    case damageKeywordOverride(Keyword, Int, Int)
    /// Next outgoing Holy damage instance deals double and applies Burning, then consumes.
    case nextHolyStrike
    /// Next outgoing damaging hit (any keyword) deals double damage, then consumes.
    case nextStrikeDouble
    /// Next incoming attack that runs the dodge gate is a guaranteed dodge, then consumes.
    case evadeNextHit
    /// Spend all current Mana; gain that much Block.
    case convertManaToBlock
    /// Gain Block equal to current Mana (does not spend Mana).
    case shieldFromMana
    /// Gain Block equal to half current Mana (floor, does not spend Mana).
    case shieldFromHalfMana
    /// Gain Block equal to `gold / goldPerBlock` (floor).
    case shieldFromGold(goldPerBlock: Int)
    /// Battle-long maximum Mana bonus; also restores the same amount of current Mana.
    case maximumManaBonus(Int)
    /// Next outgoing damaging hit is a guaranteed critical, then consumes.
    case nextStrikeCritical
    /// Next enemy attack that hits you applies Frozen once, then consumes (fires even if Block absorbs).
    case freezeNextAttacker
    /// Deal Freeze damage to the next attacker, then consumes (fires even if Block absorbs).
    case freezeOnHit(Int)
    /// Multiply an existing DoT stack's potency (e.g. double Burn).
    case multiplyDoT(Keyword, Int)
    /// Immediate typed damage plus end-of-round pulses for `remainingTurns` after apply.
    case recurringDamage(Keyword, Int, Int)
    /// Revive a defeated ally to the given Health.
    case revive(Int)

    public static let bleedDoTTurnCount = 2
    /// Fraction of health lost healed when an ability with the Leech keyword deals damage.
    public static let abilityLeechPercent = 0.50
    /// Legacy timed-buff leech percent.
    public static let standardLeechPercent = 0.10
    public static let standardLeechDuration = 6
    public static let standardMarkedDuration = 6
    public static let standardMarkedBonus = 2
    public static let standardLeechBuff = Self.leech(.leech, standardLeechPercent, standardLeechDuration)

    /// DoT stack paired with a direct hit of the same keyword (`burn` / `poison` / `bleed`).
    public static func pairedDoT(keyword: Keyword, potency: Int) -> Self? {
        guard potency > 0 else { return nil }
        switch keyword {
        case .burn: return .burn(potency)
        case .poison: return .poison(potency)
        case .bleed: return .bleed(potency)
        default: return nil
        }
    }

    public var keyword: Keyword {
        switch self {
        case .burn: .burn
        case .poison: .poison
        case .bleed: .bleed
        case let .controlMeter(k, _, _): k
        case let .shield(k, _): k
        case let .instantHeal(k, _): k
        case let .leech(k, _, _): k
        case let .resourceGain(k, _): k
        case .drawCards: .physical
        case let .cleanse(k?): k
        case .cleanse(nil), .cleanseRandom: .health
        case let .purge(k?): k
        case .purge(nil), .purgeRandom: .purge
        case let .halveShield(k): k
        case .deathsDoor: .deathsDoor
        case .thorns: .physical
        case .marked: .physical
        case .criticalChanceBonus: .physical
        case .restoreManaOnHit: .mana
        case let .damageKeywordOverride(k, _, _): k
        case .nextHolyStrike: .holy
        case .nextStrikeDouble: .physical
        case .evadeNextHit: .dodge
        case .convertManaToBlock, .shieldFromMana, .shieldFromHalfMana, .shieldFromGold: .block
        case .maximumManaBonus: .mana
        case .nextStrikeCritical: .physical
        case .freezeNextAttacker: .freeze
        case .freezeOnHit: .freeze
        case let .multiplyDoT(k, _): k
        case let .recurringDamage(k, _, _): k
        case .revive: .health
        }
    }

    public var potency: Int? {
        switch self {
        case let .burn(p), let .poison(p), let .bleed(p): p
        case let .thorns(p): p
        case let .freezeOnHit(p): p
        case let .recurringDamage(_, p, _): p
        default: nil
        }
    }

    /// True for Burn stacks and Burn/Freeze recurring damage numbers Mana can empower.
    public var isManaEmpowerableBurnOrFreezeDamage: Bool {
        switch self {
        case .burn:
            true
        case let .recurringDamage(keyword, _, _):
            keyword == .burn || keyword == .freeze
        default:
            false
        }
    }

    /// Returns a copy with Burn/Freeze damage potency increased by `amount`; other effects unchanged.
    public func withManaEmpowerment(_ amount: Int = 1) -> Self {
        switch self {
        case let .burn(potency):
            .burn(potency + amount)
        case let .recurringDamage(keyword, potency, turns)
            where keyword == .burn || keyword == .freeze:
            .recurringDamage(keyword, potency + amount, turns)
        default:
            self
        }
    }

    public var durationTurns: Int {
        switch self {
        case .bleed: Self.bleedDoTTurnCount
        case let .leech(_, _, d): d
        case let .marked(_, d): d
        case let .criticalChanceBonus(_, d): d
        case let .restoreManaOnHit(_, d): d
        case let .damageKeywordOverride(_, _, d): d
        case let .recurringDamage(_, _, d): d
        case .burn, .poison, .instantHeal, .resourceGain, .drawCards, .cleanse, .cleanseRandom,
             .purge, .purgeRandom, .halveShield, .controlMeter, .deathsDoor,
             .shield, .thorns, .nextHolyStrike, .nextStrikeDouble, .evadeNextHit,
             .convertManaToBlock, .shieldFromMana, .shieldFromHalfMana, .shieldFromGold, .maximumManaBonus,
             .nextStrikeCritical, .freezeNextAttacker, .freezeOnHit, .multiplyDoT, .revive:
            0
        }
    }

    public func potencyAfterTurn(burnDecaySlowPercent: Double = 0) -> Int {
        switch self {
        case let .burn(potency):
            let normalNext = potency / 2
            let loss = potency - normalNext
            let adjustedLoss = CombatRounding.scaled(loss, multiplier: 1 - min(1, max(0, burnDecaySlowPercent)))
            return potency - adjustedLoss
        case let .poison(potency):
            let decrease = max(1, potency * 25 / 100)
            return potency - decrease
        default:
            return 0
        }
    }

    public var summary: String {
        EffectPresentation.applyPhrase(for: self)
    }

    public static func defaultTarget(for effect: Self) -> EffectTarget {
        switch effect {
        case .burn, .poison, .bleed, .controlMeter, .halveShield, .purge, .purgeRandom, .marked,
             .multiplyDoT, .recurringDamage:
            .abilityTarget
        case .instantHeal:
            .lowestHealthAlly
        case .revive:
            .defeatedAlly
        case .shield, .leech, .resourceGain, .drawCards, .cleanse, .cleanseRandom,
             .deathsDoor, .thorns, .criticalChanceBonus, .restoreManaOnHit,
             .damageKeywordOverride, .nextHolyStrike, .nextStrikeDouble, .evadeNextHit,
             .convertManaToBlock, .shieldFromMana, .shieldFromHalfMana, .shieldFromGold, .maximumManaBonus,
             .nextStrikeCritical, .freezeNextAttacker, .freezeOnHit:
            .actor
        }
    }
}
