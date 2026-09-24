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
            context.roster.mutateRuntime(for: state.combatant) { $0.talents.turn.tookAttackHit = true }
        }

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
            let freeze = context.modifiers(for: state.combatant.id).triggers.onHitAttackerFreezeBuildup
            if freeze > 0 {
                appendNestedDamage(
                    amount: freeze,
                    keyword: .freeze,
                    abilityName: CombatTriggerEngine.triggerAbilityName(
                        "onHitAttackerFreezeBuildup", for: state.combatant, fallback: "Chilling Scales", in: context,
                    ),
                    target: attacker.combatant,
                    defender: state.combatant,
                    to: &state,
                    in: &context,
                )
            }
            applyOnHitWards(to: &state, attacker: attacker, in: &context)
        }
    }

    static func applyNimbleFang(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.options.isAttackHit,
              let sourceActorID = state.sourceActorID,
              let attacker = context.roster.combatant(for: sourceActorID),
              let runtime = context.roster.runtime(for: attacker.combatant),
              runtime.talents.pending.bleedAfterDodge > 0
        else { return }
        let potency = runtime.talents.pending.bleedAfterDodge
        context.roster.mutateRuntime(for: attacker.combatant) { $0.talents.pending.bleedAfterDodge = 0 }
        appendTargetBleed(potency: potency, state: &state, context: &context)
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
        if defenderTriggers.onHitAttackerPoison > 0, context.roster.health(for: attacker.combatant) > 0 {
            state.damageEvents.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison,
                potency: defenderTriggers.onHitAttackerPoison,
                to: attacker.combatant,
                sourceActorID: state.combatant.id,
                application: .reaction,
            ))
        }
        if defenderTriggers.onHitAttackerBleedPotency > 0, context.roster.health(for: attacker.combatant) > 0 {
            state.damageEvents.append(contentsOf: DoTApplicator.applyBleed(
                potency: defenderTriggers.onHitAttackerBleedPotency,
                to: attacker.combatant,
                sourceActorID: state.combatant.id,
                application: .attached,
                durationTurns: defenderTriggers.onHitAttackerBleedTurns > 0
                    ? defenderTriggers.onHitAttackerBleedTurns
                    : nil,
                in: &context,
            ))
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
            if restored > 0 {
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
            state.damageEvents.append(contentsOf: CombatTriggerEngine.consumeManaOverflowTalents(
                for: state.combatant,
                restoredMana: restored > 0,
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
        let defenderTriggers = context.modifiers(for: state.combatant.id).triggers
        let wards = onHitWardTotals(from: context.roster.activeEffects(for: state.combatant))

        let holyDamage = defenderTriggers.onHitAttackerHoly
        if holyDamage > 0, context.roster.health(for: attacker.combatant) > 0 {
            state.damageEvents.append(contentsOf: resolveNestedDamage(
                amount: holyDamage,
                keyword: .holy,
                target: attacker.combatant,
                sourceActorID: state.combatant.id,
                in: &context,
            ).events)
        }

        applyThornsRetaliation(amount: wards.thornsStacks, attacker: attacker, to: &state, in: &context)

        if defenderTriggers.onHitGainBlock > 0 {
            state.damageEvents.append(contentsOf: context.applyBlock(
                defenderTriggers.onHitGainBlock,
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
            appendNestedDamage(
                amount: amount,
                keyword: keyword,
                abilityName: keyword == .freeze ? "Glacial Ward" : "\(keyword.rawValue) Ward",
                target: attacker.combatant,
                defender: state.combatant,
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
        state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
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
        if state.combatant.role == .enemy, state.damageKeyword == .poison,
           state.options.isAttackHit,
           context.modifiers(for: attacker.id).triggers.safeHandling {
            return
        }
        ActiveEffectMutation.removeMatching(from: state.combatant, in: &context) {
            if case .thorns = $0 {
                return true
            }
            return false
        }
        let defenderTriggers = context.modifiers(for: state.combatant.id).triggers
        let blocked = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: state.combatant)) > 0
        let baseRetaliation = amount + max(0, defenderTriggers.thornsDamageFlat)
            + (blocked ? max(0, defenderTriggers.thornsDamageFlatWhileBlocked) : 0)
        var retaliation = defenderTriggers.thornsDamageDoubleWhileBlocked && blocked ? baseRetaliation * 2 : baseRetaliation
        if blocked, defenderTriggers.thornsDamageMultiplierWhileBlocked > 1 {
            retaliation = CombatRounding.scaled(
                retaliation, multiplier: defenderTriggers.thornsDamageMultiplierWhileBlocked,
            )
        }
        if attacker.combatant.role == .enemy, state.combatant.role != .enemy,
           context.roster.hero.isAlive,
           context.roster.hasAffliction(.poison, on: attacker.combatant) {
            retaliation = CombatRounding.scaled(
                retaliation,
                multiplier: context.heroModifiers.triggers.barbedSporesThornsVsPoisonedMultiplier,
            )
        }
        let keyword: Keyword = if defenderTriggers.resonantShell {
            .stun
        } else if defenderTriggers.thornsDealHoly {
            .holy
        } else if state.combatant.role != .enemy, context.roster.hero.isAlive,
                  context.heroModifiers.triggers.thornShedding {
            .poison
        } else {
            .physical
        }
        let healthLost = appendNestedDamage(
            amount: retaliation,
            keyword: keyword,
            abilityName: "Thorns",
            target: attacker.combatant,
            defender: state.combatant,
            to: &state,
            in: &context,
        )
        if keyword == .poison {
            state.damageEvents.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison, potency: healthLost, to: attacker.combatant,
                sourceActorID: state.combatant.id, application: .attached,
            ))
        }
        applySpitebloom(healthLost: healthLost, attacker: attacker.combatant, to: &state, in: &context)
        applySpitefulHeal(healthLost: healthLost, to: &state, in: &context)
    }

    private static func applySpitebloom(
        healthLost: Int,
        attacker: Combatant,
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        let amount = context.modifiers(for: state.combatant.id).triggers.poisonOnThornsDamage
        guard healthLost > 0, amount > 0, context.roster.health(for: attacker) > 0 else { return }
        let poison = resolveNestedDamage(
            amount: amount, keyword: .poison,
            target: attacker, sourceActorID: state.combatant.id, in: &context,
        )
        state.damageEvents.append(contentsOf: poison.events)
        if poison.healthLost > 0 {
            state.damageEvents.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison, potency: poison.healthLost, to: attacker,
                sourceActorID: state.combatant.id, application: .attached,
            ))
        }
    }

    private static func applySpitefulHeal(
        healthLost: Int,
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        let heal = context.modifiers(for: state.combatant.id).triggers.firstThornsDamageHealPerTurn
        if healthLost > 0, heal > 0,
           context.resolution.claim(.affix("spiteful"), actorID: state.combatant.id, cadence: .turn(context.turnCount)) {
            state.damageEvents.append(contentsOf: context.healEmitting(
                amount: heal, target: state.combatant, source: state.combatant,
                abilityName: context.modifiers(for: state.combatant.id).triggerAbilityName(
                    "firstThornsDamageHealPerTurn", fallback: "Spiteful",
                ),
            ))
        }
    }
}
