import Foundation
import TrinketCore
import TrinketContent

/// Step 6: writes the mutated effects list back to the roster and calls
/// `takeRawDamage` on the target runtime.
package struct TakeDamageStep: DamageStep {
    public static let stepName = "TakeDamage"
    public static let phase: DamagePhase = .resolution

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        context.roster.setActiveEffects(state.activeEffects, for: state.combatant)
        var lost = 0
        context.roster.mutateRuntime(for: state.combatant) { lost = $0.takeRawDamage(state.remaining) }
        state.healthLost = lost
    }
}
