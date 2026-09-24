import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func drawOnFreezeCardHit(healthLost: Int, actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let chance = context.modifiers(for: actor.id).triggers.freezeAttackDrawChancePercent
        guard healthLost > 0, chance > 0,
              BattleChance.succeeds(probability: chance, using: &context.rng),
              let owner = context.roster.participant(for: actor)
        else { return [] }
        return drawCards(1, for: owner, actor: actor, abilityName: "Rimewind", in: &context)
    }

    static func afterEnemyFrozen(sourceActorID: String?, in context: inout BattleState) -> [ActionEvent] {
        guard let sourceActorID,
              let source = context.roster.combatant(for: sourceActorID), source.isAlive
        else { return [] }
        let actor = source.combatant
        let triggers = context.modifiers(for: sourceActorID).triggers
        var events: [ActionEvent] = []
        if triggers.onFreezeEnemyRestoreMana > 0 {
            events.append(contentsOf: context.restoreManaEmitting(
                triggers.onFreezeEnemyRestoreMana, to: actor, abilityName: "Frost Siphon",
            ))
        }
        if triggers.onFreezeEnemyGainBlock > 0 {
            events.append(contentsOf: context.applyBlock(
                triggers.onFreezeEnemyGainBlock,
                to: actor, source: actor, abilityName: "Frost Guard",
            ))
        }
        if triggers.onFreezeBurningEnemyBurnDamage > 0,
           context.roster.hasAffliction(.burn, on: context.roster.enemy.combatant) {
            events.append(contentsOf: heroTalentDamage(
                .burn, amount: triggers.onFreezeBurningEnemyBurnDamage,
                source: actor, name: "Steam Explosion", in: &context,
            ))
        }
        if triggers.onFreezeEnemyDrawCard,
           let owner = context.roster.participant(for: actor) {
            events.append(contentsOf: drawCards(
                1, for: owner, actor: actor, abilityName: "Winter’s Dominion", in: &context,
            ))
        }
        return events
    }
}
