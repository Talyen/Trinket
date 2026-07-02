import Foundation

/// Player-facing phrasing for `Effect` and `ActiveEffect`. Shared by battle
/// logs, ability description generation, and combat HUD summaries.
enum EffectPresentation {
    static func applyPhrase(for effect: Effect) -> String {
        switch effect {
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
        case let .cleanse(keyword?):
            return "cleanse \(keyword.statusAlias ?? keyword.rawValue)"
        case .cleanse(nil):
            return "cleanse all debuffs"
        case .cleanseRandom:
            return "cleanse a random debuff"
        case let .purge(keyword?):
            return "purge \(keyword.rawValue)"
        case .purge(nil):
            return "purge all buffs"
        case .purgeRandom:
            return "purge a random buff"
        case .halveMitigation(.armor):
            return "reduce enemy Armor by half"
        case .dodge:
            return "gain Dodge"
        default:
            return effect.keyword.rawValue
        }
    }

    static func activePhrase(for active: ActiveEffect) -> String {
        switch active.effect {
        case .burn, .poison:
            return active.effect.keyword.statusAlias ?? active.effect.keyword.rawValue
        case let .bleed(potency):
            let alias = active.effect.keyword.statusAlias ?? active.effect.keyword.rawValue
            return "\(alias): \(potency) damage"
        case let .prevention(keyword, _):
            return keyword.statusAlias ?? keyword.rawValue
        case let .preventionBuildup(keyword, amount, threshold):
            return "\(keyword.rawValue) Build-up: \(amount)/\(threshold)"
        case let .shield(keyword, buffer, _):
            return "\(keyword.rawValue): \(buffer) buffer"
        case let .mitigation(keyword, percent, _):
            return "\(keyword.rawValue): \(Int(percent * 100))%"
        case .leech:
            return "Leech"
        case .dodge:
            return "Dodge"
        case .instantHeal, .resourceGain, .cleanse, .cleanseRandom, .purge, .purgeRandom, .halveMitigation:
            return ""
        }
    }

    private static func statusPhrase(for keyword: Keyword, amount _: Int) -> String {
        let alias = keyword.statusAlias ?? keyword.rawValue
        return "applies \(alias)"
    }
}
