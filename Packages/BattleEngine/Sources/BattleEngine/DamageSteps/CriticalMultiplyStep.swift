import Foundation
import TrinketCore
import TrinketContent

/// Doubles remaining damage when the hit critically strikes.
package struct CriticalMultiplyStep: DamageStep {
    public static let stepName = "CriticalMultiply"
    public static let phase: DamagePhase = .resolution

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        _ = context
        guard state.isCritical, state.remaining > 0 else { return }
        state.remaining *= 2
        state.dealt = state.remaining
    }
}
