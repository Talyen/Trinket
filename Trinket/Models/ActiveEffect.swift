import Foundation

struct ActiveEffect: Identifiable, Hashable {
    let id: Int
    var effect: Effect
    var remainingTicks: Int
    var sourceActorID: String?

    init(id: Int, effect: Effect, remainingTicks: Int, sourceActorID: String? = nil) {
        self.id = id
        self.effect = effect
        self.remainingTicks = remainingTicks
        self.sourceActorID = sourceActorID
    }

    var keyword: Keyword {
        effect.keyword
    }

    var summary: String {
        switch effect {
        case .burn, .poison:
            return effect.keyword.statusAlias ?? effect.keyword.rawValue
        case let .bleed(potency):
            return "\(effect.keyword.statusAlias ?? effect.keyword.rawValue): \(potency) damage"
        case let .prevention(keyword, _):
            return keyword.statusAlias ?? keyword.rawValue
        case let .preventionBuildup(keyword, amount, threshold):
            return "\(keyword.rawValue) Build-up: \(amount)/\(threshold)"
        case let .shield(k, b, _):
            return "\(k.rawValue): \(b) buffer"
        case let .mitigation(k, p, _):
            return "\(k.rawValue): \(Int(p * 100))%"
        case .leech:
            return "Leech"
        case .cleanse:
            return "Cleanse"
        case .dodge:
            return "Dodge"
        case .instantHeal, .resourceGain, .dealDamage, .cleanseRandom, .halveMitigation:
            return ""
        }
    }
}

struct EffectSummary: Identifiable, Equatable, Hashable {
    let keyword: Keyword
    let text: String

    var id: Keyword {
        keyword
    }
}
