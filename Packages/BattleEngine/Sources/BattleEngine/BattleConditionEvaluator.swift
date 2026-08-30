import Foundation
import TrinketContent
import TrinketCore

public enum BattleConditionEvaluator {
    public static func isMet(
        _ condition: DamageCondition,
        actor: Combatant,
        enemy: Combatant,
        hero: Combatant,
        companion: Combatant,
        context: BattleState,
    ) -> Bool {
        switch condition {
        case .enemyBleeding:
            return hasDebuffKeyword(.bleed, on: enemy, in: context)
        case .enemyBurning:
            return hasDebuffKeyword(.burn, on: enemy, in: context)
        case .enemyNotBurning:
            return !hasDebuffKeyword(.burn, on: enemy, in: context)
        case .enemyPoisoned:
            return hasDebuffKeyword(.poison, on: enemy, in: context)
        case .enemyFrozen:
            return hasPendingControl(.freeze, on: enemy, in: context)
        case .enemyStunned:
            return hasPendingControl(.stun, on: enemy, in: context)
        case .enemyStunnedOrFrozen:
            return hasPendingControl(.stun, on: enemy, in: context)
                || hasPendingControl(.freeze, on: enemy, in: context)
        case .enemyMarked:
            return hasMarked(on: enemy, in: context)
        case .enemyLowerHealthThanActor:
            return context.roster.health(for: enemy) < context.roster.health(for: actor)
        case .allyBelowHalfHealth:
            let heroHealth = context.roster.health(for: hero)
            let companionHealth = context.roster.health(for: companion)
            let heroMaxHealth = context.roster.maxHealth(for: hero)
            let companionMaxHealth = context.roster.maxHealth(for: companion)
            let heroMax = heroMaxHealth > 0 ? heroMaxHealth : hero.maxHealth
            let companionMax = companionMaxHealth > 0 ? companionMaxHealth : companion.maxHealth
            return (heroHealth > 0 && heroHealth * 2 < heroMax) || (companionHealth > 0 && companionHealth * 2 < companionMax)
        case .enemyHasBuff:
            return context.roster.activeEffects(for: enemy).contains(where: \.effect.isRemovableBuff)
        case .firstTurn:
            return context.turnCount == 0
        }
    }

    public static func lowestHealthAlly(in context: BattleState) -> Combatant {
        lowestHealthAlly(
            hero: context.roster.hero.combatant,
            companion: context.roster.companion.combatant,
            context: context,
        )
    }

    public static func lowestHealthAlly(
        hero: Combatant,
        companion: Combatant,
        context: BattleState,
    ) -> Combatant {
        let heroHealth = context.roster.health(for: hero)
        let companionHealth = context.roster.health(for: companion)
        let heroAlive = heroHealth > 0
        let companionAlive = companionHealth > 0
        switch (heroAlive, companionAlive) {
        case (true, true):
            return heroHealth <= companionHealth ? hero : companion
        case (true, false):
            return hero
        case (false, true):
            return companion
        case (false, false):
            return hero
        }
    }

    public static func mostDebuffedAlly(in context: BattleState) -> Combatant {
        mostDebuffedAlly(
            hero: context.roster.hero.combatant,
            companion: context.roster.companion.combatant,
            context: context,
        )
    }

    public static func mostDebuffedAlly(
        hero: Combatant,
        companion: Combatant,
        context: BattleState,
    ) -> Combatant {
        let heroDebuffs = context.roster.activeEffects(for: hero).count(where: \.effect.isRemovableDebuff)
        let companionDebuffs = context.roster.activeEffects(for: companion).count(where: \.effect.isRemovableDebuff)
        if heroDebuffs != companionDebuffs {
            return heroDebuffs > companionDebuffs ? hero : companion
        }
        return lowestHealthAlly(hero: hero, companion: companion, context: context)
    }

    private static func hasDebuffKeyword(
        _ keyword: Keyword,
        on combatant: Combatant,
        in context: BattleState,
    ) -> Bool {
        context.roster.activeEffects(for: combatant).contains { active in
            guard active.effect.keyword == keyword else { return false }
            switch active.effect {
            case let .bleed(potency):
                return potency > 0 && active.remainingTurns > 0
            case let .burn(potency), let .poison(potency):
                return potency > 0
            default:
                return true
            }
        }
    }

    private static func hasPendingControl(
        _ keyword: Keyword,
        on combatant: Combatant,
        in context: BattleState,
    ) -> Bool {
        context.roster.activeEffects(for: combatant).contains { active in
            guard case let .controlMeter(meterKeyword, amount, threshold) = active.effect else { return false }
            return meterKeyword == keyword && threshold > 0 && amount >= threshold
        }
    }

    private static func hasMarked(on combatant: Combatant, in context: BattleState) -> Bool {
        context.roster.activeEffects(for: combatant).contains { active in
            if case .marked = active.effect {
                true
            } else {
                false
            }
        }
    }
}
