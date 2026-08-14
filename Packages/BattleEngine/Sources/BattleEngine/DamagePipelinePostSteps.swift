import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    // MARK: - Post steps

    static func applyLeech(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        guard state.healthLost > 0,
              let sourceActorID = state.sourceActorID,
              sourceActorID != state.combatant.id
        else { return }
        let leechOutcome = HealingEngine.leechFromDamage(
            state.healthLost,
            sourceActorID: sourceActorID,
            abilityHasLeech: state.abilityHasLeech,
            damageKeyword: state.damageKeyword,
            in: &context
        )
        state.damageEvents.append(contentsOf: leechOutcome.events)
    }

    static func applyKeywordReactions(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        guard state.healthLost > 0,
              let keyword = state.damageKeyword,
              let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID),
              source.role != .enemy
        else { return }

        switch keyword {
        case .holy:
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterHolyDamageDealt(
                to: state.combatant,
                source: source.combatant,
                in: &context
            ))
        case .stun:
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterStunDamageDealt(
                to: state.combatant,
                source: source.combatant,
                in: &context
            ))
        case .burn:
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterBurnDamageDealt(
                to: state.combatant,
                source: source.combatant,
                in: &context
            ))
        default:
            break
        }
    }

    static func applyTrinketDamageReactions(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        guard let sourceActorID = state.sourceActorID,
              let sourceRuntime = context.roster.combatant(for: sourceActorID),
              sourceRuntime.role != .enemy,
              let keyword = state.damageKeyword
        else { return }
        let source = sourceRuntime.combatant
        let triggers = context.modifiers(for: sourceActorID).triggers

        if keyword == .bleed, state.healthLost > 0, triggers.bleedDamageGoldFlat > 0 {
            state.damageEvents.append(contentsOf: context.grantGoldEvent(
                triggers.bleedDamageGoldFlat,
                to: source,
                abilityName: "Cutpurse Knife"
            ))
        }

        guard state.isAttackHit else { return }
        if keyword == .physical, state.buildupDamage > 0, triggers.physicalStunBuildupPercent > 0 {
            let buildup = CombatRounding.scaled(
                state.buildupDamage,
                multiplier: triggers.physicalStunBuildupPercent
            )
            state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                buildup,
                keyword: .stun,
                to: state.combatant,
                sourceActorID: sourceActorID,
                applyFightPacing: false,
                in: &context
            ))
        }
        if keyword == .physical, state.buildupDamage > 0, triggers.physicalDamageBlockPercent > 0 {
            let block = CombatRounding.scaled(
                state.buildupDamage,
                multiplier: triggers.physicalDamageBlockPercent
            )
            if block > 0 {
                state.damageEvents.append(contentsOf: context.applyBlock(
                    block,
                    to: source,
                    source: source,
                    abilityName: "Vanguard's Crest"
                ))
            }
        }
    }

    static func applyCriticalReaction(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        guard state.isCritical,
              state.healthLost > 0,
              let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID),
              source.role != .enemy,
              state.combatant.role == .enemy
        else { return }
        state.damageEvents.append(contentsOf: CombatTriggerEngine.afterCriticalHit(
            to: state.combatant,
            source: source.combatant,
            in: &context
        ))
    }

    static func applyControlMeter(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        // Buildup uses post-mitigation / post-crit damage before shields
        // (`buildupDamage`). Shields protect health, not control meters.
        guard state.buildupDamage > 0,
              let damageKeyword = state.damageKeyword,
              damageKeyword == .stun || damageKeyword == .freeze,
              !state.isRetaliation || state.applyControlMeter,
              context.roster.health(for: state.combatant) > 0
        else { return }
        // `buildupDamage` is post-mitigation damage already fight-paced in resolution.
        state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
            state.buildupDamage,
            keyword: damageKeyword,
            to: state.combatant,
            sourceActorID: state.sourceActorID,
            applyFightPacing: false,
            in: &context
        ))
    }

    static func applyReactiveOnHit(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        // Retaliation damage must never re-enter wards (mutual thorns ping-pong).
        guard !state.isDodged, !state.isRetaliation, let sourceActorID = state.sourceActorID else { return }
        guard let attacker = context.roster.combatant(for: sourceActorID) else { return }

        if state.healthLost > 0, let damageKeyword = state.damageKeyword {
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
            state.damageEvents.append(contentsOf: EnemyTraitEngine.traitThornsDamage(
                damageTaken: state.healthLost,
                defender: state.combatant,
                attackerID: sourceActorID,
                in: &context
            ))
            state.damageEvents.append(contentsOf: EnemyTraitEngine.traitAttackerBurn(
                defender: state.combatant,
                attackerID: sourceActorID,
                in: &context
            ))
        }

        if state.healthLost > 0 {
            applyManaShieldOnHit(to: &state, in: &context)
        }

        // Thorns and freeze-next-attacker fire for direct attack hits (including fully blocked).
        if state.isAttackHit {
            applyOnHitWards(to: &state, attacker: attacker, in: &context)
        }
    }

    private static func applyManaShieldOnHit(
        to state: inout DamageResolutionState,
        in context: inout BattleState
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
                keyword: .mana
            ))
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterGainMana(
                by: state.combatant,
                in: &context
            ))
        }
    }

    private struct OnHitWardTotals {
        var thornsStacks = 0
        var freezeOnHitAmount = 0
        var shouldFreezeAttacker = false
    }

    private static func onHitWardTotals(from effects: [ActiveEffect]) -> OnHitWardTotals {
        var totals = OnHitWardTotals()
        for active in effects {
            switch active.effect {
            case let .thorns(amount):
                totals.thornsStacks += amount
            case let .freezeOnHit(amount):
                totals.freezeOnHitAmount += amount
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
        in context: inout BattleState
    ) {
        let wards = onHitWardTotals(from: context.roster.activeEffects(for: state.combatant))

        // Consume wards before nested resolveDamage so mutual thorns cannot recurse
        // even if a retaliation path forgets `isRetaliation`.
        if wards.thornsStacks > 0 {
            ActiveEffectMutation.removeMatching(from: state.combatant, in: &context) {
                if case .thorns = $0 {
                    return true
                }
                return false
            }
            appendRetaliationDamage(
                amount: wards.thornsStacks,
                keyword: .physical,
                abilityName: "Thorns",
                attacker: attacker,
                to: &state,
                in: &context
            )
        }

        if wards.freezeOnHitAmount > 0 {
            ActiveEffectMutation.removeMatching(from: state.combatant, in: &context) {
                if case .freezeOnHit = $0 {
                    return true
                }
                return false
            }
            appendRetaliationDamage(
                amount: wards.freezeOnHitAmount,
                keyword: .freeze,
                abilityName: "Glacial Ward",
                attacker: attacker,
                to: &state,
                in: &context
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
        state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
            threshold,
            keyword: .freeze,
            to: attacker.combatant,
            sourceActorID: state.combatant.id,
            in: &context
        ))
    }

    private static func appendRetaliationDamage(
        amount: Int,
        keyword: Keyword,
        abilityName: String,
        attacker: CombatantRuntime,
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        guard amount > 0 else { return }
        let outcome = context.resolveDamage(
            DamageRequest(
                amount: amount,
                target: attacker.combatant,
                keyword: keyword,
                sourceActorID: state.combatant.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    isRetaliation: true
                )
            )
        )
        var retaliationEvents = outcome.events
        if let lastIndex = retaliationEvents.indices.last {
            let event = retaliationEvents[lastIndex]
            retaliationEvents[lastIndex] = event.with(
                effectKind: .thornsTriggered,
                actorID: state.combatant.id,
                actorName: state.combatant.name,
                abilityName: abilityName
            )
        } else if outcome.healthLost > 0 {
            retaliationEvents.append(context.nextEvent(
                kind: .effect,
                effectKind: .thornsTriggered,
                actorName: state.combatant.name,
                abilityName: abilityName,
                target: attacker.combatant,
                amount: outcome.healthLost,
                keyword: keyword
            ))
        }
        state.damageEvents.append(contentsOf: retaliationEvents)
    }
}
