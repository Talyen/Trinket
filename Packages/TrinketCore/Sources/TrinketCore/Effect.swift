import Foundation

public enum EffectTarget: Hashable, Sendable {
    case abilityTarget
    case actor
    case enemy
    case hero
    case pet
    case lowestHealthAlly
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
    case shield(Keyword, Int, Int)
    case mitigation(Keyword, Double, Int)
    case instantHeal(Keyword, Int)
    case leech(Keyword, Double, Int)
    case resourceGain(Keyword, Int)
    case cleanse(Keyword?)
    case cleanseRandom
    case purge(Keyword?)
    case purgeRandom
    case halveMitigation(Keyword)
    case deathsDoor
    case haste(Int)
    case thorns(Keyword, Int, Int)
    case marked(Int, Int)
    case criticalChanceBonus(Double, Int)
    case restoreManaOnHit(Int, Int)
    /// Forces outgoing damage keywords to `keyword` and adds `bonus` damage for `durationTicks`.
    case damageKeywordOverride(Keyword, Int, Int)

    public static let bleedDoTTickCount = 3
    /// Fraction of health lost healed when an ability with the Leech keyword deals damage.
    public static let abilityLeechPercent = 0.50
    /// Legacy timed-buff leech percent (affix/packbond reactions that still grant a buff).
    public static let standardLeechPercent = 0.10
    public static let standardLeechDuration = 6
    public static let standardThornsDuration = 6
    public static let standardHasteDuration = 4
    public static let standardMarkedDuration = 6
    public static let standardMarkedBonus = 2
    public static let standardLeechBuff = Effect.leech(.leech, standardLeechPercent, standardLeechDuration)

    public var keyword: Keyword {
        switch self {
        case .burn: return .burn
        case .poison: return .poison
        case .bleed: return .bleed
        case let .controlMeter(k, _, _): return k
        case let .shield(k, _, _): return k
        case let .mitigation(k, _, _): return k
        case let .instantHeal(k, _): return k
        case let .leech(k, _, _): return k
        case let .resourceGain(k, _): return k
        case let .cleanse(k?): return k
        case .cleanse(nil), .cleanseRandom: return .health
        case let .purge(k?): return k
        case .purge(nil), .purgeRandom: return .purge
        case let .halveMitigation(k): return k
        case .deathsDoor: return .deathsDoor
        case .haste: return .physical
        case let .thorns(k, _, _): return k
        case .marked: return .physical
        case .criticalChanceBonus: return .physical
        case .restoreManaOnHit: return .mana
        case let .damageKeywordOverride(k, _, _): return k
        }
    }

    public var potency: Int? {
        switch self {
        case let .burn(p), let .poison(p), let .bleed(p): return p
        default: return nil
        }
    }

    public var durationTicks: Int {
        switch self {
        case .bleed: return Self.bleedDoTTickCount
        case let .shield(_, _, d): return d
        case let .mitigation(_, _, d): return d
        case let .leech(_, _, d): return d
        case let .haste(d): return d
        case let .thorns(_, _, d): return d
        case let .marked(_, d): return d
        case let .criticalChanceBonus(_, d): return d
        case let .restoreManaOnHit(_, d): return d
        case let .damageKeywordOverride(_, _, d): return d
        case .burn, .poison, .instantHeal, .resourceGain, .cleanse, .cleanseRandom,
             .purge, .purgeRandom, .halveMitigation, .controlMeter, .deathsDoor: return 0
        }
    }

    public func potencyAfterTick(burnDecaySlowPercent: Double = 0) -> Int {
        switch self {
        case let .burn(potency):
            let normalNext = potency / 2
            let loss = potency - normalNext
            let adjustedLoss = Int(floor(Double(loss) * (1 - min(1, max(0, burnDecaySlowPercent)))))
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

    public static func defaultTarget(for effect: Effect) -> EffectTarget {
        switch effect {
        case .burn, .poison, .bleed, .controlMeter, .halveMitigation, .purge, .purgeRandom, .marked:
            return .abilityTarget
        case .shield, .mitigation, .instantHeal, .leech, .resourceGain, .cleanse, .cleanseRandom,
             .deathsDoor, .haste, .thorns, .criticalChanceBonus, .restoreManaOnHit, .damageKeywordOverride:
            return .actor
        }
    }
}
