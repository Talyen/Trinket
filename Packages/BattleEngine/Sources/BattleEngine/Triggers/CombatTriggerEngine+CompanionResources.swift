import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterFinalCompanionGoldGain(
        granted: Int,
        actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let amount = context.modifiers(for: actor.id).triggers.belowHalfFirstGoldGainHealPerTurn
        guard granted > 0, amount > 0, context.roster.enemy.isAlive,
              context.roster.health(for: actor) * 2 < context.roster.maxHealth(for: actor),
              context.claimHeroTalent("Golden Recovery", actorID: actor.id) else { return [] }
        return context.healEmitting(amount: amount, target: actor, source: actor, abilityName: "Golden Recovery")
    }

    static func afterCompanionGoldTheft(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let triggers = context.modifiers(for: actor.id).triggers
        if triggers.goldTheftNextBlockMultiplier > 1 {
            let preparedCardSerial = context.resolution.cardTalents?.playSerial
            context.roster.mutateRuntime(for: actor) {
                $0.talents.pending.nextBlockGainMultiplier = max(
                    $0.talents.pending.nextBlockGainMultiplier,
                    triggers.goldTheftNextBlockMultiplier,
                )
                $0.talents.pending.nextBlockGainPreparedCardSerial = preparedCardSerial
            }
        }
        if triggers.goldTheftNextAttackCriticalBonus > 0 {
            let serial = context.resolution.cardTalents?.playSerial
            let actionID = context.resolution.actionID
            context.roster.mutateRuntime(for: actor) {
                $0.talents.pending.nextAttackCriticalBonus = max(
                    $0.talents.pending.nextAttackCriticalBonus,
                    triggers.goldTheftNextAttackCriticalBonus,
                )
                $0.talents.pending.nextAttackCriticalPreparedCardSerial = serial
                $0.talents.pending.nextAttackCriticalPreparedActionID = actionID
            }
        }
        var events: [ActionEvent] = []
        if triggers.goldTheftStealEnemyBlockChancePercent > 0, context.roster.enemy.isAlive {
            let enemy = context.roster.enemy.combatant
            let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: enemy))
            if block > 0,
               context.claimTalentAbility("Light-Fingered", actorID: actor.id),
               BattleChance.succeeds(
                   probability: triggers.goldTheftStealEnemyBlockChancePercent, using: &context.rng,
               ) {
                events.append(contentsOf: DefensePoolEngine.steal(
                    block, from: enemy, to: actor, abilityName: "Light-Fingered", in: &context,
                ))
            }
        }
        if triggers.goldTheftHealAllyFlat > 0, context.roster.hero.isAlive,
           context.roster.hero.currentHealth < context.roster.hero.maxHealth {
            events.append(contentsOf: context.healEmitting(
                amount: triggers.goldTheftHealAllyFlat,
                target: context.roster.hero.combatant,
                source: actor,
                abilityName: "Shared Spoils",
            ))
        }
        if triggers.firstGoldTheftDrawBattle,
           context.claimHeroTalent("Fetch!", actorID: actor.id, battle: true),
           let owner = context.roster.participant(for: actor) {
            events.append(contentsOf: drawCards(1, for: owner, actor: actor, abilityName: "Fetch!", in: &context))
        }
        return events
    }
}
