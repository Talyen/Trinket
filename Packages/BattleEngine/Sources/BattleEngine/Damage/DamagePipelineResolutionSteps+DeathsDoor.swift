import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyDeathsDoor(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) async {
        let deferredPartyHealthLoss = state.healthLost > 0 && state.combatant.role != .enemy
            && context.roster.health(for: state.combatant) == 0
        await state.damageEvents.append(contentsOf: DeathsDoorEngine.resolveAfterDamage(
            to: state.combatant,
            in: &context,
        ))
        if deferredPartyHealthLoss, context.roster.health(for: state.combatant) > 0 {
            if state.combatant.role == .hero {
                await state.damageEvents.append(contentsOf: CombatTriggerEngine.afterHeroTalentHealthLoss(
                    target: state.combatant, sourceID: state.sourceActorID, keyword: state.damageKeyword, in: &context,
                ))
            }
            await state.damageEvents.append(contentsOf: CombatTriggerEngine.afterSurvivingHealthLoss(
                target: state.combatant, in: &context,
            ))
        }
    }
}
