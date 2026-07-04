import Foundation
import TrinketCore
import TrinketContent

/// Step 3: applies armor (from active `.mitigation` effects) plus passive
/// toughness mitigation, capped at 100%. Runs before item reduction and shields.
package struct MitigationStep: DamageStep {
    public static let stepName = "Mitigation"
    public static let phase: DamagePhase = .resolution

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        let effects = context.roster.activeEffects(for: state.combatant)
        let profile = context.modifiers(for: state.combatant.id)
        var armorPct = effects.reduce(0.0) { sum, ae in
            if case let .mitigation(_, p, _) = ae.effect { return sum + p }
            return sum
        }
        armorPct += profile.passiveArmorPercent
        if let runtime = context.roster.runtime(for: state.combatant),
           runtime.mitigationShredUntilTick > context.tickCount {
            armorPct *= runtime.mitigationShredMultiplier
        }
        if profile.armorEffectivenessPenaltyPercent > 0 {
            armorPct *= max(0, 1 - profile.armorEffectivenessPenaltyPercent)
        }
        let toughnessPct = state.combatant.primaryStats.toughnessMitigationPct
        let combinedPct = max(0, min(1, armorPct + toughnessPct))
        if combinedPct > 0 {
            state.remaining = Int(ceil(Double(state.remaining) * (1 - combinedPct)))
        }
    }
}
