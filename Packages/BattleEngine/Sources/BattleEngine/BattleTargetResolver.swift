import TrinketContent
import TrinketCore

public enum BattleTargetResolver {
    public static func abilityTarget(for actor: Combatant, in context: BattleState) -> Combatant {
        actor.role == .enemy ? context.talentAdjustedEnemyTarget : context.enemy
    }

    public static func effectTarget(
        _ target: EffectTarget,
        actor: Combatant,
        abilityTarget: Combatant,
        in context: BattleState,
    ) -> Combatant {
        switch target {
        case .abilityTarget:
            return abilityTarget
        case .actor:
            return actor
        case .enemy:
            return context.enemy
        case .hero:
            return context.hero
        case .companion:
            return context.companion
        case .lowestHealthAlly:
            if actor.role == .enemy {
                return context.enemy
            }
            return BattleConditionEvaluator.lowestHealthAlly(in: context)
        case .defeatedAlly:
            if context.roster.health(for: context.companion) <= 0 {
                return context.companion
            }
            if context.roster.health(for: context.hero) <= 0 {
                return context.hero
            }
            return context.hero
        }
    }
}
