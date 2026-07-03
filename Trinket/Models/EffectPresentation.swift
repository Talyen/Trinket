import Foundation

/// Player-facing phrasing for `Effect` and `ActiveEffect`. Shared by battle
/// logs, ability description generation, and combat HUD summaries.
enum EffectPresentation {
    static func applyPhrase(for effect: Effect) -> String {
        if let phrase = dotPhrase(for: effect) { return phrase }
        if let phrase = preventionPhrase(for: effect) { return phrase }
        if let phrase = defensivePhrase(for: effect) { return phrase }
        if let phrase = restorationPhrase(for: effect) { return phrase }
        if let phrase = cleansePhrase(for: effect) { return phrase }
        if let phrase = purgePhrase(for: effect) { return phrase }
        if let phrase = mitigationPhrase(for: effect) { return phrase }
        if case .dodge = effect { return "gain Dodge" }
        return effect.keyword.rawValue
    }

    static func activePhrase(for active: ActiveEffect) -> String {
        switch active.effect {
        case .burn, .poison:
            return active.effect.keyword.statusAlias ?? active.effect.keyword.rawValue
        case let .bleed(potency):
            return bleedActivePhrase(potency: potency, keyword: active.effect.keyword)
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

    private static func dotPhrase(for effect: Effect) -> String? {
        switch effect {
        case let .burn(amount):
            return statusPhrase(for: .burn, amount: amount)
        case let .poison(amount):
            return statusPhrase(for: .poison, amount: amount)
        case let .bleed(amount):
            return statusPhrase(for: .bleed, amount: amount)
        default:
            return nil
        }
    }

    private static func preventionPhrase(for effect: Effect) -> String? {
        switch effect {
        case let .prevention(keyword, _):
            return "applies \(keyword.statusAlias ?? keyword.rawValue)"
        case let .preventionBuildup(keyword, _, _):
            return "applies \(keyword.rawValue) Build-up"
        default:
            return nil
        }
    }

    private static func defensivePhrase(for effect: Effect) -> String? {
        switch effect {
        case .shield(.block, _, _):
            return "gain Block"
        case .mitigation(.armor, _, _):
            return "gain Armor"
        default:
            return nil
        }
    }

    private static func restorationPhrase(for effect: Effect) -> String? {
        switch effect {
        case let .instantHeal(.health, amount):
            return "restore \(amount) Health"
        case .leech:
            return "gain Leech"
        case let .resourceGain(.gold, amount):
            return "gain \(amount) Gold"
        default:
            return nil
        }
    }

    private static func cleansePhrase(for effect: Effect) -> String? {
        switch effect {
        case let .cleanse(keyword?):
            return "cleanse \(keyword.statusAlias ?? keyword.rawValue)"
        case .cleanse(nil):
            return "cleanse all debuffs"
        case .cleanseRandom:
            return "cleanse a random debuff"
        default:
            return nil
        }
    }

    private static func purgePhrase(for effect: Effect) -> String? {
        switch effect {
        case let .purge(keyword?):
            return "purge \(keyword.rawValue)"
        case .purge(nil):
            return "purge all buffs"
        case .purgeRandom:
            return "purge a random buff"
        default:
            return nil
        }
    }

    private static func mitigationPhrase(for effect: Effect) -> String? {
        guard case .halveMitigation(.armor) = effect else { return nil }
        return "reduce enemy Armor by half"
    }

    private static func statusPhrase(for keyword: Keyword, amount _: Int) -> String {
        let alias = keyword.statusAlias ?? keyword.rawValue
        return "applies \(alias)"
    }

    private static func bleedActivePhrase(potency: Int, keyword: Keyword) -> String {
        let alias = keyword.statusAlias ?? keyword.rawValue
        return "\(alias): \(potency) damage"
    }
}
