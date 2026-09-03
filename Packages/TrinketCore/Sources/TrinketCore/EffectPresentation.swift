import Foundation

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
        if let phrase = cleanseOrPurgePhrase(for: effect) {
            return phrase
        }
        if let phrase = shieldHalvePhrase(for: effect) {
            return phrase
        }
        if let phrase = utilityPhrase(for: effect) {
            return phrase
        }
        return effect.keyword.rawValue
    }

    private static func dotPhrase(for effect: Effect) -> String? {
        switch effect {
        case let .burn(amount):
            statusPhrase(for: .burn, amount: amount)
        case let .poison(amount):
            statusPhrase(for: .poison, amount: amount)
        case let .bleed(amount):
            statusPhrase(for: .bleed, amount: amount)
        case let .hemorrhage(amount):
            "the next time they attack, they take \(amount) Bleed damage"
        case let .recurringDamage(keyword, amount, turns):
            "deal \(amount) \(keyword.rawValue) damage each turn \(durationPhrase(turns: turns))"
        case let .avatar(holyDamage, blockPerTurn, turns):
            "deal \(holyDamage) Holy damage and gain \(blockPerTurn) Block each turn \(durationPhrase(turns: turns))"
        case let .multiplyDoT(keyword, factor):
            factor == 2
                ? "double the enemy's \(keyword.rawValue)"
                : "multiply the enemy's \(keyword.rawValue) by \(factor)"
        default:
            nil
        }
    }

    private static func controlPhrase(for effect: Effect) -> String? {
        switch effect {
        case let .controlMeter(keyword, _, _):
            "builds toward \(keyword.statusAlias ?? keyword.rawValue)"
        case .freezeNextAttacker:
            "Freeze the next attacker"
        case let .onHitDamage(keyword, amount):
            "deal \(amount) \(keyword.rawValue) damage next time you're hit"
        default:
            nil
        }
    }

    private static func defensivePhrase(for effect: Effect) -> String? {
        switch effect {
        case let .shield(.block, buffer):
            "gain \(buffer) Block"
        case let .shield(keyword, buffer):
            "gain \(buffer) \(keyword.rawValue)"
        case let .thorns(stacks):
            "gain \(stacks) Thorns"
        case .nextHolyStrike:
            "your next Holy attack deals double damage and applies Burning"
        case .nextStrikeDouble:
            "your next attack deals double damage"
        case let .nextBurnBonus(bonus):
            "your next Burn attack deals +\(bonus) damage"
        case .nextStrikeCritical:
            "your next attack is a guaranteed Critical Hit"
        case .evadeNextHit:
            "dodge the next attack"
        case .convertManaToBlock:
            "convert all Mana into Block"
        case .shieldFromMana:
            "gain Block equal to your Mana"
        case .shieldFromHalfMana:
            "gain Block equal to half your Mana"
        case let .shieldFromGold(goldPerBlock):
            "gain 1 Block for every \(goldPerBlock) Gold"
        case .deathsDoor:
            "survive fatal blows at 1 Health"
        default:
            nil
        }
    }

    private static func restorationPhrase(for effect: Effect) -> String? {
        switch effect {
        case let .instantHeal(.health, amount):
            "restore \(amount) Health"
        case let .instantHeal(keyword, amount):
            "restore \(amount) \(keyword.rawValue)"
        case let .resourceGain(.gold, amount):
            "steal \(amount) Gold"
        case let .resourceGain(.mana, amount):
            "restore \(amount) Mana"
        case let .resourceGain(keyword, amount):
            "gain \(amount) \(keyword.rawValue)"
        case let .drawCards(count):
            count == 1 ? "draw 1 card" : "draw \(count) cards"
        case let .drawAndPlayCards(count):
            count == 1 ? "draw and play 1 card" : "draw and play \(count) cards"
        case let .maximumManaBonus(amount):
            "increase Maximum Mana by \(amount)"
        case let .revive(amount):
            "revive an Ally to \(amount) Health"
        default:
            nil
        }
    }

    private static func cleanseOrPurgePhrase(for effect: Effect) -> String? {
        switch effect {
        case let .cleanse(keyword?):
            "cleanse \(keyword.statusAlias ?? keyword.rawValue)"
        case .cleanse(nil):
            "cleanse all debuffs"
        case let .cleanseHealPerDebuff(healPerRemoved):
            "cleanse all debuffs and restore \(healPerRemoved) Health for each debuff cleansed"
        case .cleanseRandom:
            "cleanse a status effect"
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

    private static func shieldHalvePhrase(for effect: Effect) -> String? {
        switch effect {
        case .halveShield(.block):
            "halve the enemy's Block"
        case let .halveShield(keyword):
            "halve the enemy's \(keyword.rawValue)"
        default:
            nil
        }
    }

    private static func utilityPhrase(for effect: Effect) -> String? {
        switch effect {
        case .marked:
            "mark the enemy"
        case let .criticalChanceBonus(percent, _):
            "gain +\(Int(percent * 100))% Critical chance"
        case let .restoreManaOnHit(amount, _):
            "restore \(amount) Mana when you take damage"
        case let .damageKeywordOverride(keyword, bonus, durationTurns):
            "your attacks become \(keyword.rawValue) damage and deal +\(bonus) \(durationPhrase(turns: durationTurns))"
        case let .damageReductionPercent(percent, durationTurns):
            "reduces damage dealt by \(Int((percent * 100).rounded()))% \(durationPhrase(turns: durationTurns))"
        case let .damageReductionFlat(amount, durationTurns):
            "reduces damage dealt by \(amount) \(durationPhrase(turns: durationTurns))"
        default:
            nil
        }
    }

    private static func durationPhrase(turns: Int) -> String {
        turns == 1 ? "for 1 turn" : "for \(turns) turns"
    }

    private static func statusPhrase(for keyword: Keyword, amount: Int) -> String {
        let alias = keyword.statusAlias ?? keyword.rawValue
        return "applies \(alias): \(amount) damage"
    }
}
