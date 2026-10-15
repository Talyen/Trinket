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
    mutating func reviveEmitting(
        _ target: Combatant,
        health: Int,
        source: Combatant,
        abilityID: String = "",
        abilityName: String,
        origin: ActionEvent.Origin = .automatic,
    ) {
        guard health > 0, roster.health(for: target) <= 0 else { return }
        var revivedHealth = 0
        roster.mutateRuntime(for: target) { runtime in
            runtime.currentHealth = min(health, runtime.maxHealth)
            revivedHealth = runtime.currentHealth
        }
        nextEvent(
            kind: .effect(.instantHeal),
            source: .init(source),
            abilityID: abilityID, abilityName: abilityName,
            target: target,
            amount: revivedHealth,
            keyword: .health,
            origin: origin,
        )
    }
}
