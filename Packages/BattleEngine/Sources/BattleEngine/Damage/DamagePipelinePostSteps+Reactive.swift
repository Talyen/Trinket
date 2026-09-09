import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyReactiveOnHit(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard !state.isDodged, !state.options.isRetaliation, let sourceActorID = state.sourceActorID else { return }
        guard let attacker = context.roster.combatant(for: sourceActorID) else { return }

        if state.options.isAttackHit {
            context.roster.mutateRuntime(for: state.combatant) { $0.hasTakenAttackHitThisTurn = true }
        }

        applyNimbleFang(to: &state, attacker: attacker, sourceActorID: sourceActorID, in: &context)

        if state.healthLost > 0 {
            applyEnemyTraitReactions(
                to: &state,
                sourceActorID: sourceActorID,
                in: &context,
            )
            applyOnHitAttackerWards(to: &state, attacker: attacker, in: &context)
            applyManaShieldOnHit(to: &state, in: &context)
        }

        if state.options.isAttackHit {
            applyOnHitWards(to: &state, attacker: attacker, in: &context)
        }
    }

    private static func applyNimbleFang(
        to state: inout DamageResolutionState,
        attacker: CombatantRuntime,
        sourceActorID: String,
        in context: inout BattleState,
    ) {
        guard state.options.isAttackHit,
              let runtime = context.roster.runtime(for: attacker.combatant),
              runtime.pendingBleedAfterDodge > 0
        else { return }
        let potency = runtime.pendingBleedAfterDodge
        context.roster.mutateRuntime(for: attacker.combatant) { $0.pendingBleedAfterDodge = 0 }
        state.damageEvents.append(contentsOf: appendBleed(
            potency: potency,
            to: state.combatant,
            sourceActorID: sourceActorID,
            in: &context,
        ))
    }

    private static func applyEnemyTraitReactions(
        to state: inout DamageResolutionState,
        sourceActorID: String,
        in context: inout BattleState,
    ) {
        state.damageEvents.append(contentsOf: EnemyTraitEngine.traitThornsDamage(
            damageTaken: state.healthLost,
            defender: state.combatant,
            attackerID: sourceActorID,
            in: &context,
        ))
        state.damageEvents.append(contentsOf: EnemyTraitEngine.traitAttackerBurn(
            defender: state.combatant,
            attackerID: sourceActorID,
            in: &context,
        ))
    }

    private static func applyOnHitAttackerWards(
        to state: inout DamageResolutionState,
        attacker: CombatantRuntime,
        in context: inout BattleState,
    ) {
        let defenderTriggers = context.modifiers(for: state.combatant.id).triggers
        if defenderTriggers.onHitAttackerFreezeBuildup > 0, context.roster.health(for: attacker.combatant) > 0 {
            state.damageEvents.append(contentsOf: appendMeterCharge(
                defenderTriggers.onHitAttackerFreezeBuildup,
                keyword: .freeze,
                to: attacker.combatant,
                sourceActorID: state.combatant.id,
                in: &context,
            ))
        }
        if defenderTriggers.onHitAttackerPoison > 0, context.roster.health(for: attacker.combatant) > 0 {
            state.damageEvents.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison,
                potency: defenderTriggers.onHitAttackerPoison,
                to: attacker.combatant,
                sourceActorID: state.combatant.id,
                dealImmediateDamage: false,
                suppressAffixReactions: true,
            ))
        }
        if defenderTriggers.onHitAttackerBleedPotency > 0, context.roster.health(for: attacker.combatant) > 0 {
            state.damageEvents.append(contentsOf: appendBleed(
                potency: defenderTriggers.onHitAttackerBleedPotency,
                to: attacker.combatant,
                sourceActorID: state.combatant.id,
                durationTurns: defenderTriggers.onHitAttackerBleedTurns > 0
                    ? defenderTriggers.onHitAttackerBleedTurns
                    : nil,
                in: &context,
            ))
        }
        if defenderTriggers.onHitAttackerHoly > 0, context.roster.health(for: attacker.combatant) > 0 {
            state.damageEvents.append(contentsOf: resolveRetaliation(
                amount: defenderTriggers.onHitAttackerHoly,
                keyword: .holy,
                target: attacker.combatant,
                sourceActorID: state.combatant.id,
                in: &context,
            ).events)
        }
    }

    private static func applyManaShieldOnHit(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        let activeEffects = context.roster.activeEffects(for: state.combatant)
        for active in activeEffects {
            guard case let .restoreManaOnHit(amount, _) = active.effect else { continue }
            let pacedAmount = context.paced(amount, sourceActorID: state.combatant.id)
            let restored = context.restoreMana(pacedAmount, to: state.combatant)
            guard restored > 0 else { continue }
            state.damageEvents.append(context.nextEvent(
                kind: .effect,
                effectKind: .manaShieldTriggered,
                actorName: state.combatant.name,
                abilityName: "Mana Shield",
                target: state.combatant,
                amount: restored,
                keyword: .mana,
            ))
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterGainMana(
                by: state.combatant,
                in: &context,
            ))
        }
    }

    private struct OnHitWardTotals {
        var thornsStacks = 0
        var onHitDamage: [Keyword: Int] = [:]
        var shouldFreezeAttacker = false
    }

    private static func onHitWardTotals(from effects: [ActiveEffect]) -> OnHitWardTotals {
        var totals = OnHitWardTotals()
        for active in effects {
            switch active.effect {
            case let .thorns(amount):
                totals.thornsStacks += amount
            case let .onHitDamage(keyword, amount):
                totals.onHitDamage[keyword, default: 0] += amount
            case .freezeNextAttacker:
                totals.shouldFreezeAttacker = true
            default:
                continue
            }
        }
        return totals
    }

    private static func applyOnHitWards(
        to state: inout DamageResolutionState,
        attacker: CombatantRuntime,
        in context: inout BattleState,
    ) {
        let wards = onHitWardTotals(from: context.roster.activeEffects(for: state.combatant))

        applyThornsRetaliation(amount: wards.thornsStacks, attacker: attacker, to: &state, in: &context)

        if context.modifiers(for: state.combatant.id).triggers.onHitGainBlock > 0 {
            state.damageEvents.append(contentsOf: context.applyBlock(
                context.modifiers(for: state.combatant.id).triggers.onHitGainBlock,
                to: state.combatant,
                source: state.combatant,
                abilityName: CombatTriggerEngine.triggerAbilityName(
                    "onHitGainBlock",
                    for: state.combatant,
                    fallback: "Plated Hide",
                    in: context,
                ),
            ))
        }

        for (keyword, amount) in wards.onHitDamage.sorted(by: { $0.key.rawValue < $1.key.rawValue }) where amount > 0 {
            ActiveEffectMutation.removeMatching(from: state.combatant, in: &context) {
                if case let .onHitDamage(existingKeyword, _) = $0 {
                    return existingKeyword == keyword
                }
                return false
            }
            appendRetaliationDamage(
                amount: amount,
                keyword: keyword,
                abilityName: keyword == .freeze ? "Glacial Ward" : "\(keyword.rawValue) Ward",
                attacker: attacker,
                to: &state,
                in: &context,
            )
        }

        guard wards.shouldFreezeAttacker else { return }
        ActiveEffectMutation.removeMatching(from: state.combatant, in: &context) {
            if case .freezeNextAttacker = $0 {
                return true
            }
            return false
        }
        let threshold = ControlMeterEngine.threshold(for: attacker.combatant, in: context)
        state.damageEvents.append(contentsOf: appendMeterCharge(
            threshold,
            keyword: .freeze,
            to: attacker.combatant,
            sourceActorID: state.combatant.id,
            applyFightPacing: true,
            in: &context,
        ))
    }

    private static func applyThornsRetaliation(
        amount: Int,
        attacker: CombatantRuntime,
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard amount > 0 else { return }
        ActiveEffectMutation.removeMatching(from: state.combatant, in: &context) {
            if case .thorns = $0 {
                return true
            }
            return false
        }
        let keyword: Keyword = if context.modifiers(for: state.combatant.id).triggers.resonantShell {
            .stun
        } else if state.combatant.role == .companion, context.roster.hero.isAlive, context.heroModifiers.triggers.thornShedding {
            .poison
        } else {
            .physical
        }
        appendRetaliationDamage(
            amount: amount,
            keyword: keyword,
            abilityName: "Thorns",
            attacker: attacker,
            to: &state,
            in: &context,
        )
        if keyword == .poison {
            state.damageEvents.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison, potency: amount, to: attacker.combatant,
                sourceActorID: state.combatant.id, dealImmediateDamage: false, suppressAffixReactions: true,
            ))
        }
    }

    private static func appendRetaliationDamage(
        amount: Int,
        keyword: Keyword,
        abilityName: String,
        attacker: CombatantRuntime,
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard amount > 0 else { return }
        let outcome = resolveRetaliation(
            amount: amount,
            keyword: keyword,
            target: attacker.combatant,
            sourceActorID: state.combatant.id,
            controlMeter: keyword == .stun || keyword == .freeze,
            in: &context,
        )
        var retaliationEvents = outcome.events
        if outcome.healthLost > 0 {
            retaliationEvents.append(context.nextEvent(
                kind: .effect,
                effectKind: .thornsTriggered,
                actorName: state.combatant.name,
                abilityName: abilityName,
                target: attacker.combatant,
                amount: outcome.healthLost,
                keyword: keyword,
            ))
        }
        state.damageEvents.append(contentsOf: retaliationEvents)
    }
}
