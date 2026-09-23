import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterCompanionDodge(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let triggers = context.modifiers(for: actor.id).triggers
        if triggers.dodgeNextManaEmpowerFree || triggers.dodgeNextFreezeIgnoreBlock
            || triggers.dodgeNextAttackIgnoreBlock || triggers.firstDodgeDoubleNextAttack {
            let preparedCardSerial = context.resolution.cardTalents?.playSerial
            let firstDodge = triggers.firstDodgeDoubleNextAttack
                && context.claimHeroTalent("Surprise Strike", actorID: actor.id, battle: true)
            context.roster.mutateRuntime(for: actor) {
                if firstDodge {
                    $0.talents.pending.doubleDamageAfterDodge = true
                }
                if triggers.dodgeNextManaEmpowerFree {
                    $0.talents.pending.nextManaEmpowerDiscount = max($0.talents.pending.nextManaEmpowerDiscount, 3)
                }
                if triggers.dodgeNextFreezeIgnoreBlock {
                    $0.talents.pending.nextFreezeIgnoresBlock = true
                    $0.talents.pending.nextFreezeIgnorePreparedCardSerial = preparedCardSerial
                }
                if triggers.dodgeNextAttackIgnoreBlock {
                    $0.talents.pending.nextAttackIgnoresBlock = true
                    $0.talents.pending.nextAttackIgnorePreparedCardSerial = preparedCardSerial
                }
            }
        }
        var events: [ActionEvent] = []
        if triggers.dodgeDealBleedFlat > 0, context.roster.enemy.isAlive {
            events.append(contentsOf: applyDoT(
                keyword: .bleed,
                potency: triggers.dodgeDealBleedFlat,
                to: context.roster.enemy.combatant,
                sourceActorID: actor.id,
                in: &context,
            ))
        }
        if triggers.firstDodgeDrawForAlly, context.roster.hero.isAlive,
           context.claimHeroTalent("Tailwind", actorID: actor.id, battle: true) {
            let ally = context.roster.hero.combatant
            events.append(contentsOf: drawCards(1, for: .hero, actor: ally, abilityName: "Tailwind", in: &context))
        }
        if triggers.dodgeDrawChancePercent > 0,
           BattleChance.succeeds(probability: triggers.dodgeDrawChancePercent, using: &context.rng),
           let owner = context.roster.participant(for: actor) {
            events.append(contentsOf: drawCards(1, for: owner, actor: actor, abilityName: "Regroup", in: &context))
        }
        return events
    }
}
