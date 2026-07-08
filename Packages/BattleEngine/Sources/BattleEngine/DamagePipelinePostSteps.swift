import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    // MARK: - Post steps

    static func applyLeech(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
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

    static func applyControlMeter(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        // Buildup uses post-mitigation / post-crit damage before shields
        // (`buildupDamage`). Shields protect health, not control meters.
        guard state.buildupDamage > 0,
              let damageKeyword = state.damageKeyword,
              damageKeyword == .stun || damageKeyword == .freeze,
              context.roster.health(for: state.combatant) > 0
        else { return }
        state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
            state.buildupDamage,
            keyword: damageKeyword,
            to: state.combatant,
            sourceActorID: state.sourceActorID,
            in: &context
        ))
    }

    static func applyReactiveOnHit(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
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

        applyActiveReactiveEffects(to: &state, attacker: attacker, in: &context)
    }

    private static func applyActiveReactiveEffects(
        to state: inout DamageResolutionState,
        attacker: CombatantRuntime,
        in context: inout BattleEngineContext
    ) {
        let activeEffects = context.roster.activeEffects(for: state.combatant)
        for active in activeEffects {
            switch active.effect {
            case let .thorns(keyword, amount, _):
                appendThornsRetaliation(
                    amount: amount,
                    keyword: keyword,
                    attacker: attacker,
                    to: &state,
                    in: &context
                )
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

    private static func appendThornsRetaliation(
        amount: Int,
        keyword: Keyword,
        attacker: CombatantRuntime,
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        guard amount > 0 else { return }
        let outcome = context.resolveDamage(
            DamageRequest(
                amount: amount,
                target: attacker.combatant,
                keyword: keyword,
                sourceActorID: state.combatant.id,
                options: DamageOptions(applyDodge: false, isRetaliation: true)
            )
        )
        var thornsEvents = outcome.events
        if let lastIndex = thornsEvents.indices.last {
            let event = thornsEvents[lastIndex]
            thornsEvents[lastIndex] = ActionEvent(
                id: event.id,
                kind: event.kind,
                effectKind: .thornsTriggered,
                actorID: state.combatant.id,
                actorName: state.combatant.name,
                abilityID: event.abilityID,
                abilityName: "Thorns",
                abilityTier: event.abilityTier,
                targetID: event.targetID,
                targetName: event.targetName,
                amount: event.amount,
                keyword: event.keyword,
                appliedEffectSummaries: event.appliedEffectSummaries,
                milestone: event.milestone
            )
        } else if outcome.healthLost > 0 {
            thornsEvents.append(context.nextEvent(
                kind: .effect,
                effectKind: .thornsTriggered,
                actorName: state.combatant.name,
                abilityName: "Thorns",
                target: attacker.combatant,
                amount: outcome.healthLost,
                keyword: keyword
            ))
        }
        state.damageEvents.append(contentsOf: thornsEvents)
    }
}
