import Foundation
import TrinketCore
import TrinketContent

/// Step 8: for `.stun` or `.freeze` keywords, applies control-meter
/// buildup against the target using HP damage dealt after shields.
package struct ControlMeterStep: DamageStep {
    public static let stepName = "ControlMeter"
    public static let phase: DamagePhase = .post

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        guard state.healthLost > 0,
              let damageKeyword = state.damageKeyword,
              damageKeyword == .stun || damageKeyword == .freeze,
              context.roster.health(for: state.combatant) > 0
        else { return }
        state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
            state.healthLost,
            keyword: damageKeyword,
            to: state.combatant,
            sourceActorID: state.sourceActorID,
            in: &context
        ))
    }
}
