import Foundation
import TrinketContent
import TrinketCore

package enum DamagePipeline {
    /// Ordered damage checkpoints. Phases run top to bottom; commit mutations
    /// before their dependent reactions. Step implementations live in the
    /// sibling `DamagePipeline*Steps` files by responsibility:
    /// attacker calculations (`OffenseSteps`), target mitigation (`DefenseSteps`,
    /// `ResolutionSteps+Shield`, `+TakeDamage`), Marked's bonus and consumption
    /// (`OffenseSteps`, `+TakeDamage`), stochastic gates, then committed reactions
    /// (`PostSteps`, `AttackerOnHitEngine`, `TalentReactions`).
    package static func run(
        state: inout DamageResolutionState,
        in context: inout BattleState,
    ) async {
        if state.options.isElementalReaction {
            state.remaining = state.amount
            await applyElementalHealthLoss(to: &state, in: &context)
            return
        }
        if state.options.isHealthCost {
            state.remaining = state.amount
            await applyTakeDamage(to: &state, in: &context)
            await applyDeathsDoor(to: &state, in: &context)
            if state.healthLost > 0,
               let sourceActorID = state.sourceActorID,
               let source = context.roster.combatant(for: sourceActorID)?.combatant,
               context.modifiers(for: sourceActorID).triggers.healthCostEmpowerDiscount > 0 {
                let discount = context.modifiers(for: sourceActorID).triggers.healthCostEmpowerDiscount
                context.roster.mutateRuntime(for: source) {
                    $0.talents.pending.nextManaEmpowerDiscount = max(
                        $0.talents.pending.nextManaEmpowerDiscount, discount,
                    )
                }
            }
            return
        }

        await applyDodgeGate(to: &state, in: &context)
        if state.isDodged {
            return
        }
        if let sourceActorID = state.sourceActorID,
           let source = context.roster.combatant(for: sourceActorID), source.role != .enemy {
            state.sourceHadNoBlockAtHit = DefensePoolEngine.blockPoints(
                in: context.roster.activeEffects(for: source.combatant),
            ) == 0
        }
        state.targetStatus = DamageTargetStatus(for: state.combatant, in: context)
        applyEnemyAttackBlockRemoval(to: &state, in: &context)
        if !state.options.isResolvedCardRepeat {
            reserveCompanionBlockIgnore(to: &state, in: &context)
        }
        applyOutgoingDamage(to: &state, in: &context)
        applyNextDamageReduction(to: &state, in: &context)
        ElementalReactionEngine.shatter(to: &state, in: &context)
        applyPreparedAttackReduction(to: &state, in: &context)
        applyTakenFlatAdjustments(to: &state, in: &context)
        await applyShieldAbsorption(to: &state, in: &context)
        await applyTakeDamage(to: &state, in: &context)
        applyMarkedConsume(to: &state, in: &context)
        await applyDeathsDoor(to: &state, in: &context)
        if state.options.isNaturalStatusTick, let keyword = state.damageKeyword, state.combatant == context.enemy {
            ElementalReactionEngine.recordNaturalTick(keyword, amount: state.healthLost, sourceID: state.sourceActorID, in: &context)
        }

        applyResourceful(to: &state, in: &context)
        applyCrackedGuard(to: &state, in: &context)
        await applyCommittedDamageReactions(to: &state, in: &context)
    }

    /// Committed-damage reaction order (load-bearing, do not reorder):
    /// card-hit (or non-card attack rewards) → enemy traits → DoT mirrors/ticks → leech → enemy Purge → attacker on-hit
    /// applications → attacker mirrors → control meter/fang → retaliation-gated
    /// reactive → keyword rewards → ally Block → Threefold Grace → crit → uniques. DoT mirrors must precede leech so
    /// mirrored ticks count toward the same hit; keyword reactions stay last
    /// among pipeline-owned steps so wards see final healthLost.
    private static func applyCommittedDamageReactions(to state: inout DamageResolutionState, in context: inout BattleState) async {
        await applyAttackRewards(to: &state, in: &context)
        if state.options.isCardAttack, state.amount > 0, state.combatant.role == .enemy {
            await CombatTriggerEngine.afterHeroCardHit(
                keyword: state.damageKeyword, sourceID: state.sourceActorID, critical: state.isCritical,
                healthLost: state.healthLost,
                fullyBlocked: state.blockedAmount > 0 && state.remaining == 0,
                in: &context,
            )
        }
        if state.options.isAttackHit, !state.options.isCardAttack,
           state.amount > 0, state.combatant.role == .enemy {
            CombatTriggerEngine.afterNonCardAttackHit(
                keyword: state.damageKeyword, sourceID: state.sourceActorID,
                fullyBlocked: state.blockedAmount > 0 && state.remaining == 0,
                in: &context,
            )
        }

        if state.options.isAttackHit, !state.options.isCardAttack, state.isCritical,
           state.amount > 0, state.damageKeyword == .physical, state.combatant.role == .enemy {
            CombatTriggerEngine.removeBlockAfterPhysicalCriticalHit(by: state.sourceActorID, in: &context)
        }

        await EnemyTraitEngine.basicFreezeDamage(from: state, context: &context)
        await EnemyTraitEngine.firstAttackBleedBonus(from: state, context: &context)
        await EnemyTraitEngine.attacksApplyPoison(from: state, context: &context)
        await applyDoTDamageReactions(to: &state, in: &context)
        await applyCompanionDamageRetaliation(to: &state, in: &context)
        await applyLeech(to: &state, in: &context)
        await applyEnemyAttackPurge(to: &state, in: &context)
        await AttackerOnHitEngine.apply(to: &state, in: &context)
        await applyAttackerMirroredReactions(to: &state, in: &context)

        await applyControlMeter(to: &state, in: &context)
        await AttackerOnHitEngine.applyNimbleFang(to: &state, in: &context)
        if !state.options.isRetaliation {
            await applyReactiveOnHit(to: &state, in: &context)
        }
        // Full Basic counterattacks retain damage rewards without reopening counterattack retaliation.
        if !state.options.isRetaliation || state.options.isCounterattack || state.damageKeyword == .freeze
            || (state.options.isThornsDamage && state.damageKeyword == .holy)
            || (state.options.isPeriodic && state.damageKeyword == .burn) {
            await applyKeywordReactions(to: &state, in: &context)
        }
        applyFinalCompanionHolyHitRewards(to: &state, in: &context)
        applyCompanionLeechCriticalBlock(to: &state, in: &context)
        await applyThreefoldGrace(to: &state, in: &context)
        if !state.options.isRetaliation || state.options.isCounterattack {
            await applyCriticalReaction(to: &state, in: &context)
        }
        await UniqueCombatEngine.afterDamage(state, in: &context)
    }

    private static func applyDoTDamageReactions(to state: inout DamageResolutionState, in context: inout BattleState) async {
        if let keyword = state.damageKeyword, keyword == .burn || keyword == .bleed,
           let sourceActorID = state.sourceActorID {
            await DoTMirrorCascade.resolve(
                keyword: keyword, initialHealthLost: state.healthLost, target: state.combatant,
                sourceActorID: sourceActorID, in: &context,
            )
        }
        if state.damageKeyword == .bleed {
            await CombatTriggerEngine.afterBleedDamage(
                healthLost: state.healthLost, target: state.combatant,
                sourceActorID: state.sourceActorID, in: &context,
            )
        } else if state.damageKeyword == .poison {
            await CombatTriggerEngine.afterPoisonDamage(
                healthLost: state.healthLost, target: state.combatant,
                sourceActorID: state.sourceActorID, in: &context,
            )
        }
    }

    /// Freezes a 50% preview of the avoided hit back at the attacker. Runs on
    /// a discarded copy: modifier profiles share storage (CoW), so the copy
    /// is cheap, and preview mutations (empower reservations, claims, burn
    /// consumption) must not leak into the real resolution.
    static func applyWinterWake(to state: inout DamageResolutionState, in context: inout BattleState) async {
        guard !state.options.causedByDodge, state.options.isAttackHit,
              context.modifiers(for: state.combatant.id).triggers.wintersWake,
              let attackerID = state.sourceActorID,
              let attacker = context.roster.combatant(for: attackerID), attacker.isAlive else { return }
        // Scope the preview copy so it is destroyed before the nested
        // resolveDamage below; holding a full BattleState across nested
        // damage needlessly peaks worker-thread stacks.
        let amount: Int = {
            var preview = context
            // The preview owns its mutations, including emitted feedback.
            preview.commandOutput = nil
            var avoided = state
            avoided.targetStatus = DamageTargetStatus(for: state.combatant, in: preview)
            applyOutgoingDamage(to: &avoided, in: &preview)
            applyTakenFlatAdjustments(to: &avoided, in: &preview)
            return CombatRounding.scaled(avoided.remaining, multiplier: 0.5)
        }()
        guard amount > 0 else { return }
        let options = DamageOperation.reaction(cause: .dodge, scaling: .resolved, accuracy: .normal)
        let outcome = await context.resolveDamage(DamageRequest(
            amount: amount, target: attacker.combatant, keyword: .freeze,
            sourceActorID: state.combatant.id, options: options,
        ))
        if outcome.healthLost > 0 {
            context.nextEvent(
                kind: .abilityDamage, source: .init(state.combatant), abilityName: "Winter’s Wake",
                target: attacker.combatant, amount: outcome.healthLost, keyword: .freeze,
            )
        }
    }

    private static func applyNextDamageReduction(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.remaining > 0, !state.options.isRedirected,
              let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID)?.combatant,
              let runtime = context.roster.runtime(for: source),
              runtime.talents.pending.nextDamageReduction > 0 else { return }
        let reduction = min(state.remaining, runtime.talents.pending.nextDamageReduction)
        context.roster.mutateRuntime(for: source) { $0.talents.pending.nextDamageReduction = 0 }
        state.remaining -= reduction
        context.nextEvent(
            kind: .effect(.damageReduced), source: .init(source),
            abilityName: context.modifiers(for: sourceID).triggerAbilityName(
                .onHealthLossNextDamageReduction, fallback: "Loose Rubble",
            ),
            target: state.combatant, amount: reduction, keyword: state.damageKeyword ?? .physical,
        )
    }

    private static func applyOutgoingDamage(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        if state.options.usesResolvedOutgoingDamage {
            state.remaining = state.amount
            state.isCritical = state.options.guaranteedCritical
            if !state.options.isResolvedCardRepeat {
                applyConditionalDamageBonuses(to: &state, in: context)
                applyPreparedPoisonDamage(to: &state, in: &context)
            }
        } else {
            reserveAttackEmpowers(to: &state, in: &context)
            UniqueCombatEngine.captureEnemyBlock(for: &state, in: context)
            applyCriticalGate(to: &state, in: &context)
            applyCriticalBlockSteal(to: &state, in: &context)
            applyDamageBonus(to: &state, in: &context)
            applyFinalCompanionOutgoingBonuses(to: &state, in: &context)
            applyFightPacing(to: &state, in: &context)
            applyMarkedBonus(to: &state, in: &context)
            UniqueCombatEngine.applyStoredDamage(to: &state, in: &context)
            // Only Final Spark and Everkeen need a pre-defense critical snapshot.
            if state.options.capturesCardRepeat
                || (state.options.isOrdinaryUniqueCardDamage && state.isCritical && state.damageKeyword == .physical
                    && state.sourceActorID.map { context.modifiers(for: $0).triggers.firstCriticalHitRepeatsPerTurn } == true) {
                var outgoing = state
                outgoing.remaining -= state.options.partnerFirstAttackBonus
                applyCriticalMultiply(to: &outgoing, in: &context)
                state.unique.outgoingDamage = outgoing.remaining
            }
        }
        // Freeze offense for Final Spark; the repeat rechecks recipient defenses.
        let cardRepeatAmount: Int = {
            guard state.options.capturesCardRepeat else { return 0 }
            var outgoing = state
            if !state.options.usesResolvedOutgoingDamage {
                applyCriticalMultiply(to: &outgoing, in: &context)
            }
            return outgoing.remaining
        }()
        applyTakenPercentAdjustments(to: &state, in: &context)
        if !state.options.usesResolvedOutgoingDamage {
            applyCriticalMultiply(to: &state, in: &context)
        }
        let outgoingBeforeBackdraft = state.unique.outgoingDamage
        if !state.options.isResolvedCardRepeat {
            applyBackdraftBonus(to: &state, in: &context)
        }
        UniqueCombatEngine.captureCardDamage(
            state,
            outgoingAmount: SaturatedArithmetic.saturatingAdd(
                cardRepeatAmount, state.unique.outgoingDamage - outgoingBeforeBackdraft,
            ),
            in: &context,
        )
    }

    /// Single choke point for nested reaction damage (retaliation, wards,
    /// talent strikes, blocked-damage answers). DoT-typed mirrors branch to
    /// the applicator before reaching this helper.
    ///
    /// The `.thornsTriggered` decorator is never added here. Ward paths that
    /// need it must call `resolveWardDamage`, which makes the decorator
    /// explicit at the call site; every other nested-damage caller uses this
    /// function directly so no decorator fires.
    static func resolveNestedDamage(
        amount: Int,
        keyword: Keyword,
        target: Combatant,
        sourceActorID: String?,
        requireTargetAlive: Bool = false,
        isThornsDamage: Bool = false,
        requireSourceAlive source: Combatant? = nil,
        in context: inout BattleState,
    ) async -> CombatOutcome {
        guard amount > 0 else {
            return .empty
        }
        if requireTargetAlive, context.roster.health(for: target) == 0 {
            return .empty
        }
        if let source, context.roster.health(for: source) == 0 {
            return .empty
        }
        var options = DamageOperation.reaction()
        options.isThornsDamage = isThornsDamage
        return await context.resolveDamage(DamageRequest(
            amount: amount,
            target: target,
            keyword: keyword,
            sourceActorID: sourceActorID,
            options: options,
        ))
    }

    /// Ward-only sibling of `resolveNestedDamage`: resolves nested damage and
    /// emits the `.thornsTriggered` decorator when damage lands. Call sites
    /// are limited to defender-ward retaliation (freeze wards, typed wards,
    /// thorns); talent strikes, reflections, and other nested damage must call
    /// `resolveNestedDamage` directly so the decorator stays off.
    @discardableResult
    static func resolveWardDamage(
        amount: Int,
        keyword: Keyword,
        abilityName: String,
        target: Combatant,
        defender: Combatant,
        isThornsDamage: Bool = false,
        in context: inout BattleState,
    ) async -> Int {
        guard amount > 0 else { return 0 }
        let outcome = await resolveNestedDamage(
            amount: amount,
            keyword: keyword,
            target: target,
            sourceActorID: defender.id,
            isThornsDamage: isThornsDamage,
            in: &context,
        )
        if outcome.healthLost > 0 {
            context.nextEvent(
                kind: .effect(.thornsTriggered),
                source: .init(defender),
                abilityName: abilityName,
                target: target,
                amount: outcome.healthLost,
                keyword: keyword,
            )
        }
        return outcome.healthLost
    }

    static func appendAbsorption(
        _ amount: Int,
        abilityName: String,
        keyword: Keyword,
        source: CombatEventSource,
        target: Combatant,
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        state.remaining -= amount
        context.nextEvent(
            kind: .effect(.shieldAbsorbed),
            source: source,
            abilityName: abilityName,
            target: target,
            amount: amount,
            keyword: keyword,
            isFullyBlocked: state.remaining == 0 && amount > 0,
        )
    }
}
