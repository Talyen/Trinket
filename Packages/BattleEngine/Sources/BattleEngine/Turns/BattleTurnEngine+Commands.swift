import TrinketContent
import TrinketCore

package extension BattleTurnEngine {
    /// Synchronous action entry for consumers such as actor-isolated feedback
    /// tests. Construct the executor body here, outside the caller's actor.
    static func performAction(
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        origin: DamageOperation.AttackOrigin = .ability,
        context: inout BattleState,
    ) -> [ActionEvent] {
        CombatExecutor.run {
            await performAction(
                ability: ability, actor: actor, abilityTarget: abilityTarget,
                origin: origin, context: &context,
            )
        }
    }
}
