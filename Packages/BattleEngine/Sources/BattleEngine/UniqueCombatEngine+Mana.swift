import TrinketContent
import TrinketCore

extension UniqueCombatEngine {
    static func payEmpowerment(
        _ cost: Int,
        ability: Ability,
        actor: Combatant,
        in context: inout BattleState,
    ) -> Int? {
        guard let runtime = context.roster.runtime(for: actor) else { return nil }
        let mana = min(cost, runtime.currentMana)
        let shortfall = cost - mana
        let triggers = context.modifiers(for: actor.id).triggers
        let rate = ability.keywords.contains(.freeze) ? triggers.freezeEmpowermentBlockPerMana : 0
        guard shortfall == 0 || rate > 0 else { return nil }
        let blockCost = shortfall * rate
        let block = DefensePoolEngine.blockPoints(in: runtime.activeEffects)
        guard block >= blockCost else { return nil }
        if blockCost > 0 {
            DefensePoolEngine.set(block - blockCost, on: actor, in: &context)
        }
        let spent = context.spendMana(mana, for: actor)
        if spent > 0, spent == runtime.currentMana,
           triggers.lastManaEmpowermentRepeatsDamage,
           isOrdinaryAction(actorID: actor.id, in: context),
           let owner = context.roster.participant(for: actor),
           context.uniques.owners[owner]?.usedFinalSpark != true {
            context.uniques.owners[owner, default: .init()].usedFinalSpark = true
            context.uniques.card?.repeatDamage = true
        }
        return spent
    }
}
