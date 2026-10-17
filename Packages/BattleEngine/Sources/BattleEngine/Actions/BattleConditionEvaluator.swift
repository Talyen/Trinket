import TrinketContent
import TrinketCore

public enum BattleConditionEvaluator {
    public static func isMet(
        _ condition: DamageCondition,
        actor: Combatant,
        in context: borrowing BattleState,
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
        in context: borrowing BattleState,
    ) -> Bool {
        isMet(condition, action: BattleActionContext(actor: actor, selectedTarget: abilityTarget), in: context)
    }

    public static func isMet(
        _ condition: DamageCondition,
        action: BattleActionContext,
        in context: borrowing BattleState,
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
            return context.roster.hasControlStatus(for: enemy, keyword: .freeze)
        case .enemyStunned:
            return context.roster.hasControlStatus(for: enemy, keyword: .stun)
        case .enemyStunnedOrFrozen:
            return context.roster.hasControlStatus(for: enemy, keyword: .stun)
                || context.roster.hasControlStatus(for: enemy, keyword: .freeze)
        case .enemyMarked:
            return context.roster.activeEffects(for: enemy).contains { $0.effect.kind == .marked }
        case .enemyLowerHealthThanActor:
            return context.roster.health(for: enemy) < context.roster.health(for: action.actor)
        case .allyBelowHalfHealth:
            return action.hasLivingAlly(in: context) { $0.isBelowHalfHealth }
        case .allyMissingHealth:
            return action.hasLivingAlly(in: context) { $0.currentHealth < $0.maxHealth }
        case .enemyHasBuff:
            return context.roster.activeEffects(for: enemy).contains(where: \.effect.isRemovableBuff)
        case .enemyHasBlock:
            return DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: enemy)) > 0
        case .enemyFullHealth:
            return context.roster.health(for: enemy) == context.roster.maxHealth(for: enemy)
        case .actorHasTwoBlock:
            return DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: action.actor)) >= 2
        case .firstTurn:
            return context.turnCount == 0
        }
    }

    public static func lowestHealthAlly(in context: BattleState) -> Combatant {
        BattleActionContext.lowestHealthAlly(in: context)
    }

    public static func mostDebuffedAlly(in context: BattleState) -> Combatant {
        BattleActionContext.mostDebuffed(
            in: [context.hero, context.companion], state: context,
        )
    }
}
