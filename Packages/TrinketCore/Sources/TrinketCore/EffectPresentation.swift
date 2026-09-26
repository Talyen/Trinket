import Foundation

public enum EffectPresentation {
    // swiftlint:disable function_body_length - exhaustive effect descriptions must reject missing cases at compile time
    public static func applyPhrase(for effect: Effect) -> String {
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
            turns == 1
                ? "deal \(amount) \(keyword.rawValue) damage this turn and next"
                : "deal \(amount) \(keyword.rawValue) damage now and \(moreTurnsPhrase(turns: turns))"
        case let .blessedAegis(block, holyDamage):
            "each ally gains \(block) Block and deals \(holyDamage) Holy damage the next time they're hit"
        case let .avatar(holyDamage, blockPerTurn, turns):
            blockPerTurn > 0
                ? "deal \(holyDamage) Holy damage and gain \(blockPerTurn) Block now and \(moreTurnsPhrase(turns: turns))"
                : "deal \(holyDamage) Holy damage now and \(moreTurnsPhrase(turns: turns))"
        case let .multiplyDoT(keyword, factor):
            factor == 2
                ? "double the enemy's \(keyword.rawValue)"
                : "multiply the enemy's \(keyword.rawValue) by \(factor)"
        case let .detonateDoT(keyword, factor):
            factor == 2
                ? "detonate all remaining \(keyword.rawValue) at once, doubled"
                : "detonate all remaining \(keyword.rawValue) at once with ×\(factor) damage"
        case let .controlMeter(keyword, _, _):
            "builds toward \(keyword.statusName)"
        case .freezeNextAttacker:
            "Freeze the next attacker"
        case let .onHitDamage(keyword, amount):
            "deal \(amount) \(keyword.rawValue) damage next time you're hit"
        case let .multiplyControlMeter(keyword, factor):
            factor == 2
                ? "double the enemy's \(keyword.rawValue) build-up"
                : "multiply the enemy's \(keyword.rawValue) build-up by \(factor)"
        case let .shield(keyword, buffer):
            "gain \(buffer) \(keyword.rawValue)"
        case let .thorns(stacks):
            "gain \(stacks) Thorns"
        case let .thornsFromBlockFraction(divisor, _):
            "gain Thorns equal to \(divisor == 2 ? "half" : "1/\(divisor)") your Block"
        case .nextHolyStrike:
            "your next Holy attack deals double damage and applies Burning"
        case .nextStrikeDouble:
            "your next attack deals double damage"
        case let .nextBurnBonus(bonus):
            "your next Burn attack deals +\(bonus) damage"
        case .nextStrikeCritical:
            "your next attack is a guaranteed Critical Hit"
        case .nextStrikeLeech:
            "your next attack Leeches"
        case let .nextStrikeDamageKeywordOverride(keyword):
            "your next attack deals \(keyword.rawValue) damage"
        case let .partyDamageBonus(amount):
            "your partner's next attack deals \(amount) additional damage"
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
        case let .cleanse(keyword?):
            "cleanse \(keyword.statusName)"
        case .cleanse(nil):
            "cleanse all debuffs"
        case let .cleanseHealPerDebuff(healPerRemoved):
            "cleanse all debuffs and restore \(healPerRemoved) Health for each debuff cleansed"
        case let .panacea(baseHeal, healPerDebuff):
            "cleanse all debuffs and restore \(baseHeal) Health plus \(healPerDebuff) Health for each debuff cleansed"
        case .cleanseRandom:
            "cleanse a harmful status effect"
        case let .purge(keyword?):
            "purge \(keyword.rawValue)"
        case .purge(nil):
            "purge all buffs"
        case .purgeRandom:
            "purge a random buff"
        case let .halveShield(keyword):
            "halve the enemy's \(keyword.rawValue)"
        case .marked:
            "mark the enemy"
        case let .criticalChanceBonus(percent, _):
            "gain +\(Int(percent * 100))% Critical chance"
        case let .restoreManaOnHit(amount, _):
            "restore \(amount) Mana when you take damage"
        case let .damageKeywordOverride(keyword, bonus, durationTurns):
            "your attacks become \(keyword.rawValue) damage and deal +\(bonus) damage \(durationPhrase(turns: durationTurns))"
        case let .damageReductionPercent(percent, durationTurns):
            "reduces damage dealt by \(Int((percent * 100).rounded()))% \(durationPhrase(turns: durationTurns))"
        case let .healingReductionPercent(percent, durationTurns):
            "reduces the Health restored to enemies by \(Int((percent * 100).rounded()))% \(durationPhrase(turns: durationTurns))"
        case let .damageReductionFlat(amount, durationTurns):
            "reduces damage dealt by \(amount) \(durationPhrase(turns: durationTurns))"
        }
    }

    // swiftlint:enable function_body_length

    public static func requiredBattleSummaryPhrase(for effect: Effect) -> String {
        guard let phrase = battleSummaryPhrase(for: effect) else {
            preconditionFailure("Every flag effect needs a battle summary phrase; missing \(effect)")
        }
        return phrase
    }

    public static func battleSummaryPhrase(for effect: Effect) -> String? {
        switch effect {
        case .nextHolyStrike:
            "Holy Strike: Next attack deals double Holy damage and applies Burning."
        case .nextStrikeDouble:
            "Double Strike: Next attack deals double damage."
        case .evadeNextHit:
            "Evasion: Dodges the next attack."
        case .nextStrikeCritical:
            "Critical Focus: Next attack is a guaranteed Critical Hit."
        case .nextStrikeLeech:
            "Leech Focus: Next attack Leeches."
        case let .nextStrikeDamageKeywordOverride(keyword):
            keyword == .holy
                ? "Avatar: Next attack deals Holy damage."
                : "Next attack deals \(keyword.rawValue) damage."
        case .partyDamageBonus:
            "Sniff Out: Partner's next attack deals additional damage."
        case .freezeNextAttacker:
            "Glacial Ward: Freezes the next attacker."
        default:
            nil
        }
    }

    private static func durationPhrase(turns: Int) -> String {
        turnPhrase(turns: turns, includeMore: false)
    }

    private static func moreTurnsPhrase(turns: Int) -> String {
        turnPhrase(turns: turns, includeMore: true)
    }

    private static func turnPhrase(turns: Int, includeMore: Bool) -> String {
        let more = includeMore ? "more " : ""
        return turns == 1 ? "for 1 \(more)turn" : "for \(turns) \(more)turns"
    }

    private static func statusPhrase(for keyword: Keyword, amount: Int) -> String {
        "applies \(keyword.statusName): \(amount) damage"
    }
}
