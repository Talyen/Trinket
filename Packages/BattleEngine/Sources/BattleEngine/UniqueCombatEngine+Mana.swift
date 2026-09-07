import TrinketContent
import TrinketCore

extension UniqueCombatEngine {
    static func afterEmpowermentSpend(
        _ spent: Int,
        previousMana: Int,
        actor: Combatant,
        in context: inout BattleState,
    ) {
        let triggers = context.modifiers(for: actor.id).triggers
        if spent > 0, spent == previousMana,
           triggers.lastManaEmpowermentRepeatsDamage,
           isOrdinaryAction(actorID: actor.id, in: context),
           let owner = context.roster.participant(for: actor),
           context.uniques.owners[owner]?.usedFinalSpark != true {
            context.uniques.owners[owner, default: .init()].usedFinalSpark = true
            context.uniques.card?.repeatDamage = true
        }
    }
}
