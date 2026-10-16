import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    /// Explicit trigger chance, falling back to guaranteed (1) when only the
    /// flat enabler is present. Used by detonation and control gates.
    static func chanceOrGuaranteed(_ explicitChance: Double, guaranteed: Bool) -> Double {
        explicitChance > 0 ? explicitChance : (guaranteed ? 1 : 0)
    }

    static func afterDecayingDoTApplied(
        keyword: Keyword,
        to _: Combatant,
        sourceActorID: String,
        in context: inout BattleState,
    ) {
        guard keyword == .burn, let source = context.roster.combatant(for: sourceActorID) else { return }
        let dodgeBonus = context.modifiers(for: sourceActorID).triggers.onApplyBurnDodgeChanceUntilNextTurn
        if dodgeBonus > 0 {
            context.roster.mutateRuntime(for: source.combatant) {
                $0.talents.grantDodgeUntilNextTurn(dodgeBonus)
            }
        }
    }

    static func totalPotency(
        of keyword: Keyword,
        on combatant: Combatant,
        in context: BattleState,
    ) -> Int {
        context.roster.activeEffects(for: combatant).reduce(0) { sum, active in
            SaturatedArithmetic.saturatingAdd(sum, active.effect.keyword == keyword ? (active.effect.potency ?? 0) : 0)
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity - ordered damage triggers share one cadence
    static func damageBonus(
        for state: DamageResolutionState,
        in context: inout BattleState,
    ) -> Int {
        guard let sourceActorID = state.sourceActorID,
              let damageKeyword = state.damageKeyword,
              let source = context.roster.combatant(for: sourceActorID)
        else { return 0 }

        let profile = context.modifiers(for: sourceActorID)
        let triggers = profile.triggers
        let sharedKeyword = UniqueCombatEngine.sharedDamageKeyword(for: damageKeyword, triggers: triggers)
        let target = state.combatant
        let status = state.targetStatus
        let sourceHasBlock = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: source.combatant)) > 0
        var bonus = 0

        if damageKeyword == .freeze, status.isBurning {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.freezeDamageWhileBurningBonus)
        }
        if status.isFrozen {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.damageWhileTargetFrozenBonus)
        }
        if status.isStunned, source.role != .enemy || state.options.isAttackHit {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.damageWhileTargetStunnedBonus)
        }

        if state.options.isAttackHit, triggers.damageBelowHealthPercentBonus > 0,
           triggers.damageBelowHealthPercentKeyword == nil || triggers.damageBelowHealthPercentKeyword == damageKeyword
           || triggers.damageBelowHealthPercentKeyword == sharedKeyword,
           triggers.damageBelowHealthPercentThreshold > 0,
           context.roster.maxHealth(for: target) > 0 {
            let percent = Double(context.roster.health(for: target)) /
                Double(context.roster.maxHealth(for: target))
            if percent < triggers.damageBelowHealthPercentThreshold {
                bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.damageBelowHealthPercentBonus)
            }
        }

        if status.isBleeding, source.role != .enemy || state.options.isAttackHit {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.damageVsBleedingBonus)
        }
        if damageKeyword == .physical || sharedKeyword == .physical,
           DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: target)) > 0 {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.physicalDamageVsBlockedBonus)
        }
        if status.isBurning, triggers.damagePerBurnPotencyPercent > 0 {
            bonus = SaturatedArithmetic.saturatingAdd(
                bonus, CombatRounding.scaled(
                    totalPotency(of: .burn, on: target, in: context),
                    multiplier: triggers.damagePerBurnPotencyPercent,
                ),
            )
        }
        bonus = SaturatedArithmetic.saturatingAdd(
            bonus, partyAuraDamageBonus(
                for: state,
                source: source,
                damageKeyword: damageKeyword,
                targetIsPoisoned: status.isPoisoned,
                targetIsBurning: status.isBurning,
                in: context,
            ),
        )
        if damageKeyword == .holy, status.isStunned {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.holyDamageVsStunnedBonus)
        }
        if damageKeyword == .burn || sharedKeyword == .burn, status.isFrozen {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.burnDamageVsFrozenBonusPhysical)
        }
        if damageKeyword == .freeze, status.isFrozen {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.frostDamageVsFrozenBonus)
        }
        if sourceHasBlock, source.role != .enemy || state.options.isAttackHit {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.shieldDamageBonusWhileBlocked)
        }
        if context.roster.health(for: target) < context.roster.health(for: source.combatant) {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.damageVsLowerHealthEnemyBonus)
        }
        if triggers.damagePerMissingHealthEvery > 0,
           context.roster.maxHealth(for: source.combatant) > 0 {
            let missing = max(0, context.roster.maxHealth(for: source.combatant) - context.roster.health(for: source.combatant))
            bonus = SaturatedArithmetic.saturatingAdd(bonus, missing / triggers.damagePerMissingHealthEvery)
        }
        if triggers.goldReservesDamageEvery > 0 {
            let uncapped = context.gold / triggers.goldReservesDamageEvery
            bonus = SaturatedArithmetic.saturatingAdd(
                bonus, triggers.goldReservesDamageCap > 0
                    ? min(triggers.goldReservesDamageCap, uncapped)
                    : uncapped,
            )
        }
        return bonus
    }

    static func damageMultiplier(
        for state: DamageResolutionState,
        in context: BattleState,
    ) -> Double {
        guard let sourceActorID = state.sourceActorID,
              let damageKeyword = state.damageKeyword,
              let source = context.roster.combatant(for: sourceActorID)
        else { return 1 }

        let profile = context.modifiers(for: sourceActorID)
        let triggers = profile.triggers
        let target = state.combatant
        let status = state.targetStatus
        let targetHasBlock = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: target)) > 0
        let sharedKeyword = UniqueCombatEngine.sharedDamageKeyword(for: damageKeyword, triggers: triggers)
        let targetBelowPoisonThreshold = triggers.poisonDamageBelowHealthThreshold > 0
            && context.roster.maxHealth(for: target) > 0
            && Double(context.roster.health(for: target)) / Double(context.roster.maxHealth(for: target))
            < triggers.poisonDamageBelowHealthThreshold

        var multiplier = 1.0
        if source.role != .enemy {
            multiplier *= partyAfflictedDamageMultiplier(
                targetIsPoisoned: status.isPoisoned,
                targetIsBurning: status.isBurning,
                in: context,
            )
        } else {
            if status.isPoisoned {
                multiplier *= triggers.damageVsPoisonedMultiplier
            }
            if status.isBurning, state.options.isAttackHit {
                multiplier *= triggers.damageVsBurningMultiplier
            }
        }
        if status.isBurning, source.id == context.roster.companion.id {
            multiplier *= triggers.companionDamageVsBurningMultiplier
        }
        if status.isFrozen {
            multiplier *= triggers.damageVsFrozenMultiplier
        }
        if damageKeyword == .holy {
            if status.isStunned || status.isBurning {
                multiplier *= triggers.holyDamageVsStunnedOrBurningMultiplier
            }
            if status.isPoisoned || status.isBleeding {
                multiplier *= triggers.holyDamageVsPoisonedOrBleedingMultiplier
            }
            if context.enemyFaction == .undead || context.enemyFaction == .corrupted {
                multiplier *= triggers.holyDamageVsUndeadOrCorruptedMultiplier
            }
        }
        if damageKeyword == .burn || sharedKeyword == .burn, !targetHasBlock {
            multiplier *= triggers.burnDamageVsNoBlockMultiplier
        }
        if damageKeyword == .physical || sharedKeyword == .physical, status.isBleeding {
            multiplier *= triggers.physicalDamageVsBleedingMultiplier
        }
        if source.role == .hero, status.isStunned {
            multiplier *= triggers.heroDamageVsStunnedMultiplier
            multiplier *= companionExposedPreyMultiplier(in: context)
        }
        if damageKeyword == .poison, targetBelowPoisonThreshold {
            multiplier *= triggers.poisonDamageBelowHealthMultiplier
        }
        return multiplier
    }

    private static func companionExposedPreyMultiplier(in context: BattleState) -> Double {
        context.roster.companion.isAlive
            ? context.companionModifiers.triggers.heroDamageVsStunnedMultiplier : 1
    }

    static func afterStunDamageDealt(
        to _: Combatant,
        source: Combatant,
        in context: inout BattleState,
    ) {
        let amount = context.modifiers(for: source.id).triggers.stunDamageBlockFlat
        guard amount > 0 else { return }
        emitBlock(.stunDamageBlockFlat, "Oathbound", amount: amount, to: source, source: source, in: &context)
    }

    static func afterBurnDamageDealt(
        to _: Combatant,
        source: Combatant,
        healthLost: Int,
        in context: inout BattleState,
    ) async {
        let triggers = context.modifiers(for: source.id).triggers
        if context.health(of: source) > 0 {
            await burnDamageHeals(triggers: triggers, source: source, in: &context)
        }
        if triggers.onBurnDamageGainBlock > 0, context.health(of: source) > 0 {
            emitBlock(
                .onBurnDamageGainBlock, "Flame Shield",
                amount: triggers.onBurnDamageGainBlock, to: source, source: source, in: &context,
            )
        }
        emberShieldIfNeeded(source: source, in: &context)
        if triggers.onBurnDamageRestoreManaFlat > 0, context.health(of: source) > 0,
           healthLost >= triggers.burnDamageManaRestoreThreshold {
            await restoreManaFromBurnDamage(sourceActorID: source.id, sourceTriggers: triggers, in: &context)
        }
    }

    static func afterFreezeDamageDealt(
        to _: Combatant,
        source: Combatant,
        amount: Int,
        in context: inout BattleState,
    ) {
        let triggers = context.modifiers(for: source.id).triggers
        guard triggers.freezeDamageGrantsBlock, amount > 0, context.health(of: source) > 0 else { return }
        context.applyBlockGain(
            amount,
            to: source,
            source: source,
            abilityName: triggerAbilityName(.freezeDamageGrantsBlock, for: source, fallback: "Rimeheart", in: context),
            amountBasis: .resolved,
        )
    }

    private static func burnDamageHeals(
        triggers: CombatTraitTriggers,
        source: Combatant,
        in context: inout BattleState,
    ) async {
        if triggers.onBurnDamageHealLowestAllyFlat > 0 {
            let lowest = BattleConditionEvaluator.lowestHealthAlly(in: context)
            await emitHeal(
                .onBurnDamageHealLowestAllyFlat, "Healing Flames",
                amount: triggers.onBurnDamageHealLowestAllyFlat, to: lowest, source: source, in: &context,
            )
        }
    }

    private static func emberShieldIfNeeded(
        source: Combatant,
        in context: inout BattleState,
    ) {
        guard source.role != .enemy,
              context.roster.companion.isAlive,
              source.id != context.roster.companion.id,
              context.companionModifiers.triggers.onAllyBurnDamageGainBlock > 0
        else { return }
        emitBlock(
            .onAllyBurnDamageGainBlock, "Ember Shield",
            amount: context.companionModifiers.triggers.onAllyBurnDamageGainBlock,
            to: context.roster.companion.combatant,
            source: context.roster.companion.combatant,
            in: &context,
        )
    }

    // swiftlint:disable:next function_body_length - one pass owns the ordered damage reaction sequence
    static func afterCriticalHit(
        to enemy: Combatant,
        source: Combatant,
        targetWasStunnedAtHit: Bool,
        isAttackHit: Bool = false,
        in context: inout BattleState,
    ) async {
        guard source.role != .enemy else { return }
        let profile = context.modifiers(for: source.id)
        await applyPurge(
            to: enemy,
            source: source,
            abilityName: triggerAbilityName(
                profile.triggers.criticalPurgeAll ? .criticalPurgeAll : .criticalPurgeCount,
                for: source,
                fallback: "Unmaking",
                in: context,
            ),
            count: profile.triggers.criticalPurgeCount,
            purgeAll: profile.triggers.criticalPurgeAll,
            in: &context,
        )
        if source.role == .companion, context.roster.health(for: source) > 0, context.roster.hero.isAlive,
           context.heroModifiers.triggers.toxicTransfusion {
            context.roster.mutateRuntime(for: context.roster.hero.combatant) {
                $0.talents.pending.doubleNextPoisonAttack = true
            }
        }

        if isAttackHit, source.role == .hero, context.allowsHeroTalentReaction,
           profile.triggers.criticalGoldStealFlat > 0, context.roster.health(for: source) > 0 {
            _ = await context.grantGold(
                profile.triggers.criticalGoldStealFlat, to: source,
                abilityName: triggerAbilityName(.criticalGoldStealFlat, for: source, fallback: "Light Fingers", in: context),
                isTheft: true,
            )
        }
        if profile.triggers.criticalGoldFlat > 0, context.roster.health(for: source) > 0 {
            await emitGold(.criticalGoldFlat, "Cutpurse", amount: profile.triggers.criticalGoldFlat, to: source, in: &context)
        }

        if profile.triggers.criticalActionGoldFlat > 0,
           context.roster.health(for: source) > 0,
           context.claimActionGuard(.criticalActionGold, actorID: source.id) {
            await emitGold(
                .criticalActionGoldFlat, "Lucky Clover",
                amount: profile.triggers.criticalActionGoldFlat, to: source, in: &context,
            )
        }

        for (keyword, potency) in [
            (Keyword.poison, profile.triggers.criticalApplyPoison),
            (Keyword.burn, profile.triggers.criticalApplyBurn),
        ] where potency > 0 && context.roster.health(for: enemy) > 0 {
            await DoTApplicator.applyDoT(keyword: keyword, potency: potency, to: enemy, sourceActorID: source.id, in: &context)
        }
        let shouldDetonateBleed = profile.triggers.criticalOnBleedingDetonateBleed
            || (profile.triggers.criticalOnBleedingDetonateBleedChance > 0
                && BattleChance.succeeds(probability: profile.triggers.criticalOnBleedingDetonateBleedChance, using: &context.rng))
        if shouldDetonateBleed, context.roster.health(for: enemy) > 0 {
            await detonateBleed(on: enemy, sourceActorID: source.id, in: &context)
        }
        if profile.triggers.criticalDetonateBleedAndPoison, context.roster.health(for: enemy) > 0 {
            await detonateBleedAndPoison(on: enemy, sourceActorID: source.id, in: &context)
        }
        if profile.triggers.onCritDoubleBleedDuration {
            var effects = context.roster.activeEffects(for: enemy)
            for index in effects.indices where effects[index].effect.isBleed {
                effects[index].remainingTurns = min(10, SaturatedArithmetic.saturatingMul(effects[index].remainingTurns, 2))
            }
            context.roster.setActiveEffects(effects, for: enemy)
        }
        if profile.triggers.criticalVsStunnedEnemyGold > 0,
           context.roster.health(for: source) > 0,
           targetWasStunnedAtHit {
            _ = await context.grantGold(
                profile.triggers.criticalVsStunnedEnemyGold,
                to: source,
                abilityName: triggerAbilityName(
                    .criticalVsStunnedEnemyGold, for: source, fallback: "Confounding Loot", in: context,
                ),
                isTheft: true,
            )
        }
    }

    static func detonateBleed(
        on target: Combatant,
        sourceActorID: String,
        in context: inout BattleState,
    ) async {
        await detonateBleedAndPoison(on: target, sourceActorID: sourceActorID, includePoison: false, in: &context)
    }

    static func companionSpitPoison(
        to target: Combatant,
        in context: inout BattleState,
    ) async {
        guard let companionTriggers = companionReactingToHeroTriggers(in: context),
              companionTriggers.onHeroAttackPoisonedEnemyApplyPoison > 0
        else { return }
        await context.applyDecayingDoT(
            keyword: .poison,
            potency: companionTriggers.onHeroAttackPoisonedEnemyApplyPoison,
            to: target,
            sourceActorID: context.roster.companion.id,
            application: .reaction,
        )
    }
}
