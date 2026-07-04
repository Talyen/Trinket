import Foundation
import TrinketCore
import TrinketContent

/// Step 5: iterates the target's active shield effects, absorbing as much
/// of `remaining` as each shield can cover, emitting `.shieldAbsorbed`
/// events, and mutating the effects list. Depleted shields are removed.
package struct ShieldAbsorptionStep: DamageStep {
    public static let stepName = "ShieldAbsorption"
    public static let phase: DamagePhase = .resolution

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        var effects = context.roster.activeEffects(for: state.combatant)
        var shieldIndexes: [Int] = []

        for (index, ae) in effects.enumerated() {
            if case let .shield(keyword, buffer, _) = ae.effect {
                let absorbed = min(state.remaining, buffer)
                state.remaining -= absorbed
                if absorbed > 0 {
                    state.damageEvents.append(context.nextEvent(
                        kind: .effect,
                        effectKind: .shieldAbsorbed,
                        actorName: keyword.rawValue,
                        abilityName: keyword.rawValue,
                        target: state.combatant,
                        amount: absorbed,
                        keyword: keyword,
                        appliedEffectSummaries: [],
                        milestone: nil
                    ))
                    let newBuffer = buffer - absorbed
                    let newEffect: Effect = .shield(keyword, newBuffer, ae.effect.durationTicks)
                    effects[index] = ActiveEffect(
                        id: ae.id,
                        effect: newEffect,
                        remainingTicks: ae.remainingTicks
                    )
                    if newBuffer <= 0 {
                        shieldIndexes.append(index)
                    }
                }
            }
        }

        for index in shieldIndexes.reversed() {
            effects.remove(at: index)
        }
        state.activeEffects = effects
    }
}
