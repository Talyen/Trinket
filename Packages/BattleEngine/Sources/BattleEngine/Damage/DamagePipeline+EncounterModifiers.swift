import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyEnemyAttackBlockRemoval(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.options.isAttackHit, state.amount > 0,
              let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID), source.role == .enemy,
              state.combatant.role != .enemy
        else { return }
        let amount = context.modifiers(for: sourceID).triggers.attackBlockRemoval
        guard amount > 0 else { return }
        let current = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: state.combatant))
        let removed = min(current, amount)
        guard removed > 0 else { return }
        DefensePoolEngine.set(current - removed, on: state.combatant, in: &context)
        state.damageEvents.append(context.nextEvent(
            kind: .effect, effectKind: .blockStripped,
            actorName: source.combatant.name, abilityName: "Sundered Guard",
            target: state.combatant, amount: removed, keyword: .block,
        ))
    }

    static func applyEnemyAttackPurge(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.options.isAttackHit, state.amount > 0,
              let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID), source.role == .enemy,
              state.combatant.role != .enemy,
              context.roster.health(for: state.combatant) > 0
        else { return }
        let count = context.modifiers(for: sourceID).triggers.attackPurgeCount
        guard count > 0 else { return }
        let purge = PurgeOperation.resolve(
            .randomBuffs(count), source: source.combatant, target: state.combatant,
            abilityName: "Unbinding Strike", in: &context,
        )
        state.damageEvents.append(contentsOf: purge.events)
    }
}
