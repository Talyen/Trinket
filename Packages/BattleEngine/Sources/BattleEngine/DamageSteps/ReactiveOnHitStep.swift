import Foundation
import TrinketCore
import TrinketContent

/// Applies Thorns and Mana-on-hit reactive effects after health is lost.
package struct ReactiveOnHitStep: DamageStep {
    public static let stepName = "ReactiveOnHit"
    public static let phase: DamagePhase = .post

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        guard state.healthLost > 0, let sourceActorID = state.sourceActorID else { return }
        guard let attacker = context.roster.combatant(for: sourceActorID) else { return }

        let activeEffects = context.roster.activeEffects(for: state.combatant)
        for active in activeEffects {
            switch active.effect {
            case let .thorns(keyword, amount, _):
                guard amount > 0 else { continue }
                let (_, events) = context.applyDamage(
                    amount,
                    to: attacker,
                    damageKeyword: keyword,
                    sourceActorID: state.combatant.id,
                    applyDodge: true
                )
                var thornsEvents = events
                if let lastIndex = thornsEvents.indices.last {
                    var event = thornsEvents[lastIndex]
                    thornsEvents[lastIndex] = ActionEvent(
                        id: event.id,
                        kind: event.kind,
                        effectKind: .thornsTriggered,
                        actorName: state.combatant.name,
                        abilityName: "Thorns",
                        targetID: event.targetID,
                        targetName: event.targetName,
                        amount: event.amount,
                        keyword: event.keyword,
                        appliedEffectSummaries: event.appliedEffectSummaries,
                        milestone: event.milestone
                    )
                }
                state.damageEvents.append(contentsOf: thornsEvents)
            case let .restoreManaOnHit(amount, _):
                let restored = context.restoreMana(amount, to: state.combatant, sourceActorID: state.combatant.id)
                guard restored > 0 else { continue }
                state.damageEvents.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .manaShieldTriggered,
                    actorName: state.combatant.name,
                    abilityName: "Mana Shield",
                    target: state.combatant,
                    amount: restored,
                    keyword: .mana
                ))
            default:
                continue
            }
        }
    }
}
