import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
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
        var events: [ActionEvent] = []
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
