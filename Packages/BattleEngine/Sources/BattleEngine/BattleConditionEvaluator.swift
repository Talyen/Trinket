import Foundation
import TrinketCore
import TrinketContent

public enum BattleConditionEvaluator {
    public static func isMet(
        _ condition: DamageCondition,
        actor: Combatant,
        enemy: Combatant,
        hero: Combatant,
        pet: Combatant,
        context: BattleEngineContext
    ) -> Bool {
        switch condition {
        case .enemyBleeding:
            return hasDebuffKeyword(.bleed, on: enemy, in: context)
        case .enemyBurning:
            return hasDebuffKeyword(.burn, on: enemy, in: context)
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
            return context.health(of: enemy) < context.health(of: actor)
        case .allyBelowHalfHealth:
            let heroHealth = context.health(of: hero)
            let petHealth = context.health(of: pet)
            let heroMax = context.roster.runtime(for: hero)?.maxHealth ?? hero.maxHealth
            let petMax = context.roster.runtime(for: pet)?.maxHealth ?? pet.maxHealth
            return heroHealth * 2 < heroMax || petHealth * 2 < petMax
        case .enemyHasBuff:
            return context.activeEffects(for: enemy).contains { $0.effect.isRemovableBuff }
        }
    }

    public static func lowestHealthAlly(
        hero: Combatant,
        pet: Combatant,
        context: BattleEngineContext
    ) -> Combatant {
        let heroHealth = context.health(of: hero)
        let petHealth = context.health(of: pet)
        if heroHealth <= petHealth {
            return hero
        }
        return pet
    }

    private static func hasDebuffKeyword(
        _ keyword: Keyword,
        on combatant: Combatant,
        in context: BattleEngineContext
    ) -> Bool {
        context.activeEffects(for: combatant).contains { active in
            active.effect.keyword == keyword
        }
    }

    private static func hasPendingControl(
        _ keyword: Keyword,
        on combatant: Combatant,
        in context: BattleEngineContext
    ) -> Bool {
        context.activeEffects(for: combatant).contains { active in
            guard case let .controlMeter(meterKeyword, amount, threshold) = active.effect else { return false }
            return meterKeyword == keyword && threshold > 0 && amount >= threshold
        }
    }

    private static func hasMarked(on combatant: Combatant, in context: BattleEngineContext) -> Bool {
        context.activeEffects(for: combatant).contains { active in
            if case .marked = active.effect { return true }
            return false
        }
    }
}
