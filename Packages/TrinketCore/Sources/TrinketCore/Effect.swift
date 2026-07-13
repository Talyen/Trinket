import Foundation

public enum EffectTarget: Hashable, Sendable {
    case abilityTarget
    case actor
    case enemy
    case hero
    case companion
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
    /// Flat Block buffer. Stacks into a single pool; no timed duration.
    case shield(Keyword, Int)
    /// Flat Armor points. Stacks into a single pool; no timed duration.
    case mitigation(Keyword, Int)
    case instantHeal(Keyword, Int)
    case leech(Keyword, Double, Int)
    case resourceGain(Keyword, Int)
    /// Draw `Int` cards for the actor's deck (hero or companion). No-op for enemies.
    case drawCards(Int)
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
    /// Next outgoing Holy damage instance deals double and applies Burning, then consumes.
    case nextHolyStrike

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
        case .burn: .burn
        case .poison: .poison
        case .bleed: .bleed
        case let .controlMeter(k, _, _): k
        case let .shield(k, _): k
        case let .mitigation(k, _): k
        case let .instantHeal(k, _): k
        case let .leech(k, _, _): k
        case let .resourceGain(k, _): k
        case .drawCards: .physical
        case let .cleanse(k?): k
        case .cleanse(nil), .cleanseRandom: .health
        case let .purge(k?): k
        case .purge(nil), .purgeRandom: .purge
        case let .halveMitigation(k): k
        case .deathsDoor: .deathsDoor
        case .haste: .physical
        case let .thorns(k, _, _): k
        case .marked: .physical
        case .criticalChanceBonus: .physical
        case .restoreManaOnHit: .mana
        case let .damageKeywordOverride(k, _, _): k
        case .nextHolyStrike: .holy
        }
    }

    public var potency: Int? {
        switch self {
        case let .burn(p), let .poison(p), let .bleed(p): p
        default: nil
        }
    }

    public var durationTicks: Int {
        switch self {
        case .bleed: Self.bleedDoTTickCount
        case let .leech(_, _, d): d
        case let .haste(d): d
        case let .thorns(_, _, d): d
        case let .marked(_, d): d
        case let .criticalChanceBonus(_, d): d
        case let .restoreManaOnHit(_, d): d
        case let .damageKeywordOverride(_, _, d): d
        case .burn, .poison, .instantHeal, .resourceGain, .drawCards, .cleanse, .cleanseRandom,
             .purge, .purgeRandom, .halveMitigation, .controlMeter, .deathsDoor,
             .shield, .mitigation, .nextHolyStrike:
            0
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
            .abilityTarget
        case .shield, .mitigation, .instantHeal, .leech, .resourceGain, .drawCards, .cleanse, .cleanseRandom,
             .deathsDoor, .haste, .thorns, .criticalChanceBonus, .restoreManaOnHit,
             .damageKeywordOverride, .nextHolyStrike:
            .actor
        }
    }
}
