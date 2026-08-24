import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterBleedApplied(
        to target: Combatant,
        sourceActorID: String,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard context.roster.combatant(for: sourceActorID) != nil else { return [] }
        guard context.dotRecursionDepth < 2 else { return [] }
        context.dotRecursionDepth += 1
        defer { context.dotRecursionDepth -= 1 }
        let profile = context.modifiers(for: sourceActorID)
        var events: [ActionEvent] = []

        if profile.triggers.onBleedApplyPoison > 0 {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison,
                potency: profile.triggers.onBleedApplyPoison,
                to: target,
                sourceActorID: sourceActorID,
                dealImmediateDamage: true,
                suppressAffixReactions: true
            ))
        }

        if profile.triggers.onBleedDealBurnDamage > 0 {
            events.append(contentsOf: DoTDamage.resolveTurnDamage(
                basePotency: profile.triggers.onBleedDealBurnDamage,
                keyword: .burn,
                target: target,
                sourceActorID: sourceActorID,
                in: &context
            ).events)
        }

        return events
    }

    static func afterDecayingDoTApplied(
        keyword: Keyword,
        to target: Combatant,
        sourceActorID: String,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard context.dotRecursionDepth < 2 else { return [] }
        context.dotRecursionDepth += 1
        defer { context.dotRecursionDepth -= 1 }
        var events: [ActionEvent] = []
        // Smoke Screen: inflicting Burn grants +Dodge chance until your next turn.
        if keyword == .burn,
           let source = context.roster.combatant(for: sourceActorID) {
            let dodgeBonus = context.modifiers(for: sourceActorID).triggers.onApplyBurnDodgeChanceUntilNextTurn
            if dodgeBonus > 0 {
                context.roster.mutateRuntime(for: source.combatant) {
                    $0.bonusDodgeUntilNextTurn += dodgeBonus
                }
            }
        }
        guard keyword == .burn else { return events }
        let potency = context.modifiers(for: sourceActorID).triggers.onBurnApplyPoison
        guard potency > 0 else { return events }
        events.append(contentsOf: context.applyDecayingDoT(
            keyword: .poison,
            potency: potency,
            to: target,
            sourceActorID: sourceActorID,
            dealImmediateDamage: true,
            suppressAffixReactions: true
        ))
        return events
    }

    /// Total potency of all active DoT effects of `keyword` on `combatant`.
    static func totalPotency(
        of keyword: Keyword,
        on combatant: Combatant,
        in context: BattleState
    ) -> Int {
        context.roster.activeEffects(for: combatant).reduce(0) { sum, active in
            sum + (active.effect.keyword == keyword ? (active.effect.potency ?? 0) : 0)
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    static func damageBonus(
        for state: DamageResolutionState,
        in context: inout BattleState
    ) -> Int {
        guard let sourceActorID = state.sourceActorID,
              let damageKeyword = state.damageKeyword,
              let source = context.roster.combatant(for: sourceActorID)
        else { return 0 }

        let profile = context.modifiers(for: sourceActorID)
        let triggers = profile.triggers
        let target = state.combatant
        let status = state.targetStatus
        let sourceHasBlock = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: source.combatant)) > 0
        var bonus = 0

        if damageKeyword == .freeze, status.isBurning {
            bonus += triggers.freezeDamageWhileBurningBonus
        }
        // Shatter is an aura: the enemy takes extra damage from party hits while Frozen.
        // Dazed is an aura: the enemy takes extra damage from party hits while Stunned.
        if source.role != .enemy {
            let partyTriggers = context.partyTriggers
            if status.isFrozen {
                bonus += partyTriggers.damageWhileTargetFrozenBonus
            }
            if status.isStunned {
                bonus += partyTriggers.damageWhileTargetStunnedBonus
            }
        }

        if triggers.damageBelowHealthPercentBonus > 0,
           triggers.damageBelowHealthPercentKeyword == nil || triggers.damageBelowHealthPercentKeyword == damageKeyword,
           triggers.damageBelowHealthPercentThreshold > 0,
           context.roster.maxHealth(for: target) > 0 {
            let percent = Double(context.roster.health(for: target)) /
                Double(context.roster.maxHealth(for: target))
            if percent < triggers.damageBelowHealthPercentThreshold {
                bonus += triggers.damageBelowHealthPercentBonus
            }
        }

        // Combatant Talent System — target-condition flat damage bonuses.
        if status.isBleeding {
            bonus += triggers.damageVsBleedingBonus
        }
        // Combustion: attacks against Burning enemies deal bonus damage per Burn potency.
        if status.isBurning, triggers.damagePerBurnPotencyPercent > 0 {
            bonus += CombatRounding.scaled(
                totalPotency(of: .burn, on: target, in: context),
                multiplier: triggers.damagePerBurnPotencyPercent
            )
        }
        bonus += partyAuraDamageBonus(
            for: state,
            source: source,
            damageKeyword: damageKeyword,
            targetIsPoisoned: status.isPoisoned,
            targetIsBurning: status.isBurning,
            in: context
        )
        if damageKeyword == .holy, status.isStunned {
            bonus += triggers.holyDamageVsStunnedBonus
        }
        if damageKeyword == .burn, status.isFrozen {
            bonus += triggers.burnDamageVsFrozenBonusPhysical
        }
        if damageKeyword == .freeze, status.isFrozen {
            bonus += triggers.frostDamageVsFrozenBonus
        }
        if sourceHasBlock {
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
        if triggers.damagePerCarriedGoldEvery > 0 {
            bonus += context.gold / triggers.damagePerCarriedGoldEvery
        }
        if triggers.goldReservesDamageEvery > 0 {
            let uncapped = context.gold / triggers.goldReservesDamageEvery
            bonus += triggers.goldReservesDamageCap > 0
                ? min(triggers.goldReservesDamageCap, uncapped)
                : uncapped
        }

        return bonus
    }

    /// Product of target-condition damage multipliers (Combatant Talent System).
    /// Applied in `DamagePipelineResolutionSteps.applyDamageBonus`.
    static func damageMultiplier(
        for state: DamageResolutionState,
        in context: BattleState
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
        let targetBelowPoisonThreshold = triggers.poisonDamageBelowHealthThreshold > 0
            && context.roster.maxHealth(for: target) > 0
            && Double(context.roster.health(for: target)) / Double(context.roster.maxHealth(for: target))
            < triggers.poisonDamageBelowHealthThreshold

        var multiplier = 1.0
        if source.role != .enemy {
            multiplier *= partyAfflictedDamageMultiplier(
                targetIsPoisoned: status.isPoisoned,
                targetIsBurning: status.isBurning,
                in: context
            )
        } else {
            if status.isPoisoned {
                multiplier *= triggers.damageVsPoisonedMultiplier
            }
            if status.isBurning {
                multiplier *= triggers.damageVsBurningMultiplier
            }
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
        if damageKeyword == .burn, !targetHasBlock {
            multiplier *= triggers.burnDamageVsNoBlockMultiplier
        }
        if damageKeyword == .physical, status.isBleeding {
            multiplier *= triggers.physicalDamageVsBleedingMultiplier
        }
        if source.role == .hero, status.isStunned {
            multiplier *= triggers.heroDamageVsStunnedMultiplier
        }
        if damageKeyword == .poison, targetBelowPoisonThreshold {
            multiplier *= triggers.poisonDamageBelowHealthMultiplier
        }
        return multiplier
    }

    static func afterStunDamageDealt(
        to _: Combatant,
        source: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let amount = context.modifiers(for: source.id).triggers.stunDamageBlockFlat
        guard amount > 0 else { return [] }
        return context.applyBlock(
            amount,
            to: source,
            source: source,
            abilityName: triggerAbilityName("stunDamageBlockFlat", for: source, fallback: "Oathbound", in: context)
        )
    }

    static func afterBurnDamageDealt(
        to _: Combatant,
        source: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let triggers = context.modifiers(for: source.id).triggers
        var events = burnDamageHeals(triggers: triggers, source: source, in: &context)
        if triggers.onBurnDamageGainBlock > 0 {
            events.append(contentsOf: context.applyBlock(
                triggers.onBurnDamageGainBlock,
                to: source,
                source: source,
                abilityName: triggerAbilityName("onBurnDamageGainBlock", for: source, fallback: "Flame Shield", in: context)
            ))
        }
        events.append(contentsOf: emberShieldIfNeeded(source: source, in: &context))
        return events
    }

    /// Rimeheart: dealing Freeze damage grants Block equal to the amount dealt.
    static func afterFreezeDamageDealt(
        to _: Combatant,
        source: Combatant,
        amount: Int,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let triggers = context.modifiers(for: source.id).triggers
        guard triggers.freezeDamageGrantsBlock, amount > 0 else { return [] }
        return context.applyBlock(
            amount,
            to: source,
            source: source,
            abilityName: triggerAbilityName("freezeDamageGrantsBlock", for: source, fallback: "Rimeheart", in: context)
        )
    }

    private static func burnDamageHeals(
        triggers: CombatTraitTriggers,
        source: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.burnDamageHealFlat > 0 {
            events.append(contentsOf: context.healEmitting(
                amount: triggers.burnDamageHealFlat,
                target: source,
                source: source,
                abilityName: triggerAbilityName(
                    "burnDamageHealFlat",
                    for: source,
                    fallback: "Bloodfire",
                    in: context
                )
            ))
        }
        if triggers.onBurnDamageHealLowestAllyFlat > 0 {
            let lowest = BattleConditionEvaluator.lowestHealthAlly(
                hero: context.roster.hero.combatant,
                companion: context.roster.companion.combatant,
                context: context
            )
            events.append(contentsOf: context.healEmitting(
                amount: triggers.onBurnDamageHealLowestAllyFlat,
                target: lowest,
                source: source,
                abilityName: triggerAbilityName(
                    "onBurnDamageHealLowestAllyFlat",
                    for: source,
                    fallback: "Healing Flames",
                    in: context
                )
            ))
        }
        return events
    }

    private static func emberShieldIfNeeded(
        source: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard source.role != .enemy,
              context.roster.companion.isAlive,
              source.id != context.roster.companion.id,
              context.companionModifiers.triggers.onAllyBurnDamageGainBlock > 0
        else { return [] }
        return context.applyBlock(
            context.companionModifiers.triggers.onAllyBurnDamageGainBlock,
            to: context.roster.companion.combatant,
            source: context.roster.companion.combatant,
            abilityName: triggerAbilityName(
                "onAllyBurnDamageGainBlock",
                for: context.roster.companion.combatant,
                fallback: "Ember Shield",
                in: context
            )
        )
    }

    // swiftlint:disable:next function_body_length
    static func afterCriticalHit(
        to enemy: Combatant,
        source: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard source.role != .enemy else { return [] }
        let profile = context.modifiers(for: source.id)
        var events = applyPurge(
            to: enemy,
            source: source,
            abilityName: affixName(.unmaking),
            count: profile.triggers.criticalPurgeCount,
            purgeAll: profile.triggers.criticalPurgeAll,
            in: &context
        )

        if profile.triggers.criticalGoldFlat > 0 {
            events.append(contentsOf: context.grantGoldEvent(
                profile.triggers.criticalGoldFlat,
                to: source,
                abilityName: triggerAbilityName("criticalGoldFlat", for: source, fallback: "Cutpurse", in: context)
            ))
        }

        if profile.triggers.criticalActionGoldFlat > 0,
           context.criticalGoldActionByActorID[source.id] != context.actionCount {
            events.append(contentsOf: context.grantGoldEvent(
                profile.triggers.criticalActionGoldFlat,
                to: source,
                abilityName: triggerAbilityName("criticalActionGoldFlat", for: source, fallback: "Lucky Clover", in: context)
            ))
            context.criticalGoldActionByActorID[source.id] = context.actionCount
        }

        if profile.triggers.criticalApplyPoison > 0, context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison,
                potency: profile.triggers.criticalApplyPoison,
                to: enemy,
                sourceActorID: source.id,
                dealImmediateDamage: false,
                suppressAffixReactions: true
            ))
        }
        if profile.triggers.criticalApplyBurn > 0, context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .burn,
                potency: profile.triggers.criticalApplyBurn,
                to: enemy,
                sourceActorID: source.id,
                dealImmediateDamage: false,
                suppressAffixReactions: true
            ))
        }
        if profile.triggers.criticalApplyStunBuildup > 0, context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                profile.triggers.criticalApplyStunBuildup,
                keyword: .stun,
                to: enemy,
                sourceActorID: source.id,
                applyFightPacing: false,
                in: &context
            ))
        }
        // Exsanguinate: critical hits on Bleeding targets trigger all remaining Bleed ticks.
        if profile.triggers.criticalOnBleedingDetonateBleed, context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: detonateBleed(on: enemy, sourceActorID: source.id, in: &context))
        }
        if profile.triggers.criticalDetonateBleedAndPoison, context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: detonateBleedAndPoison(
                on: enemy,
                sourceActorID: source.id,
                in: &context
            ))
        }
        // Rend Flesh: critical hits double the duration of active Bleed effects (capped at 10 turns).
        if profile.triggers.onCritDoubleBleedDuration {
            var effects = context.roster.activeEffects(for: enemy)
            for index in effects.indices where effects[index].effect.isBleed {
                effects[index].remainingTurns = min(10, effects[index].remainingTurns * 2)
            }
            context.roster.setActiveEffects(effects, for: enemy)
        }
        // Confounding Loot: critical hits against Stunned enemies drop Gold.
        if profile.triggers.criticalVsStunnedEnemyGold > 0,
           context.roster.hasControlStatus(for: enemy, keyword: .stun) {
            events.append(contentsOf: context.grantGoldEvent(
                profile.triggers.criticalVsStunnedEnemyGold,
                to: source,
                abilityName: triggerAbilityName("criticalVsStunnedEnemyGold", for: source, fallback: "Confounding Loot", in: context)
            ))
        }

        return events
    }

    /// Resolves every remaining Bleed tick on `target` immediately (Exsanguinate / Cauterize).
    static func detonateBleed(
        on target: Combatant,
        sourceActorID: String,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard !context.isResolvingDoTDetonation else { return [] }
        context.isResolvingDoTDetonation = true
        defer { context.isResolvingDoTDetonation = false }

        var events: [ActionEvent] = []
        let currentEffects = context.roster.activeEffects(for: target)
        var bleedsToDetonate: [(potency: Int, turns: Int)] = []
        for effect in currentEffects {
            if case let .bleed(potency) = effect.effect, effect.remainingTurns > 0 {
                bleedsToDetonate.append((potency, effect.remainingTurns))
            }
        }
        guard !bleedsToDetonate.isEmpty else { return [] }
        var remainingEffects = currentEffects
        remainingEffects.removeAll {
            if case .bleed = $0.effect {
                return true
            }
            return false
        }
        context.roster.setActiveEffects(remainingEffects, for: target)

        for (potency, turns) in bleedsToDetonate {
            for _ in 0 ..< turns {
                guard context.roster.health(for: target) > 0 else { break }
                events.append(contentsOf: DoTDamage.resolveTurnDamage(
                    basePotency: potency,
                    keyword: .bleed,
                    target: target,
                    sourceActorID: sourceActorID,
                    in: &context
                ).events)
            }
        }
        return events
    }
}

package extension CombatTriggerEngine {
    /// Companion reflex: when the Hero hits a Poisoned enemy, the Companion spits extra Poison.
    static func companionSpitPoison(
        to target: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard let companionTriggers = companionReactingToHeroTriggers(in: context),
              companionTriggers.onHeroAttackPoisonedEnemyApplyPoison > 0
        else { return [] }
        return context.applyDecayingDoT(
            keyword: .poison,
            potency: companionTriggers.onHeroAttackPoisonedEnemyApplyPoison,
            to: target,
            sourceActorID: context.roster.companion.id,
            dealImmediateDamage: false,
            suppressAffixReactions: true
        )
    }
}
