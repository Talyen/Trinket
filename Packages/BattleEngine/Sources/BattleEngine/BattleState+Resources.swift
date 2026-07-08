import TrinketContent
import TrinketCore

extension BattleState {
    package mutating func addGold(_ amount: Int, sourceActorID: String) {
        gold += amount + modifiers(for: sourceActorID).goldGainedBonus
    }

    package mutating func restoreMana(_ amount: Int, to combatant: Combatant, sourceActorID _: String) -> Int {
        guard var runtime = roster.runtime(for: combatant) else { return 0 }
        let actual = runtime.restoreMana(amount)
        roster.update(runtime)
        return actual
    }

    @discardableResult
    package mutating func spendMana(_ amount: Int, for combatant: Combatant) -> Int {
        guard var runtime = roster.runtime(for: combatant) else { return 0 }
        let actual = runtime.spendMana(amount)
        roster.update(runtime)
        return actual
    }
}
