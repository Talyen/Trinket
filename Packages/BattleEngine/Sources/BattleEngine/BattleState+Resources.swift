import TrinketContent
import TrinketCore

package extension BattleState {
    mutating func addGold(_ amount: Int, sourceActorID: String) {
        gold += amount + modifiers(for: sourceActorID).goldGainedBonus
    }

    @discardableResult
    mutating func restoreMana(_ amount: Int, to combatant: Combatant, sourceActorID _: String) -> Int {
        guard var runtime = roster.runtime(for: combatant) else { return 0 }
        let actual = runtime.restoreMana(amount)
        roster.update(runtime)
        return actual
    }

    @discardableResult
    mutating func spendMana(_ amount: Int, for combatant: Combatant) -> Int {
        guard var runtime = roster.runtime(for: combatant) else { return 0 }
        let actual = runtime.spendMana(amount)
        roster.update(runtime)
        return actual
    }
}

public extension BattleTurnEngine {
    /// Spends 1 Mana to raise Burn/Freeze damage numbers on `ability` when available.
    @discardableResult
    static func spendManaToEmpowerBurnOrFreezeIfNeeded(
        for ability: inout Ability,
        actor: Combatant,
        context: inout BattleEngineContext
    ) -> [ActionEvent] {
        guard ability.hasManaEmpowerableBurnOrFreezeDamage else { return [] }
        guard let runtime = context.roster.runtime(for: actor),
              runtime.maxMana > 0,
              runtime.currentMana >= 1
        else { return [] }
        let spent = context.spendMana(1, for: actor)
        guard spent > 0 else { return [] }
        ability = ability.empoweredByMana(amount: 1)
        return CombatReactionEngine.afterSpendMana(by: actor, in: &context)
    }
}
