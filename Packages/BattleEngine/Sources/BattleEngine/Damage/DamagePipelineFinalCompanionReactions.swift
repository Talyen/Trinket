import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyFinalCompanionLeechRewards(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.combatant.role == .enemy,
              let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID), source.role == .companion
        else { return }
        let triggers = context.modifiers(for: sourceID).triggers
        let attackHasLeech = state.options.isAttackHit && state.healthLost > 0
            && (state.options.abilityHasLeech || state.talentAttackHasLeech
                || triggers.borrowedLife && context.roster.isDeathsDoorActive(for: source.combatant))
        guard state.didLeech || attackHasLeech else { return }
        if triggers.leechEnemyNextAttackDamageMultiplier < 1, context.roster.enemy.isAlive {
            context.roster.mutateRuntime(for: context.roster.enemy.combatant) {
                $0.talents.pending.nextOutgoingAttackMultiplier = min(
                    $0.talents.pending.nextOutgoingAttackMultiplier,
                    triggers.leechEnemyNextAttackDamageMultiplier,
                )
            }
        }
        if state.isCritical, state.options.isAttackHit,
           triggers.leechCriticalPoisonDamage > 0, context.roster.enemy.isAlive {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.heroTalentDamage(
                .poison, amount: triggers.leechCriticalPoisonDamage,
                source: source.combatant, name: "Toxic Touch", in: &context,
            ))
        }
    }

    static func applyFinalCompanionHolyHitRewards(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.amount > 0, state.damageKeyword == .holy,
              state.combatant.role == .enemy, context.roster.enemy.isAlive,
              context.roster.hero.isAlive,
              let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID), source.role == .companion,
              context.modifiers(for: sourceID).triggers.firstHolyHitAllyBlockPerTurn > 0,
              context.resolution.claim(
                  .heroTalent("Sun Glyph"), actorID: sourceID, cadence: .turn(context.turnCount),
              ) else { return }
        state.damageEvents.append(contentsOf: context.applyBlock(
            context.modifiers(for: sourceID).triggers.firstHolyHitAllyBlockPerTurn,
            to: context.roster.hero.combatant,
            source: source.combatant,
            abilityName: "Sun Glyph",
        ))
    }
}
