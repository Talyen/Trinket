import Foundation
import TrinketContent
import TrinketCore

package enum DamagePipeline {
    /// Ordered damage checkpoints. Phases run top to bottom; commit mutations
    /// before their dependent reactions. Step implementations live in the
    /// sibling `DamagePipeline*Steps` files by phase:
    /// offense (`ResolutionSteps`), defense (`ResolutionSteps+Shield`,
    /// `+TakeDamage`, stochastic gates), then committed reactions
    /// (`PostSteps`, `+Reactive`, `TalentReactions`) under one
    /// `CombatCheckpoint.committedDamage` guard.
    package static func run(
        state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        let immediateEnemyDamage = state.provenance != nil
            && state.provenance == context.resolution.damageProvenance(for: context.enemy.id)
        if context.heroTalents.enemyTurnActive, state.options.isAttackHit || immediateEnemyDamage,
           state.sourceActorID == context.enemy.id, state.combatant.role != .enemy {
            context.heroTalents.attackedDuringEnemyTurn.insert(state.combatant.id)
        }
        if state.options.isHealthCost {
            state.remaining = state.amount
            state.dealt = state.amount
            applyTakeDamage(to: &state, in: &context)
            applyDeathsDoor(to: &state, in: &context)
            return
        }

        if state.damageKeyword == .burn,
           context.modifiers(for: state.combatant.id).triggers.undyingEmber,
           context.roster.isDeathsDoorActive(for: state.combatant) {
            applyOutgoingDamage(to: &state, in: &context)
            applyTakenFlatAdjustments(to: &state, in: &context)
            var request = HealRequest(
                amount: state.remaining, target: state.combatant, sourceActorID: state.combatant.id,
                origin: .restoration(.health), logAs: .instantHeal(
                    actorName: state.combatant.name,
                    abilityName: "Undying Ember",
                    keyword: .health,
                ),
            )
            request.amountBasis = .resolved
            state.damageEvents.append(contentsOf: HealingEngine.resolveHeal(request, in: &context).events)
            state.remaining = 0
            state.buildupDamage = 0
            state.dealt = 0
            return
        }

        applyDodgeGate(to: &state, in: &context)
        if state.isDodged {
            return
        }
        state.targetStatus = DamageTargetStatus(for: state.combatant, in: context)
        applyOutgoingDamage(to: &state, in: &context)
        applyPreparedAttackReduction(to: &state, in: &context)
        applyTakenFlatAdjustments(to: &state, in: &context)
        applyShieldAbsorption(to: &state, in: &context)
        applyTakeDamage(to: &state, in: &context)
        applyMarkedConsume(to: &state, in: &context)
        applyDeathsDoor(to: &state, in: &context)

        CombatCheckpoint.committedDamage.perform(in: &context) { context in
            applyCommittedDamageReactions(to: &state, in: &context)
        }
    }

    private static func applyCommittedDamageReactions(to state: inout DamageResolutionState, in context: inout BattleState) {
        if state.options.isCardAttack, state.amount > 0, state.combatant.role == .enemy {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterHeroCardHit(
                keyword: state.damageKeyword, sourceID: state.sourceActorID, critical: state.isCritical,
                fullyBlocked: state.blockedAmount > 0 && state.remaining == 0,
                blockBroken: state.heroCardBlockBroken, targetWasFrozen: state.targetStatus.isFrozen, in: &context,
            ))
        }

        state.damageEvents.append(contentsOf: EnemyTraitEngine.basicFreezeDamage(from: state, context: &context))
        state.damageEvents.append(contentsOf: EnemyTraitEngine.firstAttackBleedBonus(from: state, context: &context))
        applyDoTDamageReactions(to: &state, in: &context)
        applyLeech(to: &state, in: &context)
        applyTalentDamageApplications(to: &state, in: &context)
        applyTalentMirroredReactions(to: &state, in: &context)

        applyControlMeter(to: &state, in: &context)
        applyNimbleFang(to: &state, in: &context)
        if !state.options.isRetaliation {
            applyReactiveOnHit(to: &state, in: &context)
            applyKeywordReactions(to: &state, in: &context)
            applyCriticalReaction(to: &state, in: &context)
        }
        state.damageEvents.append(contentsOf: UniqueCombatEngine.afterDamage(state, in: &context))
    }

    private static func applyDoTDamageReactions(to state: inout DamageResolutionState, in context: inout BattleState) {
        if let keyword = state.damageKeyword, keyword == .burn || keyword == .bleed,
           let sourceActorID = state.sourceActorID {
            state.damageEvents.append(contentsOf: DoTMirrorCascade.resolve(
                keyword: keyword, initialHealthLost: state.healthLost, target: state.combatant,
                sourceActorID: sourceActorID, in: &context,
            ))
        }
        if state.damageKeyword == .bleed {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterBleedDamage(
                healthLost: state.healthLost, target: state.combatant,
                sourceActorID: state.sourceActorID, in: &context,
            ))
        } else if state.damageKeyword == .poison {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterPoisonDamage(
                healthLost: state.healthLost, target: state.combatant,
                sourceActorID: state.sourceActorID, in: &context,
            ))
        }
    }

    /// Freezes a 50% preview of the avoided hit back at the attacker. Runs on
    /// a discarded copy: modifier profiles share storage (CoW), so the copy
    /// is cheap, and preview mutations (empower reservations, claims, burn
    /// consumption) must not leak into the real resolution.
    static func applyWinterWake(to state: inout DamageResolutionState, in context: inout BattleState) {
        guard !state.options.causedByDodge, state.options.isAttackHit,
              context.modifiers(for: state.combatant.id).triggers.wintersWake,
              let attackerID = state.sourceActorID,
              let attacker = context.roster.combatant(for: attackerID), attacker.isAlive else { return }
        // Scope the preview copy so it is destroyed before the nested
        // resolveDamage below; holding a full BattleState across nested
        // damage needlessly peaks worker-thread stacks.
        let amount: Int = {
            var preview = context
            var avoided = state
            avoided.targetStatus = DamageTargetStatus(for: state.combatant, in: preview)
            applyOutgoingDamage(to: &avoided, in: &preview)
            applyTakenFlatAdjustments(to: &avoided, in: &preview)
            return CombatRounding.scaled(avoided.remaining, multiplier: 0.5)
        }()
        guard amount > 0 else { return }
        let options = DamageOperation.reaction(cause: .dodge, scaling: .resolved, accuracy: .normal)
        let outcome = context.resolveDamage(DamageRequest(
            amount: amount, target: attacker.combatant, keyword: .freeze,
            sourceActorID: state.combatant.id, options: options,
        ))
        state.damageEvents.append(contentsOf: outcome.events)
        if outcome.healthLost > 0 {
            state.damageEvents.append(context.nextEvent(
                kind: .abilityDamage, actorName: state.combatant.name, abilityName: "Winter’s Wake",
                target: attacker.combatant, amount: outcome.healthLost, keyword: .freeze,
            ))
        }
    }

    private static func applyOutgoingDamage(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        if state.options.usesResolvedOutgoingDamage {
            state.remaining = state.amount
            state.dealt = state.amount
            state.isCritical = state.options.guaranteedCritical
        } else {
            reserveAttackEmpowers(to: &state, in: &context)
            UniqueCombatEngine.captureEnemyBlock(for: &state, in: context)
            applyCriticalGate(to: &state, in: &context)
            applyCriticalBlockSteal(to: &state, in: &context)
            applyDamageBonus(to: &state, in: &context)
            applyFightPacing(to: &state, in: &context)
            applyMarkedBonus(to: &state, in: &context)
            UniqueCombatEngine.applyStoredDamage(to: &state, in: &context)
            state.unique.outgoingDamage = CombatRounding.scaled(
                state.remaining - state.options.partnerFirstAttackBonus,
                multiplier: state.isCritical ? criticalMultiplier(for: state.sourceActorID, in: context) : 1,
            )
        }
        applyTakenPercentAdjustments(to: &state, in: &context)
        if !state.options.usesResolvedOutgoingDamage {
            applyCriticalMultiply(to: &state, in: &context)
        }
        applyBackdraftBonus(to: &state, in: &context)
        if state.options.isCardAttack, state.amount > 0, state.combatant.role == .enemy {
            let bonus = CombatTriggerEngine.heroCardDamageBonus(keyword: state.damageKeyword, sourceID: state.sourceActorID, in: &context)
            state.remaining += bonus
            state.buildupDamage += bonus
            state.unique.outgoingDamage += bonus
            state.heroCardBlockIgnore = CombatTriggerEngine.heroCardBlockIgnore(
                keyword: state.damageKeyword,
                sourceID: state.sourceActorID,
                in: &context,
            )
        }
    }

    /// Single choke point for nested reaction damage (retaliation, wards,
    /// talent strikes, blocked-damage answers). DoT-typed mirrors branch to
    /// the applicator before reaching this helper.
    ///
    /// The `.thornsTriggered` decorator is never added here. Ward paths that
    /// need it must call `appendNestedDamage`, which makes the decorator
    /// explicit at the call site; every other nested-damage caller uses this
    /// function directly so no decorator fires.
    static func resolveNestedDamage(
        amount: Int,
        keyword: Keyword,
        target: Combatant,
        sourceActorID: String?,
        requireTargetAlive: Bool = false,
        requireSourceAlive source: Combatant? = nil,
        in context: inout BattleState,
    ) -> CombatOutcome {
        guard amount > 0 else {
            return .empty
        }
        if requireTargetAlive, context.roster.health(for: target) == 0 {
            return .empty
        }
        if let source, context.roster.health(for: source) == 0 {
            return .empty
        }
        return context.resolveDamage(DamageRequest(
            amount: amount,
            target: target,
            keyword: keyword,
            sourceActorID: sourceActorID,
            options: .reaction(),
        ))
    }

    /// Ward-only sibling of `resolveNestedDamage`: resolves nested damage and
    /// appends the `.thornsTriggered` decorator when damage lands. Call sites
    /// are limited to defender-ward retaliation (freeze wards, typed wards,
    /// thorns); talent strikes, reflections, and other nested damage must call
    /// `resolveNestedDamage` directly so the decorator stays off.
    static func appendNestedDamage(
        amount: Int,
        keyword: Keyword,
        abilityName: String,
        target: Combatant,
        defender: Combatant,
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard amount > 0 else { return }
        let outcome = resolveNestedDamage(
            amount: amount,
            keyword: keyword,
            target: target,
            sourceActorID: defender.id,
            in: &context,
        )
        var retaliationEvents = outcome.events
        if outcome.healthLost > 0 {
            retaliationEvents.append(context.nextEvent(
                kind: .effect,
                effectKind: .thornsTriggered,
                actorName: defender.name,
                abilityName: abilityName,
                target: target,
                amount: outcome.healthLost,
                keyword: keyword,
            ))
        }
        state.damageEvents.append(contentsOf: retaliationEvents)
    }

    static func appendAbsorption(
        _ amount: Int,
        abilityName: String,
        keyword: Keyword,
        actorName: String,
        target: Combatant,
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        state.remaining -= amount
        state.damageEvents.append(context.nextEvent(
            kind: .effect,
            effectKind: .shieldAbsorbed,
            actorName: actorName,
            abilityName: abilityName,
            target: target,
            amount: amount,
            keyword: keyword,
            isFullyBlocked: state.remaining == 0 && amount > 0,
        ))
    }
}
