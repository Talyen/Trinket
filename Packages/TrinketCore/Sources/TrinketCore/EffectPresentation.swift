import Foundation

/// Player-facing phrasing for `Effect` and `ActiveEffect`. Shared by battle
/// logs, ability description generation, and combat HUD summaries.
public enum EffectPresentation {
    public static func applyPhrase(for effect: Effect) -> String {
        if let phrase = dotPhrase(for: effect) {
            return phrase
        }
        if let phrase = controlPhrase(for: effect) {
            return phrase
        }
        if let phrase = defensivePhrase(for: effect) {
            return phrase
        }
        if let phrase = restorationPhrase(for: effect) {
            return phrase
        }
        if let phrase = cleansePhrase(for: effect) {
            return phrase
        }
        if let phrase = purgePhrase(for: effect) {
            return phrase
        }
        if let phrase = mitigationPhrase(for: effect) {
            return phrase
        }
        if let phrase = utilityPhrase(for: effect) {
            return phrase
        }
        return effect.keyword.rawValue
    }

    public static func activePhrase(for active: ActiveEffect) -> String {
        if let phrase = activeStatusPhrase(for: active.effect) {
            return phrase
        }
        if let phrase = activeRecoveryPhrase(for: active.effect) {
            return phrase
        }

        switch active.effect {
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
        case .nextHolyStrike:
            return "Next Holy Strike"
        case .burn, .poison, .bleed, .controlMeter, .shield, .mitigation,
             .instantHeal, .resourceGain, .drawCards, .cleanse, .cleanseRandom, .purge, .purgeRandom, .halveMitigation:
            return ""
        }
    }

    private static func activeStatusPhrase(for effect: Effect) -> String? {
        switch effect {
        case .burn, .poison:
            return effect.keyword.statusAlias ?? effect.keyword.rawValue
        case let .bleed(potency):
            return bleedActivePhrase(potency: potency, keyword: effect.keyword)
        case let .controlMeter(keyword, amount, threshold):
            if amount >= threshold {
                return keyword.statusAlias ?? keyword.rawValue
            }
            return "\(keyword.rawValue) Build-up: \(amount)/\(threshold)"
        case let .shield(keyword, buffer):
            return "\(keyword.rawValue): \(buffer)"
        case let .mitigation(keyword, points):
            return "\(keyword.rawValue): \(points)"
        default:
            return nil
        }
    }

    private static func activeRecoveryPhrase(for effect: Effect) -> String? {
        switch effect {
        case .instantHeal, .resourceGain, .drawCards, .cleanse, .cleanseRandom, .purge, .purgeRandom, .halveMitigation:
            ""
        default:
            nil
        }
    }

    private static func dotPhrase(for effect: Effect) -> String? {
        switch effect {
        case let .burn(amount):
            statusPhrase(for: .burn, amount: amount)
        case let .poison(amount):
            statusPhrase(for: .poison, amount: amount)
        case let .bleed(amount):
            statusPhrase(for: .bleed, amount: amount)
        default:
            nil
        }
    }

    private static func controlPhrase(for effect: Effect) -> String? {
        switch effect {
        case let .controlMeter(keyword, _, _):
            "builds toward \(keyword.statusAlias ?? keyword.rawValue)"
        default:
            nil
        }
    }

    private static func defensivePhrase(for effect: Effect) -> String? {
        switch effect {
        case let .shield(.block, buffer):
            "gain \(buffer) Block"
        case let .mitigation(.armor, points):
            "gain \(points) Armor"
        case .haste:
            "gain Haste"
        case .thorns:
            "gain Thorns"
        case .nextHolyStrike:
            "your next Holy attack deals double damage and applies Burning"
        default:
            nil
        }
    }

    private static func restorationPhrase(for effect: Effect) -> String? {
        switch effect {
        case let .instantHeal(.health, amount):
            "restore \(amount) Health"
        case .leech:
            "gain Leech"
        case let .resourceGain(.gold, amount):
            "steal \(amount) Gold"
        case let .resourceGain(.mana, amount):
            "restore \(amount) Mana"
        case let .drawCards(count):
            count == 1 ? "draw 1 card" : "draw \(count) cards"
        default:
            nil
        }
    }

    private static func cleansePhrase(for effect: Effect) -> String? {
        switch effect {
        case let .cleanse(keyword?):
            "cleanse \(keyword.statusAlias ?? keyword.rawValue)"
        case .cleanse(nil):
            "cleanse all debuffs"
        case .cleanseRandom:
            "cleanse a random debuff"
        default:
            nil
        }
    }

    private static func purgePhrase(for effect: Effect) -> String? {
        switch effect {
        case let .purge(keyword?):
            "purge \(keyword.rawValue)"
        case .purge(nil):
            "purge all buffs"
        case .purgeRandom:
            "purge a random buff"
        default:
            nil
        }
    }

    private static func mitigationPhrase(for effect: Effect) -> String? {
        guard case .halveMitigation(.armor) = effect else { return nil }
        return "halve the enemy's Armor"
    }

    private static func utilityPhrase(for effect: Effect) -> String? {
        switch effect {
        case .marked:
            "mark the enemy"
        case let .criticalChanceBonus(percent, _):
            "gain +\(Int(percent * 100))% Critical chance"
        case let .restoreManaOnHit(amount, _):
            "restore \(amount) Mana when you take damage"
        case let .damageKeywordOverride(keyword, bonus, durationTicks):
            "your attacks become \(keyword.rawValue) damage and deal +\(bonus) \(durationPhrase(ticks: durationTicks))"
        default:
            nil
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
