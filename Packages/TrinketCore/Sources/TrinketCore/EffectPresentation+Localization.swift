import Foundation

public enum EffectPresentation {
    // swiftlint:disable:next function_body_length - Keep the complete Effect-to-resource mapping exhaustive beside its typed semantic values
    public static func localizedDescription(for effect: Effect, locale: Locale) -> LocalizedGameText {
        let resource: LocalizedStringResource
        var values: [String: Int] = [:]
        switch effect {
        case let .burn(amount):
            resource = L10n.effect_burn(amount); values = ["damage": amount]
        case let .poison(amount):
            resource = L10n.effect_poison(amount); values = ["damage": amount]
        case let .bleed(amount):
            resource = L10n.effect_bleed(amount); values = ["damage": amount]
        case let .hemorrhage(amount):
            resource = L10n.effect_hemorrhage(amount); values = ["damage": amount]
        case let .recurringDamage(keyword, amount, turns):
            resource = turns == 1 ? L10n.effect_recurring_one(amount, keyword.markedName(locale: locale))
                : L10n.effect_recurring_many(amount, keyword.markedName(locale: locale), turns)
            values = ["damage": amount, "turns": turns]
        case let .blessedAegis(block, holyDamage):
            resource = L10n.effect_blessed_aegis(block, holyDamage); values = ["block": block, "damage": holyDamage]
        case let .avatar(holyDamage, blockPerTurn, turns):
            if blockPerTurn > 0 {
                resource = turns == 1 ? L10n.effect_avatar_block_single(holyDamage, blockPerTurn, turns) : L10n.effect_avatar_block(
                    holyDamage,
                    blockPerTurn,
                    turns,
                )
            } else {
                resource = turns == 1 ? L10n.effect_avatar_single(holyDamage, turns) : L10n.effect_avatar(holyDamage, turns)
            }
            values = ["damage": holyDamage, "block": blockPerTurn, "turns": turns]
        case let .multiplyDoT(keyword, factor):
            resource = L10n.effect_multiply_dot(keyword.markedName(locale: locale), factor); values = ["factor": factor]
        case let .detonateDoT(keyword, factor):
            resource = L10n.effect_detonate_dot(keyword.markedName(locale: locale), factor); values = ["factor": factor]
        case let .controlMeter(keyword, _, _):
            resource = L10n.effect_control(keyword.markedName(locale: locale))
        case .freezeNextAttacker:
            resource = L10n.effect_freeze_attacker
        case let .onHitDamage(keyword, amount):
            resource = L10n.effect_on_hit(amount, keyword.markedName(locale: locale)); values = ["damage": amount]
        case let .multiplyControlMeter(keyword, factor):
            resource = L10n.effect_multiply_control(keyword.markedName(locale: locale), factor); values = ["factor": factor]
        case let .shield(keyword, amount):
            resource = L10n.effect_shield(amount, keyword.markedName(locale: locale)); values = ["amount": amount]
        case let .thorns(amount):
            resource = L10n.effect_shield(amount, Keyword.thorns.markedName(locale: locale)); values = ["amount": amount]
        case let .thornsFromBlockFraction(divisor, _):
            resource = divisor == 2 ? L10n.effect_block_thorns_half : L10n.effect_block_thorns_fraction(divisor)
            values = ["divisor": divisor]
        case .nextHolyStrike: resource = L10n.effect_next_holy
        case .nextStrikeDouble: resource = L10n.effect_next_double
        case .playNextCardTwice: resource = L10n.effect_next_twice
        case let .nextBurnBonus(amount):
            resource = L10n.effect_next_burn(amount); values = ["damage": amount]
        case .nextStrikeCritical: resource = L10n.effect_next_critical
        case .nextStrikeLeech: resource = L10n.effect_next_leech
        case let .nextStrikeDamageKeywordOverride(keyword): resource = L10n.effect_next_keyword(keyword.markedName(locale: locale))
        case let .partyDamageBonus(amount):
            resource = L10n.effect_party_damage(amount); values = ["damage": amount]
        case .evadeNextHit: resource = L10n.effect_evade
        case .convertManaToBlock: resource = L10n.effect_mana_block
        case .shieldFromMana: resource = L10n.effect_block_mana
        case .shieldFromHalfMana: resource = L10n.effect_block_half_mana
        case let .shieldFromGold(amount):
            resource = L10n.effect_block_gold(amount); values = ["gold": amount]
        case .deathsDoor: resource = L10n.effect_deaths_door
        case let .instantHeal(keyword, amount):
            resource = L10n.effect_heal(amount, keyword.markedName(locale: locale)); values = ["amount": amount]
        case let .resourceGain(keyword, amount):
            resource = keyword == .gold ? L10n.effect_steal_gold(amount) : L10n.effect_heal(amount, keyword.markedName(locale: locale))
            values = ["gold": amount, "amount": amount]
        case let .drawCards(count):
            resource = L10n.effect_draw(count); values = ["cards": count]
        case let .drawAndPlayCards(count):
            resource = L10n.effect_draw_play(count); values = ["cards": count]
        case let .maximumManaBonus(amount):
            resource = L10n.effect_max_mana(amount); values = ["mana": amount]
        case let .revive(amount):
            resource = L10n.effect_revive(amount); values = ["health": amount]
        case let .cleanse(keyword?): resource = L10n.effect_cleanse_keyword(keyword.markedName(locale: locale))
        case .cleanse(nil): resource = L10n.effect_cleanse_all
        case let .cleanseHealPerDebuff(amount):
            resource = L10n.effect_cleanse_heal(amount); values = ["health": amount]
        case let .panacea(baseHeal, healPerDebuff):
            resource = L10n.effect_panacea(baseHeal, healPerDebuff); values = ["base_health": baseHeal, "health_per_debuff": healPerDebuff]
        case .cleanseRandom: resource = L10n.effect_cleanse_random
        case let .purge(keyword?): resource = L10n.effect_purge_keyword(keyword.markedName(locale: locale))
        case .purge(nil): resource = L10n.effect_purge_all
        case .purgeRandom: resource = L10n.effect_purge_random
        case let .halveShield(keyword): resource = L10n.effect_halve_shield(keyword.markedName(locale: locale))
        case .marked: resource = L10n.effect_marked
        case let .criticalChanceBonus(percent, _):
            let amount = CombatRounding.rounded((percent * 100).rounded(.towardZero))
            resource = L10n.effect_critical(amount); values = ["chance": amount]
        case let .restoreManaOnHit(amount, _):
            resource = L10n.effect_restore_mana_hit(amount); values = ["mana": amount]
        case let .damageKeywordOverride(keyword, amount, turns):
            resource = (turns == 1 ? L10n.effect_keyword_override_single(keyword.markedName(locale: locale), amount, turns) : L10n
                .effect_keyword_override(
                    keyword.markedName(locale: locale),
                    amount,
                    turns,
                )); values = ["damage": amount, "turns": turns]
        case let .damageReductionPercent(percent, turns):
            let amount = CombatRounding.rounded(percent * 100)
            resource = (turns == 1 ? L10n.effect_damage_reduction_single(amount, turns) : L10n.effect_damage_reduction(
                amount,
                turns,
            )); values = ["percent": amount, "turns": turns]
        case let .healingReductionPercent(percent, turns):
            let amount = CombatRounding.rounded(percent * 100)
            resource = (turns == 1 ? L10n.effect_healing_reduction_single(amount, turns) : L10n.effect_healing_reduction(
                amount,
                turns,
            )); values = ["percent": amount, "turns": turns]
        case let .damageReductionFlat(amount, turns):
            resource = (turns == 1 ? L10n.effect_damage_flat_single(amount, turns) : L10n.effect_damage_flat(amount, turns)); values = [
                "amount": amount,
                "turns": turns,
            ]
        }
        return LocalizedGameText(resource, locale: locale, values: values)
    }
}
