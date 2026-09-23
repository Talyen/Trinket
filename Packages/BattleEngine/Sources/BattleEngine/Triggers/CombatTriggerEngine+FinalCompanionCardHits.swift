import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterFinalCompanionCardHit(
        keyword: Keyword?,
        actor: Combatant,
        critical: Bool,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        events.append(contentsOf: finalCompanionGoldFromAttack(actor: actor, critical: critical, triggers: triggers, in: &context))
        guard context.roster.enemy.isAlive else { return events }
        if keyword == .physical {
            if triggers.firstPhysicalAttackBlockPerTurn > 0,
               context.claimHeroTalent("Bone Shield", actorID: actor.id) {
                events.append(contentsOf: context.applyBlock(
                    triggers.firstPhysicalAttackBlockPerTurn,
                    to: actor, source: actor, abilityName: "Bone Shield",
                ))
            }
            if critical, triggers.physicalCriticalBleedDamage > 0 {
                events.append(contentsOf: heroTalentDamage(
                    .bleed, amount: triggers.physicalCriticalBleedDamage,
                    source: actor, name: "Cleaving Bones", in: &context,
                ))
            }
        }
        if keyword == .holy {
            if triggers.firstHolyAttackBlockPerTurn > 0,
               context.claimHeroTalent("Radiant Barrier", actorID: actor.id) {
                events.append(contentsOf: context.applyBlock(
                    triggers.firstHolyAttackBlockPerTurn,
                    to: actor, source: actor, abilityName: "Radiant Barrier",
                ))
            }
            if critical, triggers.holyCriticalStunDamage > 0 {
                events.append(contentsOf: heroTalentDamage(
                    .stun, amount: triggers.holyCriticalStunDamage,
                    source: actor, name: "Stun Flare", in: &context,
                ))
            }
            if critical, triggers.holyCritEnemyNextAttackMissChance > 0 {
                prepareEnemyNextAttackMiss(
                    triggers.holyCritEnemyNextAttackMissChance, abilityName: "Dazzling Guard", in: &context,
                )
            }
        }
        if keyword == .freeze, critical, triggers.freezeCritEnemyNextAttackMissChance > 0 {
            prepareEnemyNextAttackMiss(
                triggers.freezeCritEnemyNextAttackMissChance, abilityName: "Blinding Frost", in: &context,
            )
        }
        return events
    }

    private static func finalCompanionGoldFromAttack(
        actor: Combatant,
        critical: Bool,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.attackGoldStealAmount > 0,
           context.claimTalentAbility("Snatch", actorID: actor.id),
           BattleChance.succeeds(probability: triggers.attackGoldStealChancePercent, using: &context.rng) {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.attackGoldStealAmount, to: actor, abilityName: "Snatch", isTheft: true,
            ))
        }
        if critical, triggers.criticalGoldStealAmount > 0,
           context.claimTalentAbility("Lucky Strike", actorID: actor.id),
           BattleChance.succeeds(probability: triggers.criticalGoldStealChancePercent, using: &context.rng) {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.criticalGoldStealAmount, to: actor, abilityName: "Lucky Strike", isTheft: true,
            ))
        }
        return events
    }

    static func prepareEnemyNextAttackMiss(
        _ chance: Double,
        abilityName: String,
        in context: inout BattleState,
    ) {
        let enemy = context.roster.enemy.combatant
        context.roster.mutateRuntime(for: enemy) {
            if chance >= $0.talents.pending.nextAttackMissChance {
                $0.talents.pending.nextAttackMissChance = chance
                $0.talents.pending.nextAttackMissAbilityName = abilityName
            }
        }
    }
}
