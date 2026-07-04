import Foundation
import TrinketCore
import TrinketContent

/// Rolls for a critical hit after dodge. Doubles `remaining` damage on success.
package struct CriticalGateStep: DamageStep {
    public static let stepName = "CriticalGate"
    public static let phase: DamagePhase = .stochastic

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        guard state.amount > 0,
              state.sourceActorID != nil,
              let damageKeyword = state.damageKeyword,
              let actor = context.roster.combatant(for: state.sourceActorID!)
        else { return }

        var chance = actor.primaryStats.criticalChance(for: damageKeyword)
        chance += state.abilityCriticalChanceBonus

        let sourceEffects = context.activeEffects(for: actor.combatant)
        for active in sourceEffects {
            if case let .criticalChanceBonus(bonus, _) = active.effect {
                chance += bonus
            }
        }

        if state.guaranteedCriticalIfEnemyBuffed,
           context.activeEffects(for: state.combatant).contains(where: { $0.effect.isRemovableBuff }) {
            chance = 1.0
        }

        chance = min(0.75, chance)
        guard Double.random(in: 0 ... 1, using: &context.rng) < chance else { return }

        state.isCritical = true
        state.damageEvents.append(context.nextEvent(
            kind: .effect,
            effectKind: .criticalApplied,
            actorName: actor.name,
            abilityName: "Critical",
            target: state.combatant,
            amount: 0,
            keyword: damageKeyword
        ))
    }
}
