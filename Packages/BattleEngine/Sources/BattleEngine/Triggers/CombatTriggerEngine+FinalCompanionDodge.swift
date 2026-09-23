import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterFinalCompanionDodge(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard actor.role == .companion else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        prepareFinalDodgeBonuses(by: actor, triggers: triggers, in: &context)
        var events = finalDodgeResources(by: actor, triggers: triggers, in: &context)
        events.append(contentsOf: finalDodgeDamage(by: actor, triggers: triggers, in: &context))
        return events
    }

    private static func prepareFinalDodgeBonuses(
        by actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        let serial = context.resolution.cardTalents?.playSerial
        let firstFeint = triggers.firstDodgeNextAttackBonusPerTurn > 0
            && context.claimHeroTalent("Feint Strike", actorID: actor.id)
        context.roster.mutateRuntime(for: actor) {
            if triggers.dodgeNextBleedAttackMultiplier > 1 {
                $0.talents.pending.nextBleedAttackMultiplier = max(
                    $0.talents.pending.nextBleedAttackMultiplier, triggers.dodgeNextBleedAttackMultiplier,
                )
                $0.talents.pending.nextBleedMultiplierPreparedCardSerial = serial
            }
            if triggers.dodgeNextPhysicalDamageMultiplier > 1 {
                $0.talents.pending.nextPhysicalAttackMultiplier = max(
                    $0.talents.pending.nextPhysicalAttackMultiplier, triggers.dodgeNextPhysicalDamageMultiplier,
                )
                $0.talents.pending.nextPhysicalAttackPreparedCardSerial = serial
            }
            if triggers.dodgeNextCriticalDamageMultiplier > 1 {
                $0.talents.pending.nextCriticalHitMultiplier = max(
                    $0.talents.pending.nextCriticalHitMultiplier, triggers.dodgeNextCriticalDamageMultiplier,
                )
                $0.talents.pending.nextCriticalHitPreparedCardSerial = serial
            }
            if firstFeint {
                $0.talents.pending.cardDamageBonus += triggers.firstDodgeNextAttackBonusPerTurn
            }
        }
        if context.roster.hero.isAlive {
            let ally = context.roster.hero.combatant
            if triggers.dodgeAllyNextAttackCriticalBonus > 0 {
                context.roster.mutateRuntime(for: ally) {
                    $0.talents.pending.nextAttackCriticalBonus = max(
                        $0.talents.pending.nextAttackCriticalBonus,
                        triggers.dodgeAllyNextAttackCriticalBonus,
                    )
                    $0.talents.pending.nextAttackCriticalPreparedCardSerial = serial
                }
            }
            if triggers.firstDodgeAllyEvadeNextHit,
               context.claimHeroTalent("Evasive Pack", actorID: actor.id, battle: true) {
                context.prependEffect(.evadeNextHit, to: ally, remainingTurns: 0)
            }
        }
    }

    private static func finalDodgeResources(
        by actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.dodgeGoldAmount > 0,
           BattleChance.succeeds(probability: triggers.dodgeGoldChancePercent, using: &context.rng) {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.dodgeGoldAmount, to: actor, abilityName: "Palmed Coin",
            ))
        }
        if triggers.belowHalfFirstDodgeHealPerTurn > 0,
           context.roster.enemy.isAlive,
           context.roster.health(for: actor) * 2 < context.roster.maxHealth(for: actor),
           context.claimHeroTalent("Stolen Breath", actorID: actor.id) {
            events.append(contentsOf: context.healEmitting(
                amount: triggers.belowHalfFirstDodgeHealPerTurn,
                target: actor, source: actor, abilityName: "Stolen Breath",
            ))
        }
        return events
    }

    private static func finalDodgeDamage(
        by actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.roster.enemy.isAlive else { return [] }
        var events: [ActionEvent] = []
        for (keyword, chance, amount, name) in [
            (Keyword.physical, triggers.dodgePhysicalChancePercent, triggers.dodgePhysicalDamage, "Snapping Jaws"),
            (.poison, triggers.dodgePoisonChancePercent, triggers.dodgePoisonDamage, "Poisonous Dash"),
            (.stun, triggers.dodgeStunChancePercent, triggers.dodgeStunDamage, "Dazzling Tail"),
        ] where amount > 0 && context.roster.enemy.isAlive {
            if BattleChance.succeeds(probability: chance, using: &context.rng) {
                events.append(contentsOf: heroTalentDamage(
                    keyword, amount: amount, source: actor, name: name, in: &context,
                ))
            }
        }
        return events
    }
}
