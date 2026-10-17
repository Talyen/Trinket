import TrinketContent
import TrinketCore

extension EffectHandlers {
    static func summarizeMaximumManaBonus(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = CombatantMaxValues.maximumManaBonus(in: stacks)
        guard total > 0 else { return nil }
        return EffectSummary(keyword: keyword, text: "Maximum Mana: Increases Maximum Mana by +\(total)")
    }
}

package extension BattleState {
    @discardableResult
    mutating func reviveEmitting(
        _ target: Combatant,
        health: Int,
        source: Combatant,
        abilityID: String = "",
        abilityName: String,
        origin: ActionEvent.Origin = .automatic,
    ) -> Int {
        guard health > 0, let runtime = roster.runtime(for: target), !runtime.isAlive else { return 0 }
        let revivedHealth = min(health, runtime.maxHealth)
        guard revivedHealth > 0 else { return 0 }
        roster.mutateRuntime(for: target) { $0.currentHealth = revivedHealth }
        nextEvent(
            kind: .effect(.instantHeal),
            source: .init(source),
            abilityID: abilityID, abilityName: abilityName,
            target: target,
            amount: revivedHealth,
            keyword: .health,
            origin: origin,
        )
        return revivedHealth
    }
}
