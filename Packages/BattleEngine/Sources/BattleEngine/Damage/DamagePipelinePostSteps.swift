import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyResourceful(to state: CommittedDamage, in context: inout BattleState) {
        guard state.options.isPrimaryAttack,
              let attackerID = state.sourceActorID,
              context.roster.combatant(for: attackerID)?.role == .enemy else { return }
        for wearer in state.brokenBlockOwners {
            guard context.modifiers(for: wearer.id).triggers.blockBreakDrawBelowHalf,
                  let runtime = context.roster.runtime(for: wearer), runtime.isAlive,
                  runtime.isBelowHalfHealth,
                  let owner = context.roster.participant(for: wearer) else { continue }
            CombatTriggerEngine.drawCards(1, for: owner, actor: wearer, abilityName: "Resourceful", in: &context)
        }
    }

    static func applyLeech(
        to state: CommittedDamage,
        in context: inout BattleState,
    ) async -> Bool {
        guard let sourceActorID = state.sourceActorID,
              state.healthLost > 0 || (state.blockedAmount > 0 && context.modifiers(for: sourceActorID).triggers.leechOnBlockDamage),
              sourceActorID != state.combatant.id
        else { return false }
        let leechOutcome = await HealingEngine.leechFromDamage(
            state.healthLost,
            sourceActorID: sourceActorID,
            target: state.combatant,
            blockedAmount: state.blockedAmount,
            abilityHasLeech: state.options.abilityHasLeech || state.talentAttackHasLeech,
            criticalAttack: state.isCritical && state.options.isAttackHit,
            attackHit: state.options.isAttackHit,
            damageKeyword: state.damageKeyword,
            in: &context,
        )
        let didLeech = leechOutcome.flags.contains(.leeched)
        applyFinalCompanionLeechRewards(to: state, didLeech: didLeech, in: &context)
        return didLeech
    }

    static func applyKeywordReactions(
        to state: CommittedDamage,
        in context: inout BattleState,
    ) async {
        let nativeEnemyHit = state.options.isPrimaryAttack && state.amount > 0
            && state.sourceActorID == context.enemy.id
            && (state.damageKeyword == .holy || state.damageKeyword == .stun)
        guard state.healthLost > 0 || nativeEnemyHit,
              let keyword = state.damageKeyword,
              let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID)
        else { return }
        // Native Holy/Stun rewards belong to attack hits, not their bonus packets.
        if source.role == .enemy, keyword == .holy || keyword == .stun,
           !state.options.isPrimaryAttack {
            return
        }

        switch keyword {
        case .holy:
            await CombatTriggerEngine.afterHolyDamageDealt(
                to: state.combatant,
                source: source.combatant,
                attackHit: state.options.isAttackHit,
                sourceHadNoBlock: state.sourceHadNoBlockAtHit,
                in: &context,
            )
        case .stun:
            CombatTriggerEngine.afterStunDamageDealt(to: state.combatant, source: source.combatant, in: &context)
        case .burn:
            await CombatTriggerEngine.afterBurnDamageDealt(
                to: state.combatant,
                source: source.combatant,
                healthLost: state.healthLost,
                in: &context,
            )
        case .freeze:
            CombatTriggerEngine.afterFreezeDamageDealt(
                to: state.combatant,
                source: source.combatant,
                amount: state.healthLost,
                in: &context,
            )
        default:
            break
        }
    }

    static func applyThreefoldGrace(
        to state: CommittedDamage,
        in context: inout BattleState,
    ) async {
        guard state.healthLost > 0,
              let keyword = state.damageKeyword,
              state.partySource(in: context) != nil,
              state.combatant.role == .enemy,
              keyword == .burn || keyword == .freeze || keyword == .holy else { return }
        for owner in BattleParticipant.party {
            let wearer = context.roster[owner]
            guard wearer.isAlive, wearer.currentMana < wearer.maxMana else { continue }
            let chance = context.modifiers(for: wearer.combatant.id).triggers.threefoldElementalDamageManaChancePercent
            guard chance > 0, BattleChance.succeeds(probability: chance, using: &context.rng) else { continue }
            await context.restoreManaEmitting(1, to: wearer.combatant, abilityName: "Threefold Grace")
        }
    }

    static func applyAttackRewards(
        to state: CommittedDamage,
        in context: inout BattleState,
    ) async {
        guard state.options.isAttackHit, state.amount > 0,
              state.combatant.role == .enemy,
              let source = state.partySource(in: context) else { return }
        if state.isCritical {
            context.resolution.recordCriticalAttack(by: source.id)
        }
        guard !state.options.isCardAttack, source.isAlive else { return }
        if state.isCritical {
            await CombatTriggerEngine.afterTypedCriticalAttackHit(keyword: state.damageKeyword, actor: source.combatant, in: &context)
        }
        await CombatTriggerEngine.afterCompanionAttackHit(
            keyword: state.damageKeyword, actor: source.combatant, critical: state.isCritical,
            healthLost: state.healthLost, triggers: context.modifiers(for: source.id).triggers, in: &context,
        )
    }

    static func applyCriticalReaction(
        to state: CommittedDamage,
        in context: inout BattleState,
    ) async {
        guard state.isCritical,
              state.amount > 0,
              let source = state.partySource(in: context),
              state.combatant.role == .enemy
        else { return }
        await CombatTriggerEngine.afterCriticalHit(
            to: state.combatant,
            source: source.combatant,
            targetWasStunnedAtHit: state.targetWasStunnedAtHit,
            isAttackHit: state.options.isAttackHit,
            in: &context,
        )
    }

    static func applyControlMeter(
        to state: CommittedDamage,
        in context: inout BattleState,
    ) async -> Bool {
        guard state.remaining > 0,
              let damageKeyword = state.damageKeyword,
              damageKeyword == .stun || damageKeyword == .freeze,
              context.roster.health(for: state.combatant) > 0
        else { return false }
        let wasControlled = context.roster.hasControlStatus(for: state.combatant, keyword: damageKeyword)
        let criticalMultiplier: Double = if damageKeyword == .freeze, state.isCritical, state.options.isAttackHit,
                                            let sourceActorID = state.sourceActorID {
            context.modifiers(for: sourceActorID).triggers.freezeCriticalBuildupMultiplier
        } else {
            1
        }
        await ControlMeterEngine.applyMeterCharge(
            CombatRounding.scaled(state.remaining, multiplier: criticalMultiplier),
            keyword: damageKeyword,
            to: state.combatant,
            sourceActorID: state.sourceActorID,
            applyFightPacing: false,
            setupHealthDamage: state.healthLost,
            in: &context,
        )
        return !wasControlled && context.roster.hasControlStatus(for: state.combatant, keyword: damageKeyword)
    }

    static func applyReactiveOnHit(
        to state: CommittedDamage,
        in context: inout BattleState,
    ) async {
        guard !state.isDodged, !state.options.isRetaliation, let sourceActorID = state.sourceActorID else { return }
        guard let attacker = context.roster.combatant(for: sourceActorID) else { return }

        if state.options.isAttackHit {
            context.roster.mutateRuntime(for: state.combatant) { $0.talents.turn.tookAttackHit = true }
        }

        if state.healthLost > 0 {
            await applyEnemyTraitReactions(
                to: state,
                sourceActorID: sourceActorID,
                in: &context,
            )
            await applyOnHitAttackerWards(to: state, attacker: attacker, in: &context)
            await applyManaShieldOnHit(to: state, in: &context)
        }

        if state.options.isAttackHit {
            let freeze = context.modifiers(for: state.combatant.id).triggers.onHitAttackerFreezeBuildup
            if freeze > 0 {
                await resolveWardDamage(
                    amount: freeze,
                    keyword: .freeze,
                    abilityName: CombatTriggerEngine.triggerAbilityName(
                        .onHitAttackerFreezeBuildup, for: state.combatant, fallback: "Chilling Scales", in: context,
                    ),
                    target: attacker.combatant,
                    defender: state.combatant,
                    in: &context,
                )
            }
            await applyOnHitWards(to: state, attacker: attacker, in: &context)
        }
    }

    private static func applyEnemyTraitReactions(
        to state: CommittedDamage,
        sourceActorID: String,
        in context: inout BattleState,
    ) async {
        await EnemyTraitEngine.traitThornsDamage(
            damageTaken: state.healthLost,
            defender: state.combatant,
            attackerID: sourceActorID,
            in: &context,
        )
        if state.options.isAttackHit {
            await EnemyTraitEngine.traitAttackerBurn(defender: state.combatant, attackerID: sourceActorID, in: &context)
        }
    }

    private static func applyOnHitAttackerWards(
        to state: CommittedDamage,
        attacker: CombatantRuntime,
        in context: inout BattleState,
    ) async {
        let defenderTriggers = context.modifiers(for: state.combatant.id).triggers
        if defenderTriggers.onHitAttackerPoison > 0, context.roster.health(for: attacker.combatant) > 0 {
            await context.applyDecayingDoT(
                keyword: .poison,
                potency: defenderTriggers.onHitAttackerPoison,
                to: attacker.combatant,
                sourceActorID: state.combatant.id,
                application: .reaction,
            )
        }
        if defenderTriggers.onHitAttackerBleedPotency > 0, context.roster.health(for: attacker.combatant) > 0 {
            await DoTApplicator.applyBleed(
                potency: defenderTriggers.onHitAttackerBleedPotency,
                to: attacker.combatant,
                sourceActorID: state.combatant.id,
                application: .reaction,
                durationTurns: defenderTriggers.onHitAttackerBleedTurns > 0
                    ? defenderTriggers.onHitAttackerBleedTurns
                    : nil,
                in: &context,
            )
        }
    }

    private static func applyManaShieldOnHit(
        to state: CommittedDamage,
        in context: inout BattleState,
    ) async {
        let activeEffects = context.roster.activeEffects(for: state.combatant)
        for active in activeEffects {
            guard case let .restoreManaOnHit(amount, _) = active.effect else { continue }
            let pacedAmount = context.paced(amount, sourceActorID: state.combatant.id)
            let restored = context.restoreMana(pacedAmount, to: state.combatant)
            if restored > 0 {
                context.nextEvent(
                    kind: .effect(.manaShieldTriggered),
                    source: .init(state.combatant),
                    abilityName: "Mana Shield",
                    target: state.combatant,
                    amount: restored,
                    keyword: .mana,
                )
            }
            await CombatTriggerEngine.manaRestorationReactions(for: state.combatant, restored: restored, in: &context)
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
                totals.thornsStacks = SaturatedArithmetic.saturatingAdd(totals.thornsStacks, amount)
            case let .onHitDamage(keyword, amount):
                totals.onHitDamage[keyword] = SaturatedArithmetic.saturatingAdd(totals.onHitDamage[keyword, default: 0], amount)
            case .freezeNextAttacker:
                totals.shouldFreezeAttacker = true
            default:
                continue
            }
        }
        return totals
    }

    private static func applyOnHitWards(
        to state: CommittedDamage,
        attacker: CombatantRuntime,
        in context: inout BattleState,
    ) async {
        let defenderTriggers = context.modifiers(for: state.combatant.id).triggers
        let wards = onHitWardTotals(from: context.roster.activeEffects(for: state.combatant))

        let holyDamage = defenderTriggers.onHitAttackerHoly
        if holyDamage > 0, context.roster.health(for: attacker.combatant) > 0 {
            _ = await resolveNestedDamage(
                amount: holyDamage,
                keyword: .holy,
                target: attacker.combatant,
                sourceActorID: state.combatant.id,
                in: &context,
            )
        }

        await applyThornsRetaliation(amount: wards.thornsStacks, attacker: attacker, to: state, in: &context)

        if defenderTriggers.onHitGainBlock > 0 {
            context.applyBlockGain(
                defenderTriggers.onHitGainBlock,
                to: state.combatant,
                source: state.combatant,
                abilityName: CombatTriggerEngine.triggerAbilityName(
                    .onHitGainBlock,
                    for: state.combatant,
                    fallback: "Plated Hide",
                    in: context,
                ),
            )
        }

        for (keyword, amount) in wards.onHitDamage.sorted(by: { $0.key.rawValue < $1.key.rawValue }) where amount > 0 {
            ActiveEffectMutation.removeMatching(from: state.combatant, in: &context) {
                $0.kind == .onHitDamage && $0.keyword == keyword
            }
            await resolveWardDamage(
                amount: amount,
                keyword: keyword,
                abilityName: keyword == .freeze ? "Glacial Ward" : "\(keyword.rawValue) Ward",
                target: attacker.combatant,
                defender: state.combatant,
                in: &context,
            )
        }

        guard wards.shouldFreezeAttacker else { return }
        ActiveEffectMutation.removeMatching(from: state.combatant, in: &context) {
            $0.kind == .freezeNextAttacker
        }
        let threshold = ControlMeterEngine.threshold(for: attacker.combatant, in: context)
        await ControlMeterEngine.applyMeterCharge(
            threshold,
            keyword: .freeze,
            to: attacker.combatant,
            sourceActorID: state.combatant.id,
            applyFightPacing: true,
            in: &context,
        )
    }

    private static func applyThornsRetaliation(
        amount: Int,
        attacker: CombatantRuntime,
        to state: CommittedDamage,
        in context: inout BattleState,
    ) async {
        guard amount > 0 else { return }
        if state.combatant.role == .enemy, state.damageKeyword == .poison,
           state.options.isAttackHit,
           context.modifiers(for: attacker.id).triggers.safeHandling {
            return
        }
        ActiveEffectMutation.removeMatching(from: state.combatant, in: &context) {
            $0.kind == .thorns
        }
        let defenderTriggers = context.modifiers(for: state.combatant.id).triggers
        let blocked = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: state.combatant)) > 0
        let baseRetaliation = SaturatedArithmetic.saturatingAdd(
            amount, SaturatedArithmetic.saturatingAdd(
                max(0, defenderTriggers.thornsDamageFlat),
                blocked ? max(0, defenderTriggers.thornsDamageFlatWhileBlocked) : 0,
            ),
        )
        var retaliation = defenderTriggers.thornsDamageDoubleWhileBlocked && blocked
            ? SaturatedArithmetic.saturatingMul(baseRetaliation, 2) : baseRetaliation
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
        } else {
            .physical
        }
        let healthLost = await resolveWardDamage(
            amount: retaliation,
            keyword: keyword,
            abilityName: "Thorns",
            target: attacker.combatant,
            defender: state.combatant,
            isThornsDamage: true,
            in: &context,
        )
        await thornsRewards(healthLost: healthLost, attacker: attacker.combatant, defender: state.combatant, in: &context)
    }

    static func thornsRewards(
        healthLost: Int,
        attacker: Combatant,
        defender: Combatant,
        in context: inout BattleState,
    ) async {
        let poison = context.modifiers(for: defender.id).triggers.firstThornsPoisonDamagePerTurn
        if healthLost > 0, poison > 0, context.roster.health(for: attacker) > 0,
           context.claimTurnGuard(.thornShedding, actorID: defender.id) {
            await context.applyDecayingDoT(
                keyword: .poison, potency: poison, to: attacker,
                sourceActorID: defender.id, application: .reaction,
            )
        }
        await spitefulHeal(healthLost: healthLost, defender: defender, in: &context)
    }

    private static func spitefulHeal(
        healthLost: Int,
        defender: Combatant,
        in context: inout BattleState,
    ) async {
        let heal = context.modifiers(for: defender.id).triggers.firstThornsDamageHealPerTurn
        guard healthLost > 0, heal > 0, context.roster.health(for: defender) > 0,
              context.resolution.claim(.affix(.spitefulHeal), actorID: defender.id, cadence: .turn(context.turnCount))
        else { return }
        let target = BattleActionContext(actor: defender, in: context).target(.lowestHealthAlly, in: context)
        await context.healEmitting(
            amount: heal, target: target, source: defender,
            abilityName: context.modifiers(for: defender.id).triggerAbilityName(
                .firstThornsDamageHealPerTurn, fallback: "Spiteful",
            ),
        )
    }
}
