import Foundation
import TrinketCore
import TrinketContent

/// Step 1: gates the entire damage call on a dodge roll. When the roll
/// succeeds, the event stream records a `.dodgeApplied` event and the
/// orchestrator short-circuits.
package struct DodgeGateStep: DamageStep {
    public static let stepName = "DodgeGate"
    public static let phase: DamagePhase = .stochastic

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        guard state.applyDodge,
              state.amount > 0,
              context.roster.health(for: state.combatant) > 0,
              state.sourceActorID != nil
        else { return }
        let chance = state.combatant.primaryStats.dodgeChance
        if Double.random(in: 0 ... 1, using: &context.rng) < chance {
            state.damageEvents.append(context.nextEvent(
                kind: .effect,
                effectKind: .dodgeApplied,
                actorName: state.combatant.name,
                abilityName: "Dodge",
                target: state.combatant,
                amount: 0,
                keyword: .dodge,
                appliedEffectSummaries: [],
                milestone: nil
            ))
            state.isDodged = true
        }
    }
}
