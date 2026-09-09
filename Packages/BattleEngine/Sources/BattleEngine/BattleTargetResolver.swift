import TrinketContent
import TrinketCore

public enum BattleTargetResolver {
    public static func abilityTarget(for actor: Combatant, in context: BattleState) -> Combatant {
        BattleActionContext(actor: actor, in: context).selectedTarget
    }

    public static func effectTarget(
        _ target: EffectTarget,
        actor: Combatant,
        abilityTarget: Combatant,
        in context: BattleState,
    ) -> Combatant {
        BattleActionContext(actor: actor, selectedTarget: abilityTarget).target(target, in: context)
    }
}
