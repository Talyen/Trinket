import Foundation

public enum EffectTarget: Hashable, Sendable {
    case abilityTarget
    case actor
    case enemy
    case hero
    case pet
}

public struct DamageComponent: Hashable, Sendable {
    public let amount: Int
    public let keyword: Keyword
    public let target: EffectTarget

    public init(_ amount: Int, keyword: Keyword = .physical, target: EffectTarget = .abilityTarget) {
        self.amount = amount
        self.keyword = keyword
        self.target = target
    }
}

public struct TargetedEffect: Hashable, Sendable {
    public let effect: Effect
    public let target: EffectTarget

    public init(_ effect: Effect, target: EffectTarget? = nil) {
        self.effect = effect
        self.target = target ?? Effect.defaultTarget(for: effect)
    }
}

public enum Effect: Hashable, Sendable {
    case burn(Int)
    case poison(Int)
    case bleed(Int)
    case prevention(Keyword, Int)
    case preventionBuildup(Keyword, Int, Int)
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
    case dodge(Keyword, Int)

    public static let bleedDoTTickCount = 3
    public static let standardLeechPercent = 0.10
    public static let standardLeechDuration = 6
    public static let standardLeechBuff = Effect.leech(.leech, standardLeechPercent, standardLeechDuration)

    public var keyword: Keyword {
        switch self {
        case .burn: return .burn
        case .poison: return .poison
        case .bleed: return .bleed
        case let .prevention(k, _): return k
        case let .preventionBuildup(k, _, _): return k
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
        case .dodge: return .dodge
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
        case let .prevention(_, d): return d
        case let .shield(_, _, d): return d
        case let .mitigation(_, _, d): return d
        case let .leech(_, _, d): return d
        case let .dodge(_, d): return d
        case .burn, .poison, .instantHeal, .resourceGain, .cleanse, .cleanseRandom,
             .purge, .purgeRandom, .halveMitigation, .preventionBuildup: return 0
        }
    }

    public func potencyAfterTick() -> Int {
        switch self {
        case let .burn(potency):
            return potency / 2
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
        case .burn, .poison, .bleed, .prevention, .preventionBuildup, .halveMitigation, .purge, .purgeRandom:
            return .abilityTarget
        case .shield, .mitigation, .instantHeal, .leech, .resourceGain, .cleanse, .cleanseRandom, .dodge:
            return .actor
        }
    }
}
