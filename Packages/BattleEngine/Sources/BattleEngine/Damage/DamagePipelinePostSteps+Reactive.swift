import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyReactiveOnHit(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) async {
        guard !state.isDodged, !state.options.isRetaliation, let sourceActorID = state.sourceActorID else { return }
        guard let attacker = context.roster.combatant(for: sourceActorID) else { return }

        if state.options.isAttackHit {
            context.roster.mutateRuntime(for: state.combatant) { $0.talents.turn.tookAttackHit = true }
        }

        if state.healthLost > 0 {
            await applyEnemyTraitReactions(
                to: &state,
                sourceActorID: sourceActorID,
                in: &context,
            )
            await applyOnHitAttackerWards(to: &state, attacker: attacker, in: &context)
            await applyManaShieldOnHit(to: &state, in: &context)
        }

        if state.options.isAttackHit {
            let freeze = context.modifiers(for: state.combatant.id).triggers.onHitAttackerFreezeBuildup
            if freeze > 0 {
                await appendNestedDamage(
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
            await applyOnHitWards(to: &state, attacker: attacker, in: &context)
        }
    }

    private static func applyEnemyTraitReactions(
        to state: inout DamageResolutionState,
        sourceActorID: String,
        in context: inout BattleState,
    ) async {
        await state.damageEvents.append(contentsOf: EnemyTraitEngine.traitThornsDamage(
            damageTaken: state.healthLost,
            defender: state.combatant,
            attackerID: sourceActorID,
            in: &context,
        ))
        await state.damageEvents.append(contentsOf: EnemyTraitEngine.traitAttackerBurn(
            defender: state.combatant,
            attackerID: sourceActorID,
            in: &context,
        ))
    }

    private static func applyOnHitAttackerWards(
        to state: inout DamageResolutionState,
        attacker: CombatantRuntime,
        in context: inout BattleState,
    ) async {
        let defenderTriggers = context.modifiers(for: state.combatant.id).triggers
        if defenderTriggers.onHitAttackerPoison > 0, context.roster.health(for: attacker.combatant) > 0 {
            await state.damageEvents.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison,
                potency: defenderTriggers.onHitAttackerPoison,
                to: attacker.combatant,
                sourceActorID: state.combatant.id,
                application: .reaction,
            ))
        }
        if defenderTriggers.onHitAttackerBleedPotency > 0, context.roster.health(for: attacker.combatant) > 0 {
            await state.damageEvents.append(contentsOf: DoTApplicator.applyBleed(
                potency: defenderTriggers.onHitAttackerBleedPotency,
                to: attacker.combatant,
                sourceActorID: state.combatant.id,
                application: .reaction,
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
    ) async {
        let activeEffects = context.roster.activeEffects(for: state.combatant)
        for active in activeEffects {
            guard case let .restoreManaOnHit(amount, _) = active.effect else { continue }
            let pacedAmount = context.paced(amount, sourceActorID: state.combatant.id)
            let restored = context.restoreMana(pacedAmount, to: state.combatant)
            if restored > 0 {
                state.damageEvents.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .manaShieldTriggered,
                    source: .init(state.combatant),
                    abilityName: "Mana Shield",
                    target: state.combatant,
                    amount: restored,
                    keyword: .mana,
                ))
            }
            await state.damageEvents.append(contentsOf: CombatTriggerEngine.manaRestorationReactions(
                for: state.combatant,
                restored: restored,
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
    ) async {
        let defenderTriggers = context.modifiers(for: state.combatant.id).triggers
        let wards = onHitWardTotals(from: context.roster.activeEffects(for: state.combatant))

        let holyDamage = defenderTriggers.onHitAttackerHoly
        if holyDamage > 0, context.roster.health(for: attacker.combatant) > 0 {
            await state.damageEvents.append(contentsOf: resolveNestedDamage(
                amount: holyDamage,
                keyword: .holy,
                target: attacker.combatant,
                sourceActorID: state.combatant.id,
                in: &context,
            ).events)
        }

        await applyThornsRetaliation(amount: wards.thornsStacks, attacker: attacker, to: &state, in: &context)

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
            await appendNestedDamage(
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
        await state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
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
    ) async {
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
        let healthLost = await appendNestedDamage(
            amount: retaliation,
            keyword: keyword,
            abilityName: "Thorns",
            target: attacker.combatant,
            defender: state.combatant,
            isThornsDamage: true,
            to: &state,
            in: &context,
        )
        if keyword == .poison {
            await state.damageEvents.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison, potency: healthLost, to: attacker.combatant,
                sourceActorID: state.combatant.id, application: .attached,
            ))
        }
        await state.damageEvents.append(contentsOf: thornsRewards(
            healthLost: healthLost, attacker: attacker.combatant, defender: state.combatant, in: &context,
        ))
    }

    static func thornsRewards(
        healthLost: Int,
        attacker: Combatant,
        defender: Combatant,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        var events = await spitebloomDamage(healthLost: healthLost, attacker: attacker, defender: defender, in: &context)
        await events.append(contentsOf: spitefulHeal(healthLost: healthLost, defender: defender, in: &context))
        return events
    }

    private static func spitebloomDamage(
        healthLost: Int,
        attacker: Combatant,
        defender: Combatant,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        let amount = context.modifiers(for: defender.id).triggers.poisonOnThornsDamage
        guard healthLost > 0, amount > 0, context.roster.health(for: attacker) > 0 else { return [] }
        let poison = await resolveNestedDamage(
            amount: amount, keyword: .poison,
            target: attacker, sourceActorID: defender.id, in: &context,
        )
        var events = poison.events
        if poison.healthLost > 0 {
            await events.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison, potency: poison.healthLost, to: attacker,
                sourceActorID: defender.id, application: .attached,
            ))
        }
        return events
    }

    private static func spitefulHeal(
        healthLost: Int,
        defender: Combatant,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        let heal = context.modifiers(for: defender.id).triggers.firstThornsDamageHealPerTurn
        guard healthLost > 0, heal > 0, context.roster.health(for: defender) > 0,
              context.resolution.claim(.affix(.spitefulHeal), actorID: defender.id, cadence: .turn(context.turnCount))
        else { return [] }
        let target = BattleActionContext(actor: defender, in: context).target(.lowestHealthAlly, in: context)
        return await context.healEmitting(
            amount: heal, target: target, source: defender,
            abilityName: context.modifiers(for: defender.id).triggerAbilityName(
                "firstThornsDamageHealPerTurn", fallback: "Spiteful",
            ),
        )
    }
}
