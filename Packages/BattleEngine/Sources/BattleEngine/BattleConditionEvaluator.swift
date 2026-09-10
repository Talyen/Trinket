import Foundation
import TrinketContent
import TrinketCore

public enum BattleConditionEvaluator {
    public static func isMet(
        _ condition: DamageCondition,
        actor: Combatant,
        in context: BattleState,
    ) -> Bool {
        if let current = context.resolution.actionContext, current.actor.id == actor.id {
            return isMet(condition, action: current, in: context)
        }
        return isMet(condition, action: BattleActionContext(actor: actor, in: context), in: context)
    }

    static func isMet(
        _ condition: DamageCondition,
        actor: Combatant,
        abilityTarget: Combatant,
        in context: BattleState,
    ) -> Bool {
        isMet(condition, action: BattleActionContext(actor: actor, selectedTarget: abilityTarget), in: context)
    }

    public static func isMet(
        _ condition: DamageCondition,
        action: BattleActionContext,
        in context: BattleState,
    ) -> Bool {
        let enemy = action.selectedTarget
        switch condition {
        case .enemyBleeding:
            return context.roster.hasAffliction(.bleed, on: enemy)
        case .enemyBurning:
            return context.roster.hasAffliction(.burn, on: enemy)
        case .enemyNotBurning:
            return !context.roster.hasAffliction(.burn, on: enemy)
        case .enemyPoisoned:
            return context.roster.hasAffliction(.poison, on: enemy)
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
            return context.roster.health(for: enemy) < context.roster.health(for: action.actor)
        case .allyBelowHalfHealth:
            return action.allies(in: context).contains {
                let health = context.health(of: $0)
                return health > 0 && health * 2 < context.maxHealth(of: $0)
            }
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
        BattleActionContext.lowestHealth(in: [hero, companion], state: context)
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
        BattleActionContext.mostDebuffed(in: [hero, companion], state: context)
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
