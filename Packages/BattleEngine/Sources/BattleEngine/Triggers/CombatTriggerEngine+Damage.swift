import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    /// Explicit trigger chance, falling back to guaranteed (1) when only the
    /// flat enabler is present. Shared by the bleed/burn conversion gates,
    /// which differ only in the key they read.
    static func chanceOrGuaranteed(_ explicitChance: Double, guaranteed: Bool) -> Double {
        explicitChance > 0 ? explicitChance : (guaranteed ? 1 : 0)
    }

    /// Damage conversions run once per positive Health-damage packet, including ticks.
    static func afterBleedDamageConversions(
        to target: Combatant,
        sourceActorID: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.roster.combatant(for: sourceActorID) != nil else { return [] }
        return withDoTRecursionScope(site: "afterBleedDamageConversions", context: &context) { context in
            let profile = context.modifiers(for: sourceActorID)
            var events: [ActionEvent] = []

            let bleedPoisonChance = chanceOrGuaranteed(
                profile.triggers.onBleedDealPoisonChancePercent,
                guaranteed: profile.triggers.onBleedApplyPoison > 0,
            )
            if profile.triggers.onBleedApplyPoison > 0, bleedPoisonChance > 0,
               BattleChance.succeeds(probability: min(1, bleedPoisonChance), using: &context.rng) {
                events.append(contentsOf: context.applyDecayingDoT(
                    keyword: .poison,
                    potency: profile.triggers.onBleedApplyPoison,
                    to: target,
                    sourceActorID: sourceActorID,
                    application: .reaction,
                ))
            }

            let bleedBurnChance = chanceOrGuaranteed(
                profile.triggers.onBleedDealBurnChancePercent,
                guaranteed: profile.triggers.onBleedDealBurnDamage > 0,
            )
            if profile.triggers.onBleedDealBurnDamage > 0, bleedBurnChance > 0,
               BattleChance.succeeds(probability: min(1, bleedBurnChance), using: &context.rng) {
                events.append(contentsOf: DoTDamage.resolveDamage(
                    basePotency: profile.triggers.onBleedDealBurnDamage,
                    keyword: .burn,
                    target: target,
                    sourceActorID: sourceActorID,
                    in: &context,
                ).events)
            }

            return events
        }
    }

    static func afterDecayingDoTApplied(
        keyword: Keyword,
        to _: Combatant,
        sourceActorID: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard keyword == .burn, let source = context.roster.combatant(for: sourceActorID) else { return [] }
        let dodgeBonus = context.modifiers(for: sourceActorID).triggers.onApplyBurnDodgeChanceUntilNextTurn
        if dodgeBonus > 0 {
            context.roster.mutateRuntime(for: source.combatant) {
                $0.talents.grantDodgeUntilNextTurn(dodgeBonus)
            }
        }
        return []
    }

    static func afterBurnDamageConversion(
        to target: Combatant,
        sourceActorID: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let triggers = context.modifiers(for: sourceActorID).triggers
        let potency = triggers.onBurnApplyPoison
        guard potency > 0 else { return [] }
        return withDoTRecursionScope(site: "afterBurnDamageConversion", context: &context) { context in
            let chance = chanceOrGuaranteed(triggers.onBurnDealPoisonChancePercent, guaranteed: true)
            guard BattleChance.succeeds(probability: min(1, chance), using: &context.rng) else { return [] }
            return context.applyDecayingDoT(
                keyword: .poison, potency: potency, to: target,
                sourceActorID: sourceActorID, application: .reaction,
            )
        }
    }

    static func totalPotency(
        of keyword: Keyword,
        on combatant: Combatant,
        in context: BattleState,
    ) -> Int {
        context.roster.activeEffects(for: combatant).reduce(0) { sum, active in
            sum + (active.effect.keyword == keyword ? (active.effect.potency ?? 0) : 0)
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
            bonus += triggers.freezeDamageWhileBurningBonus
        }
        if status.isFrozen {
            bonus += triggers.damageWhileTargetFrozenBonus
        }
        if status.isStunned, source.role != .enemy || state.options.isAttackHit {
            bonus += triggers.damageWhileTargetStunnedBonus
        }

        if triggers.damageBelowHealthPercentBonus > 0,
           triggers.damageBelowHealthPercentKeyword == nil || triggers.damageBelowHealthPercentKeyword == damageKeyword
           || triggers.damageBelowHealthPercentKeyword == sharedKeyword,
           triggers.damageBelowHealthPercentThreshold > 0,
           context.roster.maxHealth(for: target) > 0 {
            let percent = Double(context.roster.health(for: target)) /
                Double(context.roster.maxHealth(for: target))
            if percent < triggers.damageBelowHealthPercentThreshold {
                bonus += triggers.damageBelowHealthPercentBonus
            }
        }

        if status.isBleeding, source.role != .enemy || state.options.isAttackHit {
            bonus += triggers.damageVsBleedingBonus
        }
        if damageKeyword == .physical,
           DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: target)) > 0 {
            bonus += triggers.physicalDamageVsBlockedBonus
        }
        if status.isBurning, triggers.damagePerBurnPotencyPercent > 0 {
            bonus += CombatRounding.scaled(
                totalPotency(of: .burn, on: target, in: context),
                multiplier: triggers.damagePerBurnPotencyPercent,
            )
        }
        bonus += partyAuraDamageBonus(
            for: state,
            source: source,
            damageKeyword: damageKeyword,
            targetIsPoisoned: status.isPoisoned,
            targetIsBurning: status.isBurning,
            in: context,
        )
        if damageKeyword == .holy, status.isStunned {
            bonus += triggers.holyDamageVsStunnedBonus
        }
        if damageKeyword == .burn || sharedKeyword == .burn, status.isFrozen {
            bonus += triggers.burnDamageVsFrozenBonusPhysical
        }
        if damageKeyword == .freeze, status.isFrozen {
            bonus += triggers.frostDamageVsFrozenBonus
        }
        if sourceHasBlock, source.role != .enemy || state.options.isAttackHit {
            bonus += triggers.shieldDamageBonusWhileBlocked
        }
        if context.roster.health(for: target) < context.roster.health(for: source.combatant) {
            bonus += triggers.damageVsLowerHealthEnemyBonus
        }
        if triggers.damagePerMissingHealthEvery > 0,
           context.roster.maxHealth(for: source.combatant) > 0 {
            let missing = max(0, context.roster.maxHealth(for: source.combatant) - context.roster.health(for: source.combatant))
            bonus += missing / triggers.damagePerMissingHealthEvery
        }
        if triggers.goldReservesDamageEvery > 0 {
            let uncapped = context.gold / triggers.goldReservesDamageEvery
            bonus += triggers.goldReservesDamageCap > 0
                ? min(triggers.goldReservesDamageCap, uncapped)
                : uncapped
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
    ) -> [ActionEvent] {
        let amount = context.modifiers(for: source.id).triggers.stunDamageBlockFlat
        guard amount > 0 else { return [] }
        return emitBlock(
            "stunDamageBlockFlat", "Oathbound", amount: amount, to: source, source: source, in: &context,
        )
    }

    static func afterBurnDamageDealt(
        to _: Combatant,
        source: Combatant,
        healthLost: Int,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let triggers = context.modifiers(for: source.id).triggers
        var events = burnDamageHeals(triggers: triggers, source: source, in: &context)
        if triggers.onBurnDamageGainBlock > 0 {
            events.append(contentsOf: emitBlock(
                "onBurnDamageGainBlock", "Flame Shield",
                amount: triggers.onBurnDamageGainBlock, to: source, source: source, in: &context,
            ))
        }
        events.append(contentsOf: emberShieldIfNeeded(source: source, in: &context))
        if triggers.onBurnDamageRestoreManaFlat > 0,
           healthLost >= triggers.burnDamageManaRestoreThreshold {
            events.append(contentsOf: restoreManaFromBurnDamage(
                sourceActorID: source.id,
                sourceTriggers: triggers,
                in: &context,
            ))
        }
        return events
    }

    static func afterFreezeDamageDealt(
        to _: Combatant,
        source: Combatant,
        amount: Int,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let triggers = context.modifiers(for: source.id).triggers
        guard triggers.freezeDamageGrantsBlock, amount > 0, context.health(of: source) > 0 else { return [] }
        return context.applyBlock(
            amount,
            to: source,
            source: source,
            abilityName: triggerAbilityName("freezeDamageGrantsBlock", for: source, fallback: "Rimeheart", in: context),
            amountBasis: .resolved,
        )
    }

    private static func burnDamageHeals(
        triggers: CombatTraitTriggers,
        source: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.onBurnDamageHealLowestAllyFlat > 0 {
            let lowest = BattleConditionEvaluator.lowestHealthAlly(in: context)
            events.append(contentsOf: emitHeal(
                "onBurnDamageHealLowestAllyFlat", "Healing Flames",
                amount: triggers.onBurnDamageHealLowestAllyFlat, to: lowest, source: source, in: &context,
            ))
        }
        return events
    }

    private static func emberShieldIfNeeded(
        source: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard source.role != .enemy,
              context.roster.companion.isAlive,
              source.id != context.roster.companion.id,
              context.companionModifiers.triggers.onAllyBurnDamageGainBlock > 0
        else { return [] }
        return emitBlock(
            "onAllyBurnDamageGainBlock", "Ember Shield",
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
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard source.role != .enemy else { return [] }
        let profile = context.modifiers(for: source.id)
        var events = applyPurge(
            to: enemy,
            source: source,
            abilityName: triggerAbilityName(
                profile.triggers.criticalPurgeAll ? "criticalPurgeAll" : "criticalPurgeCount",
                for: source,
                fallback: "Unmaking",
                in: context,
            ),
            count: profile.triggers.criticalPurgeCount,
            purgeAll: profile.triggers.criticalPurgeAll,
            in: &context,
        )
        if source.role == .companion, context.roster.hero.isAlive,
           context.heroModifiers.triggers.toxicTransfusion {
            context.roster.mutateRuntime(for: context.roster.hero.combatant) {
                $0.talents.pending.doubleNextPoisonAttack = true
            }
        }

        if profile.triggers.criticalGoldFlat > 0, context.roster.health(for: source) > 0 {
            events.append(contentsOf: emitGold(
                "criticalGoldFlat", "Cutpurse", amount: profile.triggers.criticalGoldFlat, to: source, in: &context,
            ))
        }

        if profile.triggers.criticalActionGoldFlat > 0,
           context.roster.health(for: source) > 0,
           context.claimActionGuard(.criticalActionGold, actorID: source.id) {
            events.append(contentsOf: emitGold(
                "criticalActionGoldFlat", "Lucky Clover",
                amount: profile.triggers.criticalActionGoldFlat, to: source, in: &context,
            ))
        }

        for (keyword, potency) in [
            (Keyword.poison, profile.triggers.criticalApplyPoison),
            (Keyword.burn, profile.triggers.criticalApplyBurn),
        ] where potency > 0 && context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: applyDoT(
                keyword: keyword,
                potency: potency,
                to: enemy,
                sourceActorID: source.id,
                in: &context,
            ))
        }
        let shouldDetonateBleed = profile.triggers.criticalOnBleedingDetonateBleed
            || (profile.triggers.criticalOnBleedingDetonateBleedChance > 0
                && BattleChance.succeeds(probability: profile.triggers.criticalOnBleedingDetonateBleedChance, using: &context.rng))
        if shouldDetonateBleed, context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: detonateBleed(on: enemy, sourceActorID: source.id, in: &context))
        }
        if profile.triggers.criticalDetonateBleedAndPoison, context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: detonateBleedAndPoison(
                on: enemy,
                sourceActorID: source.id,
                in: &context,
            ))
        }
        if profile.triggers.onCritDoubleBleedDuration {
            var effects = context.roster.activeEffects(for: enemy)
            for index in effects.indices where effects[index].effect.isBleed {
                effects[index].remainingTurns = min(10, effects[index].remainingTurns * 2)
            }
            context.roster.setActiveEffects(effects, for: enemy)
        }
        if profile.triggers.criticalVsStunnedEnemyGold > 0,
           context.roster.health(for: source) > 0,
           context.roster.hasControlStatus(for: enemy, keyword: .stun) {
            events.append(contentsOf: context.grantGoldEvent(
                profile.triggers.criticalVsStunnedEnemyGold,
                to: source,
                abilityName: triggerAbilityName(
                    "criticalVsStunnedEnemyGold", for: source, fallback: "Confounding Loot", in: context,
                ),
                isTheft: true,
            ))
        }

        return events
    }

    static func detonateBleed(
        on target: Combatant,
        sourceActorID: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        detonateBleedAndPoison(on: target, sourceActorID: sourceActorID, includePoison: false, in: &context)
    }

    static func companionSpitPoison(
        to target: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard let companionTriggers = companionReactingToHeroTriggers(in: context),
              companionTriggers.onHeroAttackPoisonedEnemyApplyPoison > 0
        else { return [] }
        return context.applyDecayingDoT(
            keyword: .poison,
            potency: companionTriggers.onHeroAttackPoisonedEnemyApplyPoison,
            to: target,
            sourceActorID: context.roster.companion.id,
            application: .reaction,
        )
    }
}
