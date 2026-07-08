import Foundation
import TrinketContent
import TrinketCore

/// Intrinsic battle rule: hero and pet each get one Death's Door proc per battle.
package enum DeathsDoorEngine {
    public static func applies(to combatant: Combatant) -> Bool {
        combatant.role == .hero || combatant.role == .pet
    }

    public static func isActive(for combatant: Combatant, in context: BattleEngineContext) -> Bool {
        context.roster.isDeathsDoorActive(for: combatant)
    }

    public static func resolveAfterDamage(
        to combatant: Combatant,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        guard applies(to: combatant) else { return [] }

        let health = context.roster.health(for: combatant)
        if health == 0 {
            if !context.roster.hasConsumedDeathsDoor(for: combatant) {
                return trigger(on: combatant, in: &context)
            }
            if isActive(for: combatant, in: context) {
                clampToMinimumHP(on: combatant, in: &context)
            }
        } else if isActive(for: combatant, in: context), health < 1 {
            clampToMinimumHP(on: combatant, in: &context)
        }
        return []
    }

    private static func trigger(
        on combatant: Combatant,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        context.roster.mutateRuntime(for: combatant) { runtime in
            runtime.hasConsumedDeathsDoor = true
            runtime.currentHealth = 1
        }

        let duration = BattleTiming.deathsDoorDurationTicks
        context.prependEffect(
            .deathsDoor,
            to: combatant,
            remainingTicks: duration
        )

        let event = context.nextEvent(
            kind: .effect,
            effectKind: .deathsDoorTriggered,
            actorName: combatant.name,
            abilityName: Keyword.deathsDoor.rawValue,
            target: combatant,
            amount: 0,
            keyword: .deathsDoor
        )
        return [event]
    }

    private static func clampToMinimumHP(
        on combatant: Combatant,
        in context: inout BattleEngineContext
    ) {
        context.roster.mutateRuntime(for: combatant) { runtime in
            runtime.currentHealth = max(1, runtime.currentHealth)
        }
    }
}
