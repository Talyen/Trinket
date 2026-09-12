import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterPartyCardPlayed(in context: inout BattleState) -> [ActionEvent] {
        let count = context.turnCadence.cardsPlayed.values.reduce(0, +)
        var events: [ActionEvent] = []
        for owner in [BattleParticipant.hero, .companion] {
            let actor = context.roster[owner]
            guard actor.isAlive else { continue }
            let triggers = context.modifiers(for: actor.id).triggers
            guard triggers.cardsPlayedHealPartyThreshold > 0,
                  count == triggers.cardsPlayedHealPartyThreshold,
                  context.resolution.claim(.heroTalent("playfulEnergy"), actorID: actor.id, cadence: .turn(context.turnCount))
            else { continue }
            for targetOwner in [BattleParticipant.hero, .companion] {
                let target = context.roster[targetOwner]
                guard target.isAlive else { continue }
                events.append(contentsOf: context.healEmitting(
                    amount: triggers.cardsPlayedHealPartyAmount,
                    target: target.combatant,
                    source: actor.combatant,
                    abilityName: triggerAbilityName(
                        "cardsPlayedHealPartyThreshold", for: actor.combatant, fallback: "Playful Energy", in: context,
                    ),
                ))
            }
        }
        return events
    }
}
