import Foundation
import TrinketContent
import TrinketCore

package extension BattleState {
    mutating func addGold(_ amount: Int, sourceActorID: String) {
        gold += goldGranted(for: amount, sourceActorID: sourceActorID)
    }

    /// Flat + percent bonuses applied to an outgoing gold grant (Lucky / Gilded).
    func goldGranted(for amount: Int, sourceActorID: String) -> Int {
        let profile = modifiers(for: sourceActorID)
        let scaled = CombatRounding.scaled(amount, multiplier: 1 + max(0, profile.goldGainedPercent))
        return scaled + profile.goldGainedBonus
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
    /// Mana spent per +1 Burn/Freeze empowerment on a card play.
    static let manaEmpowermentCost = 3
    /// Burn/Freeze damage added per empowerment purchase.
    static let manaEmpowermentBonus = 1

    /// Spends `manaEmpowermentCost` Mana to raise Burn/Freeze damage numbers on `ability` by
    /// `manaEmpowermentBonus` when the actor can afford it.
    @discardableResult
    static func spendManaToEmpowerBurnOrFreezeIfNeeded(
        for ability: inout Ability,
        actor: Combatant,
        context: inout BattleState
    ) -> [ActionEvent] {
        guard ability.hasManaEmpowerableBurnOrFreezeDamage else { return [] }
        guard let runtime = context.roster.runtime(for: actor),
              runtime.maxMana > 0,
              runtime.currentMana >= manaEmpowermentCost
        else { return [] }
        let spent = context.spendMana(manaEmpowermentCost, for: actor)
        guard spent >= manaEmpowermentCost else { return [] }
        ability = ability.empoweredByMana(amount: manaEmpowermentBonus)
        return CombatReactionEngine.afterSpendMana(by: actor, in: &context)
    }
}
