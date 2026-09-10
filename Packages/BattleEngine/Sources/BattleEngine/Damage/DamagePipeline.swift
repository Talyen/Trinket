import Foundation
import TrinketContent
import TrinketCore

package enum DamagePipeline {
    package static func run(
        state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
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
        if state.options.isOriginalCardDamage, state.amount > 0, state.combatant.role == .enemy {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterHeroCardHit(
                keyword: state.damageKeyword, sourceID: state.sourceActorID, critical: state.isCritical,
                fullyBlocked: state.blockedAmount > 0 && state.remaining == 0,
                blockBroken: state.heroCardBlockBroken, targetWasFrozen: state.targetStatus.isFrozen, in: &context,
            ))
        }

        applyDoTDamageReactions(to: &state, in: &context)
        applyLeech(to: &state, in: &context)
        applyTalentDamageApplications(to: &state, in: &context)
        applyTalentMirroredReactions(to: &state, in: &context)

        applyControlMeter(to: &state, in: &context)
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

    static func applyWinterWake(to state: inout DamageResolutionState, in context: inout BattleState) {
        guard !state.options.causedByDodge, state.options.isAttackHit,
              context.modifiers(for: state.combatant.id).triggers.wintersWake,
              let attackerID = state.sourceActorID,
              let attacker = context.roster.combatant(for: attackerID), attacker.isAlive else { return }
        var preview = context
        var avoided = state
        avoided.targetStatus = DamageTargetStatus(for: state.combatant, in: preview)
        applyOutgoingDamage(to: &avoided, in: &preview)
        applyTakenFlatAdjustments(to: &avoided, in: &preview)
        let amount = CombatRounding.scaled(avoided.remaining, multiplier: 0.5)
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
            state.uniqueOutgoingDamage = CombatRounding.scaled(
                state.remaining - state.options.partnerFirstAttackBonus,
                multiplier: state.isCritical ? criticalMultiplier(for: state.sourceActorID, in: context) : 1,
            )
        }
        applyTakenPercentAdjustments(to: &state, in: &context)
        if !state.options.usesResolvedOutgoingDamage {
            applyCriticalMultiply(to: &state, in: &context)
        }
        applyBackdraftBonus(to: &state, in: &context)
        if state.options.isOriginalCardDamage, state.amount > 0, state.combatant.role == .enemy {
            let bonus = CombatTriggerEngine.heroCardDamageBonus(keyword: state.damageKeyword, sourceID: state.sourceActorID, in: &context)
            state.remaining += bonus
            state.buildupDamage += bonus
            state.uniqueOutgoingDamage += bonus
            state.heroCardBlockIgnore = CombatTriggerEngine.heroCardBlockIgnore(
                keyword: state.damageKeyword,
                sourceID: state.sourceActorID,
                in: &context,
            )
        }
    }

    static func resolveRetaliation(
        amount: Int,
        keyword: Keyword,
        target: Combatant,
        sourceActorID: String?,

        in context: inout BattleState,
    ) -> CombatOutcome {
        context.resolveDamage(DamageRequest(
            amount: amount,
            target: target,
            keyword: keyword,
            sourceActorID: sourceActorID,
            options: .reaction(),
        ))
    }

    static func appendBleed(
        potency: Int,
        to target: Combatant,
        sourceActorID: String,
        durationTurns: Int? = nil,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        DoTApplicator.applyBleed(
            potency: potency,
            to: target,
            sourceActorID: sourceActorID,
            application: .attached,
            durationTurns: durationTurns,
            in: &context,
        )
    }

    static func appendMeterCharge(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?,
        applyFightPacing: Bool = false,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        ControlMeterEngine.applyMeterCharge(
            amount,
            keyword: keyword,
            to: combatant,
            sourceActorID: sourceActorID,
            applyFightPacing: applyFightPacing,
            in: &context,
        )
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
        ))
    }
}
