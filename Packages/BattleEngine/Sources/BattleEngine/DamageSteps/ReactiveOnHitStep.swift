import Foundation
import TrinketCore
import TrinketContent

/// Applies Thorns, trait thorns, shield erosion, and mitigation shred after health is lost.
package struct ReactiveOnHitStep: DamageStep {
    public static let stepName = "ReactiveOnHit"
    public static let phase: DamagePhase = .post

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        guard state.healthLost > 0, let sourceActorID = state.sourceActorID else { return }
        guard let attacker = context.roster.combatant(for: sourceActorID) else { return }

        if let damageKeyword = state.damageKeyword {
            EnemyTraitEngine.applyShieldErosion(
                keyword: damageKeyword,
                to: state.combatant,
                context: &context
            )
            EnemyTraitEngine.applyMitigationShred(
                keyword: damageKeyword,
                to: state.combatant,
                context: &context
            )
        }

        state.damageEvents.append(contentsOf: EnemyTraitEngine.traitThornsDamage(
            damageTaken: state.healthLost,
            defender: state.combatant,
            attackerID: sourceActorID,
            in: &context
        ))

        let activeEffects = context.roster.activeEffects(for: state.combatant)
        for active in activeEffects {
            switch active.effect {
            case let .thorns(keyword, amount, _):
                guard amount > 0 else { continue }
                let events = context.resolveDamage(
                    DamageRequest(
                        amount: amount,
                        target: attacker.combatant,
                        keyword: keyword,
                        sourceActorID: state.combatant.id,
                        options: DamageOptions(isRetaliation: true)
                    )
                ).events
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
