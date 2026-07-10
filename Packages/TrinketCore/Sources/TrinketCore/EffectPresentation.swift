import Foundation

/// Player-facing phrasing for `Effect` and `ActiveEffect`. Shared by battle
/// logs, ability description generation, and combat HUD summaries.
public enum EffectPresentation {
    public static func applyPhrase(for effect: Effect) -> String {
        if let phrase = dotPhrase(for: effect) { return phrase }
        if let phrase = controlPhrase(for: effect) { return phrase }
        if let phrase = defensivePhrase(for: effect) { return phrase }
        if let phrase = restorationPhrase(for: effect) { return phrase }
        if let phrase = cleansePhrase(for: effect) { return phrase }
        if let phrase = purgePhrase(for: effect) { return phrase }
        if let phrase = mitigationPhrase(for: effect) { return phrase }
        if let phrase = utilityPhrase(for: effect) { return phrase }
        return effect.keyword.rawValue
    }

    public static func activePhrase(for active: ActiveEffect) -> String {
        switch active.effect {
        case .burn, .poison:
            return active.effect.keyword.statusAlias ?? active.effect.keyword.rawValue
        case let .bleed(potency):
            return bleedActivePhrase(potency: potency, keyword: active.effect.keyword)
        case let .controlMeter(keyword, amount, threshold):
            if amount >= threshold {
                return keyword.statusAlias ?? keyword.rawValue
            }
            return "\(keyword.rawValue) Build-up: \(amount)/\(threshold)"
        case let .shield(keyword, buffer, _):
            return "\(keyword.rawValue): \(buffer) buffer"
        case let .mitigation(keyword, percent, _):
            return "\(keyword.rawValue): \(Int(percent * 100))%"
        case .leech:
            return "Leech"
        case .deathsDoor:
            return "Death's Door"
        case .haste:
            return "Hasted"
        case .thorns:
            return "Thorns"
        case .marked:
            return "Marked"
        case .criticalChanceBonus:
            return "Focused"
        case .restoreManaOnHit:
            return "Mana Shield"
        case .damageKeywordOverride:
            return "Consecrated"
        case .instantHeal, .resourceGain, .drawCards, .cleanse, .cleanseRandom, .purge, .purgeRandom, .halveMitigation:
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

    private static func controlPhrase(for effect: Effect) -> String? {
        switch effect {
        case let .controlMeter(keyword, _, _):
            return "builds toward \(keyword.statusAlias ?? keyword.rawValue)"
        default:
            return nil
        }
    }

    private static func defensivePhrase(for effect: Effect) -> String? {
        switch effect {
        case let .shield(.block, buffer, durationTicks):
            return "gain \(buffer) Block \(durationPhrase(ticks: durationTicks))"
        case let .mitigation(.armor, percent, durationTicks):
            return "gain \(Int(percent * 100))% Armor \(durationPhrase(ticks: durationTicks))"
        case .haste:
            return "gain Haste"
        case .thorns:
            return "gain Thorns"
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
            return "steal \(amount) Gold"
        case let .resourceGain(.mana, amount):
            return "restore \(amount) Mana"
        case let .drawCards(count):
            return count == 1 ? "draw 1 card" : "draw \(count) cards"
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
        return "halve the enemy's Armor"
    }

    private static func utilityPhrase(for effect: Effect) -> String? {
        switch effect {
        case .marked:
            return "mark the enemy"
        case let .criticalChanceBonus(percent, _):
            return "gain +\(Int(percent * 100))% Critical chance"
        case let .restoreManaOnHit(amount, _):
            return "restore \(amount) Mana when you take damage"
        case let .damageKeywordOverride(keyword, bonus, durationTicks):
            return "your attacks become \(keyword.rawValue) damage and deal +\(bonus) \(durationPhrase(ticks: durationTicks))"
        default:
            return nil
        }
    }

    /// Duration values are player-facing turns (1 former tick = 1 turn).
    private static func durationPhrase(ticks: Int) -> String {
        ticks == 1 ? "for 1 turn" : "for \(ticks) turns"
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
