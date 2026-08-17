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

    private static func hasAffliction(
        _ keyword: Keyword,
        on combatant: Combatant,
        in context: BattleState
    ) -> Bool {
        context.roster.activeEffects(for: combatant).contains { $0.effect.keyword == keyword }
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
        let targetIsFrozen = context.roster.hasControlStatus(for: target, keyword: .freeze)
        let targetIsStunned = context.roster.hasControlStatus(for: target, keyword: .stun)
        let targetIsBurning = hasAffliction(.burn, on: target, in: context)
        let targetIsPoisoned = hasAffliction(.poison, on: target, in: context)
        let targetIsBleeding = hasAffliction(.bleed, on: target, in: context)
        let sourceHasBlock = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: source.combatant)) > 0
        var bonus = 0

        if damageKeyword == .freeze, targetIsBurning {
            bonus += triggers.freezeDamageWhileBurningBonus
        }
        // Shatter is an aura: the enemy takes extra damage from party hits while Frozen.
        if source.role != .enemy, targetIsFrozen {
            bonus += context.partyTriggers.damageWhileTargetFrozenBonus
        }
        // Dazed is an aura: the enemy takes extra damage from party hits while Stunned.
        if source.role != .enemy, targetIsStunned {
            bonus += context.partyTriggers.damageWhileTargetStunnedBonus
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
        if targetIsBleeding {
            bonus += triggers.damageVsBleedingBonus
            bonus += triggers.damageVsBleedingFlat
        }
        // Combustion: attacks against Burning enemies deal bonus damage per Burn potency.
        if targetIsBurning, triggers.damagePerBurnPotencyPercent > 0 {
            bonus += CombatRounding.scaled(
                totalPotency(of: .burn, on: target, in: context),
                multiplier: triggers.damagePerBurnPotencyPercent
            )
        }
        bonus += partyAuraDamageBonus(
            for: state,
            source: source,
            damageKeyword: damageKeyword,
            targetIsPoisoned: targetIsPoisoned,
            targetIsBurning: targetIsBurning,
            in: context
        )
        if damageKeyword == .holy, targetIsStunned {
            bonus += triggers.holyDamageVsStunnedBonus
        }
        if damageKeyword == .burn, targetIsFrozen {
            bonus += triggers.burnDamageVsFrozenBonusPhysical
        }
        if damageKeyword == .freeze, targetIsFrozen {
            bonus += triggers.frostDamageVsFrozenBonus
        }
        if damageKeyword == .burn, context.maxMana(of: target) == 0 {
            bonus += triggers.burnDamageVsNoManaBonus
        }
        if sourceHasBlock {
            bonus += triggers.shieldDamageBonusWhileBlocked
        }
        if context.roster.maxHealth(for: source.combatant) > 0,
           context.roster.health(for: target) < context.roster.health(for: source.combatant) {
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
            bonus += context.gold / triggers.goldReservesDamageEvery
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
        let targetIsFrozen = context.roster.hasControlStatus(for: target, keyword: .freeze)
        let targetIsStunned = context.roster.hasControlStatus(for: target, keyword: .stun)
        let targetIsBurning = hasAffliction(.burn, on: target, in: context)
        let targetIsPoisoned = hasAffliction(.poison, on: target, in: context)
        let targetIsBleeding = hasAffliction(.bleed, on: target, in: context)
        let targetHasBlock = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: target)) > 0
        let targetBelowPoisonThreshold = triggers.poisonDamageBelowHealthThreshold > 0
            && context.roster.maxHealth(for: target) > 0
            && Double(context.roster.health(for: target)) / Double(context.roster.maxHealth(for: target))
            < triggers.poisonDamageBelowHealthThreshold

        var multiplier = 1.0
        if source.role != .enemy {
            multiplier *= partyAfflictedDamageMultiplier(
                targetIsPoisoned: targetIsPoisoned,
                targetIsBurning: targetIsBurning,
                in: context
            )
        } else {
            if targetIsPoisoned {
                multiplier *= triggers.damageVsPoisonedMultiplier
            }
            if targetIsBurning {
                multiplier *= triggers.damageVsBurningMultiplier
            }
        }
        if targetIsFrozen {
            multiplier *= triggers.damageVsFrozenMultiplier
        }
        if damageKeyword == .holy {
            if targetIsStunned || targetIsBurning {
                multiplier *= triggers.holyDamageVsStunnedOrBurningMultiplier
            }
            if targetIsPoisoned || targetIsBleeding {
                multiplier *= triggers.holyDamageVsPoisonedOrBleedingMultiplier
            }
            if context.enemyFaction == .undead || context.enemyFaction == .corrupted {
                multiplier *= triggers.holyDamageVsUndeadOrCorruptedMultiplier
            }
        }
        if damageKeyword == .burn, !targetHasBlock {
            multiplier *= triggers.burnDamageVsNoBlockMultiplier
        }
        if damageKeyword == .physical, targetIsBleeding {
            multiplier *= triggers.physicalDamageVsBleedingMultiplier
        }
        if source.role == .hero, targetIsStunned {
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
            abilityName: traitName(for: source, fallback: .oathbound, in: context)
        )
    }

    static func afterBurnDamageDealt(
        to _: Combatant,
        source: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let triggers = context.modifiers(for: source.id).triggers
        var events: [ActionEvent] = []
        if triggers.burnDamageHealFlat > 0 {
            events.append(contentsOf: HealingEngine.resolveHeal(
                HealRequest(
                    amount: triggers.burnDamageHealFlat,
                    target: source,
                    sourceActorID: source.id,
                    logAs: .instantHeal(
                        actorName: source.name,
                        abilityName: traitName(for: source, fallback: .bloodfire, in: context),
                        keyword: .health,
                        displayAmount: triggers.burnDamageHealFlat
                    )
                ),
                in: &context
            ).events)
        }
        if triggers.onBurnDamageHealLowestAllyFlat > 0 {
            let lowest = BattleConditionEvaluator.lowestHealthAlly(
                hero: context.roster.hero.combatant,
                companion: context.roster.companion.combatant,
                context: context
            )
            events.append(contentsOf: HealingEngine.resolveHeal(
                HealRequest(
                    amount: triggers.onBurnDamageHealLowestAllyFlat,
                    target: lowest,
                    sourceActorID: source.id,
                    logAs: .instantHeal(
                        actorName: source.name,
                        abilityName: traitName(for: source, fallback: .healingFlames, in: context),
                        keyword: .health,
                        displayAmount: triggers.onBurnDamageHealLowestAllyFlat
                    )
                ),
                in: &context
            ).events)
        }
        // Flame Shield: dealing Burn damage grants the owner 1 Block.
        if triggers.onBurnDamageGainBlock > 0 {
            events.append(contentsOf: context.applyBlock(
                triggers.onBurnDamageGainBlock,
                to: source,
                source: source,
                abilityName: traitName(for: source, fallback: .flameShield, in: context)
            ))
        }
        // Ember Shield: when an ally deals Burn damage, the Moth gains Block.
        if source.role != .enemy,
           context.roster.companion.isAlive,
           source.id != context.roster.companion.id,
           context.companionModifiers.triggers.onAllyBurnDamageGainBlock > 0 {
            events.append(contentsOf: context.applyBlock(
                context.companionModifiers.triggers.onAllyBurnDamageGainBlock,
                to: context.roster.companion.combatant,
                source: context.roster.companion.combatant,
                abilityName: traitName(for: context.roster.companion.combatant, fallback: .emberShield, in: context)
            ))
        }
        return events
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
                abilityName: traitName(for: source, fallback: .cutpurse, in: context)
            ))
        }

        if profile.triggers.criticalActionGoldFlat > 0,
           context.criticalGoldActionByActorID[source.id] != context.actionCount {
            events.append(contentsOf: context.grantGoldEvent(
                profile.triggers.criticalActionGoldFlat,
                to: source,
                abilityName: traitName(for: source, fallback: .luckyClover, in: context)
            ))
            context.criticalGoldActionByActorID[source.id] = context.actionCount
        }

        // Combatant Talent System crit reactions.
        if profile.triggers.criticalBlockFlat > 0 {
            events.append(contentsOf: context.applyBlock(
                profile.triggers.criticalBlockFlat,
                to: source,
                source: source,
                abilityName: traitName(for: source, fallback: .payoff, in: context)
            ))
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
                abilityName: traitName(for: source, fallback: .confoundingLoot, in: context)
            ))
        }

        return events
    }

    /// Resolves up to 3 remaining Bleed ticks on `target` immediately (Exsanguinate / Cauterize).
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

        var totalTicksDetonated = 0
        let maxTicks = 3
        for (potency, turns) in bleedsToDetonate {
            for _ in 0 ..< turns {
                guard totalTicksDetonated < maxTicks else { break }
                totalTicksDetonated += 1
                events.append(contentsOf: DoTDamage.resolveTurnDamage(
                    basePotency: potency,
                    keyword: .bleed,
                    target: target,
                    sourceActorID: sourceActorID,
                    in: &context
                ).events)
            }
            if totalTicksDetonated >= maxTicks {
                break
            }
        }
        return events
    }
}
