import Foundation
import TrinketContent
import TrinketCore

package extension BattleState {
    mutating func addGold(_ amount: Int, sourceActorID: String) {
        gold += goldGranted(for: amount, sourceActorID: sourceActorID)
    }

    mutating func grantGoldEvent(
        _ amount: Int,
        to combatant: Combatant,
        abilityName: String
    ) -> [ActionEvent] {
        let granted = goldGranted(for: amount, sourceActorID: combatant.id)
        addGold(amount, sourceActorID: combatant.id)
        var events = [nextEvent(
            kind: .effect,
            effectKind: .resourceGain,
            actorName: combatant.name,
            abilityName: abilityName,
            target: combatant,
            amount: granted,
            keyword: .gold
        )]
        events.append(contentsOf: CombatTriggerEngine.healSelfAfterGoldGain(
            source: combatant,
            in: &self
        ).events)
        return events
    }

    /// Flat + percent bonuses applied to an outgoing gold grant (Lucky / Gilded).
    func goldGranted(for amount: Int, sourceActorID: String) -> Int {
        let profile = modifiers(for: sourceActorID)
        let scaled = CombatRounding.scaled(amount, multiplier: 1 + max(0, profile.goldGainedPercent))
        return scaled + profile.goldGainedBonus
    }

    @discardableResult
    mutating func restoreMana(_ amount: Int, to combatant: Combatant) -> Int {
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
        let repeats = ability.hasManaEmpowerableBurnDamage
            && context.modifiers(for: actor.id).triggers.repeatManaEmpowerment
        var events: [ActionEvent] = []
        var purchases = 0
        while purchases == 0 || repeats {
            guard let runtime = context.roster.runtime(for: actor),
                  runtime.maxMana > 0,
                  runtime.currentMana >= manaEmpowermentCost
            else { break }
            let spent = context.spendMana(manaEmpowermentCost, for: actor)
            guard spent >= manaEmpowermentCost else { break }
            purchases += 1
            ability = ability.empoweredByMana(amount: manaEmpowermentBonus)
            events.append(contentsOf: CombatTriggerEngine.afterSpendMana(by: actor, in: &context))
        }
        return events
    }
}
