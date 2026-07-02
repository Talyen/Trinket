import Foundation

enum EffectTarget: Hashable {
    case abilityTarget
    case actor
    case enemy
    case hero
    case pet
}

struct TargetedEffect: Hashable {
    let effect: Effect
    let target: EffectTarget

    init(_ effect: Effect, target: EffectTarget? = nil) {
        self.effect = effect
        self.target = target ?? Effect.defaultTarget(for: effect)
    }
}

enum Effect: Hashable {
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
    case cleanse(Keyword?, Int)
    case dealDamage(Keyword, Int)
    case cleanseRandom
    case halveMitigation(Keyword)
    case dodge(Keyword, Int)

    static let bleedDoTTickCount = 3
    static let standardLeechPercent = 0.10
    static let standardLeechDuration = 6
    static let standardLeechBuff = Effect.leech(.leech, standardLeechPercent, standardLeechDuration)

    var keyword: Keyword {
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
        case let .cleanse(k?, _): return k
        case .cleanse(nil, _), .cleanseRandom: return .health
        case let .dealDamage(k, _): return k
        case let .halveMitigation(k): return k
        case .dodge: return .dodge
        }
    }

    var potency: Int? {
        switch self {
        case let .burn(p), let .poison(p), let .bleed(p): return p
        case let .dealDamage(_, amount): return amount
        default: return nil
        }
    }

    var durationTicks: Int {
        switch self {
        case .bleed: return Self.bleedDoTTickCount
        case let .prevention(_, d): return d
        case let .shield(_, _, d): return d
        case let .mitigation(_, _, d): return d
        case let .leech(_, _, d): return d
        case let .cleanse(_, d): return d
        case let .dodge(_, d): return d
        case .burn, .poison, .instantHeal, .resourceGain, .dealDamage, .cleanseRandom, .halveMitigation, .preventionBuildup: return 0
        }
    }

    func potencyAfterTick() -> Int {
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

    var summary: String {
        switch self {
        case let .burn(amount):
            return statusPhrase(for: .burn, amount: amount)
        case let .poison(amount):
            return statusPhrase(for: .poison, amount: amount)
        case let .bleed(amount):
            return statusPhrase(for: .bleed, amount: amount)
        case let .prevention(keyword, _):
            return "applies \(keyword.statusAlias ?? keyword.rawValue)"
        case let .preventionBuildup(keyword, _, _):
            return "applies \(keyword.rawValue) Build-up"
        case .shield(.block, _, _):
            return "gain Block"
        case .mitigation(.armor, _, _):
            return "gain Armor"
        case let .instantHeal(.health, amount):
            return "restore \(amount) Health"
        case .leech:
            return "gain Leech"
        case let .resourceGain(.gold, amount):
            return "gain \(amount) Gold"
        case let .cleanse(keyword?, _):
            return "cleanse \(keyword.statusAlias ?? keyword.rawValue)"
        case .cleanse(nil, _):
            return "cleanse all debuffs"
        case .cleanseRandom:
            return "cleanse a random debuff"
        case let .dealDamage(keyword, amount):
            return "deal \(amount) \(keyword.rawValue) damage"
        case .halveMitigation(.armor):
            return "reduce enemy Armor by half"
        case .dodge:
            return "gain Dodge"
        default:
            return keyword.rawValue
        }
    }

    private func statusPhrase(for keyword: Keyword, amount _: Int) -> String {
        let alias = keyword.statusAlias ?? keyword.rawValue
        return "applies \(alias)"
    }

    static func defaultTarget(for effect: Effect) -> EffectTarget {
        switch effect {
        case .burn, .poison, .bleed, .prevention, .preventionBuildup, .dealDamage, .halveMitigation:
            return .abilityTarget
        case .shield, .mitigation, .instantHeal, .leech, .resourceGain, .cleanse, .cleanseRandom, .dodge:
            return .actor
        }
    }
}
