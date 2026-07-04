import Foundation
import TrinketCore
import TrinketContent

/// Step 7: heals the attacker when `healthLost > 0`, leech is active, and
/// the hit was not self-inflicted.
package struct LeechStep: DamageStep {
    public static let stepName = "Leech"
    public static let phase: DamagePhase = .post

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        guard state.healthLost > 0,
              let sourceActorID = state.sourceActorID,
              sourceActorID != state.combatant.id
        else { return }
        let leechOutcome = HealingEngine.leechFromDamage(
            state.healthLost,
            sourceActorID: sourceActorID,
            in: &context
        )
        state.damageEvents.append(contentsOf: leechOutcome.events)
    }
}
