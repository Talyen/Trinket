import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterCompanionCardHit(
        keyword: Keyword?,
        actor: Combatant,
        critical: Bool,
        healthLost: Int,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard actor.role == .companion else { return [] }
        var events: [ActionEvent] = []
        if critical, triggers.criticalGoldStealFlat > 0 {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.criticalGoldStealFlat, to: actor,
                abilityName: "Pickpocket", isTheft: true,
            ))
        }
        if keyword == .poison,
           triggers.poisonAttackStunChancePercent > 0,
           context.claimTalentAbility("Paralysis", actorID: actor.id),
           BattleChance.succeeds(probability: triggers.poisonAttackStunChancePercent, using: &context.rng),
           context.roster.enemy.isAlive {
            let enemy = context.roster.enemy.combatant
            events.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                ControlMeterEngine.threshold(for: enemy, in: context),
                keyword: .stun, to: enemy,
                sourceActorID: actor.id, applyFightPacing: false, in: &context,
            ))
        }
        if keyword == .burn {
            events.append(contentsOf: afterCompanionBurnHit(
                actor: actor, critical: critical, healthLost: healthLost,
                triggers: triggers, in: &context,
            ))
        }
        if keyword == .holy {
            events.append(contentsOf: afterCompanionHolyHit(
                actor: actor, critical: critical, triggers: triggers, in: &context,
            ))
        }
        if keyword == .bleed, critical {
            events.append(contentsOf: afterCompanionBleedCritical(actor: actor, triggers: triggers, in: &context))
        }
        return events
    }

    private static func afterCompanionHolyHit(
        actor: Combatant,
        critical: Bool,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if critical, triggers.holyCriticalAllyIgnoreBlock, context.roster.hero.isAlive {
            let serial = context.resolution.cardTalents?.playSerial
            context.roster.mutateRuntime(for: context.roster.hero.combatant) {
                $0.talents.pending.nextAttackIgnoresBlock = true
                $0.talents.pending.nextAttackIgnorePreparedCardSerial = serial
            }
        }
        if critical, triggers.holyCriticalPurgeCount > 0, context.roster.enemy.isAlive {
            events.append(contentsOf: applyPurge(
                to: context.roster.enemy.combatant, source: actor,
                abilityName: "Bane of Evil", count: triggers.holyCriticalPurgeCount,
                purgeAll: false, in: &context,
            ))
        }
        if triggers.holyAttackEnemyMissChance > 0, context.roster.enemy.isAlive {
            context.roster.mutateRuntime(for: context.roster.enemy.combatant) {
                $0.talents.pending.nextAttackMissChance = max(
                    $0.talents.pending.nextAttackMissChance, triggers.holyAttackEnemyMissChance,
                )
            }
        }
        if triggers.holyAttackDrawChancePercent > 0, context.roster.enemy.isAlive,
           context.claimTalentAbility("Radiant Wisdom", actorID: actor.id),
           BattleChance.succeeds(probability: triggers.holyAttackDrawChancePercent, using: &context.rng),
           let owner = context.roster.participant(for: actor) {
            events.append(contentsOf: drawCards(1, for: owner, actor: actor, abilityName: "Radiant Wisdom", in: &context))
        }
        if triggers.holyAttackCleanseAllyChancePercent > 0, context.roster.hero.isAlive,
           context.hasTalentDebuff(on: context.roster.hero.combatant),
           context.claimTalentAbility("Purifying Light", actorID: actor.id),
           BattleChance.succeeds(probability: triggers.holyAttackCleanseAllyChancePercent, using: &context.rng) {
            events.append(contentsOf: CleanseOperation.resolve(
                .random, source: actor, target: context.roster.hero.combatant,
                abilityName: "Purifying Light", in: &context,
            ).events)
        }
        return events
    }

    private static func afterCompanionBurnHit(
        actor: Combatant,
        critical: Bool,
        healthLost: Int,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if healthLost > 0, triggers.burnAttackBlockAmount > 0,
           context.claimTalentAbility("Flame Shield", actorID: actor.id),
           BattleChance.succeeds(probability: triggers.burnAttackBlockChancePercent, using: &context.rng) {
            events.append(contentsOf: context.applyBlock(
                triggers.burnAttackBlockAmount, to: actor, source: actor, abilityName: "Flame Shield",
            ))
        }
        if healthLost > 0, triggers.burnAttackHealLowestAmount > 0,
           context.claimTalentAbility("Healing Flames", actorID: actor.id),
           BattleChance.succeeds(probability: triggers.burnAttackHealLowestChancePercent, using: &context.rng) {
            let target = BattleConditionEvaluator.lowestHealthAlly(in: context)
            if context.roster.health(for: target) < context.roster.maxHealth(for: target) {
                events.append(contentsOf: context.healEmitting(
                    amount: triggers.burnAttackHealLowestAmount,
                    target: target, source: actor, abilityName: "Healing Flames",
                ))
            }
        }
        if critical, triggers.burnCriticalRestoreMana > 0,
           context.claimTalentAbility("Furnace Rhythm", actorID: actor.id) {
            events.append(contentsOf: context.restoreManaEmitting(
                triggers.burnCriticalRestoreMana, to: actor, abilityName: "Furnace Rhythm",
            ))
        }
        return events
    }

    private static func afterCompanionBleedCritical(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.bleedCriticalPoisonDamage > 0 {
            events.append(contentsOf: heroTalentDamage(
                .poison, amount: triggers.bleedCriticalPoisonDamage,
                source: actor, name: "Cross-Contamination", in: &context,
            ))
        }
        if triggers.bleedCriticalThorns > 0 {
            events.append(contentsOf: heroTalentThorns(
                to: actor, source: actor, amount: triggers.bleedCriticalThorns,
                name: "Spiny Carapace", in: &context,
            ))
        }
        if triggers.bleedCriticalDrawChancePercent > 0,
           context.claimTalentAbility("Frenzied Tail", actorID: actor.id),
           BattleChance.succeeds(probability: triggers.bleedCriticalDrawChancePercent, using: &context.rng),
           let owner = context.roster.participant(for: actor) {
            events.append(contentsOf: drawCards(
                1, for: owner, actor: actor, abilityName: "Frenzied Tail", in: &context,
            ))
        }
        return events
    }
}
