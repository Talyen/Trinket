import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    static func afterDodge(
        by combatant: Combatant,
        attackerID: String?,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: combatant.id)
        let triggers = profile.triggers
        var events: [ActionEvent] = []

        context.roster.mutateRuntime(for: combatant) { runtime in
            if triggers.damageAfterDodgeBonus > 0 {
                runtime.pendingDamageAfterDodge += triggers.damageAfterDodgeBonus
            }
            if triggers.nextAttackDoubleAfterDodge {
                runtime.pendingDamageDoubleAfterDodge = true
            }
            if triggers.onDodgeNextPartyHitGuaranteedCritical {
                runtime.pendingGuaranteedCriticalAfterDodge = true
            }
            if triggers.nextAttackBleedAfterDodge > 0 {
                runtime.pendingBleedAfterDodge = triggers.nextAttackBleedAfterDodge
            }
            if triggers.critMultiplierPerDodge > 0 {
                runtime.talentCritMultiplierBonus = min(1.0, runtime.talentCritMultiplierBonus + triggers.critMultiplierPerDodge)
            }
        }
        if triggers.onDodgePartyNextCardDamageBonus > 0 {
            for owner in [BattleParticipant.hero, .companion] {
                let member = context.roster[owner]
                guard member.isAlive else { continue }
                context.roster.mutateRuntime(for: member.combatant) {
                    $0.pendingCardDamageBonus += triggers.onDodgePartyNextCardDamageBonus
                }
            }
        }
        if triggers.onCompanionDodgeGrantHeroDodgePercent > 0,
           combatant.id == context.roster.companion.id,
           context.roster.hero.isAlive {
            context.roster.mutateRuntime(for: context.roster.hero.combatant) {
                $0.bonusDodgeUntilNextTurn += triggers.onCompanionDodgeGrantHeroDodgePercent
            }
        }

        if triggers.dodgeGoldFlat > 0 {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.dodgeGoldFlat,
                to: combatant,
                abilityName: affixName(.payday)
            ))
        }

        if triggers.dodgeBlockFlat > 0 {
            events.append(contentsOf: context.applyBlock(
                triggers.dodgeBlockFlat,
                to: combatant,
                source: combatant,
                abilityName: affixName(.untouchable)
            ))
        }

        if triggers.onDodgeGrantHeroBlock > 0, context.roster.hero.isAlive {
            events.append(contentsOf: context.applyBlock(
                triggers.onDodgeGrantHeroBlock,
                to: context.roster.hero.combatant,
                source: combatant,
                abilityName: "Aerial Cover"
            ))
        }

        if triggers.onDodgePartyMana > 0 {
            for owner in [BattleParticipant.hero, .companion] {
                let member = context.roster[owner]
                guard member.isAlive else { continue }
                events.append(contentsOf: context.restoreManaEmitting(
                    triggers.onDodgePartyMana,
                    to: member.combatant,
                    abilityName: "Dodge"
                ))
            }
        }

        if triggers.onDodgeDrawCardForHero > 0, context.roster.hero.isAlive {
            let drawn = BattleCardCombatEngine.drawCards(
                count: triggers.onDodgeDrawCardForHero,
                for: .hero,
                context: &context
            )
            if drawn > 0 {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .cardsDrawn,
                    actorName: context.roster.hero.name,
                    abilityName: "Tailwind",
                    target: context.roster.hero.combatant,
                    amount: drawn,
                    keyword: .physical
                ))
            }
        }

        if triggers.onDodgeDrawAndPlayCardChainOnCrit {
            events.append(contentsOf: drawPlayCascade(for: combatant, in: &context))
        }

        events.append(contentsOf: applySidestepHeal(for: combatant, profile: profile, in: &context))
        events.append(contentsOf: applyWhiplashStun(for: combatant, profile: profile, in: &context))

        if triggers.dodgeApplyPoison > 0, context.roster.enemy.isAlive {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison,
                potency: triggers.dodgeApplyPoison,
                to: context.roster.enemy.combatant,
                sourceActorID: combatant.id,
                dealImmediateDamage: true
            ))
        }

        if triggers.onDodgeDelayAttackerTurn, let attackerID,
           let attacker = context.roster.combatant(for: attackerID),
           attacker.role == .enemy {
            context.additionalControlSkipsByCombatantID[attackerID, default: 0] += 1
        }

        if let attackerID, let attackerRuntime = context.roster.combatant(for: attackerID) {
            let target = attackerRuntime.combatant
            guard context.roster.health(for: target) > 0 else { return events }

            if triggers.onDodgeCounterDamage > 0 {
                events.append(contentsOf: context.resolveDamage(
                    DamageRequest(
                        amount: triggers.onDodgeCounterDamage,
                        target: target,
                        keyword: .physical,
                        sourceActorID: combatant.id,
                        options: DamageOptions(
                            applyStatBonus: false,
                            applyItemBonus: false,
                            applyDodge: false,
                            isRetaliation: true,
                            causedByDodge: true
                        )
                    )
                ).events)
            }
            if triggers.onDodgeCounterBasicAttack {
                let basicAmount = combatant.abilityLoadout.basic?.damageComponents.first?.amount ?? 0
                if basicAmount > 0 {
                    events.append(contentsOf: context.resolveDamage(
                        DamageRequest(
                            amount: basicAmount,
                            target: target,
                            keyword: .physical,
                            sourceActorID: combatant.id,
                            options: DamageOptions(
                                applyStatBonus: false,
                                applyItemBonus: false,
                                applyDodge: false,
                                isRetaliation: true,
                                causedByDodge: true
                            )
                        )
                    ).events)
                }
            }
            if triggers.onDodgeApplyPoisonOrBleed > 0 {
                if BattleChance.succeeds(probability: 0.5, using: &context.rng) {
                    events.append(contentsOf: context.applyDecayingDoT(
                        keyword: .poison,
                        potency: triggers.onDodgeApplyPoisonOrBleed,
                        to: target,
                        sourceActorID: combatant.id,
                        dealImmediateDamage: false,
                        suppressAffixReactions: true
                    ))
                } else {
                    events.append(contentsOf: DoTApplicator.applyBleed(
                        potency: triggers.onDodgeApplyPoisonOrBleed,
                        to: target,
                        sourceActorID: combatant.id,
                        dealImmediateDamage: false,
                        suppressAffixReactions: true,
                        in: &context
                    ))
                }
            }
            if triggers.onDodgeAttackerStunBuildup > 0 {
                events.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                    triggers.onDodgeAttackerStunBuildup,
                    keyword: .stun,
                    to: target,
                    sourceActorID: combatant.id,
                    applyFightPacing: false,
                    in: &context
                ))
            }
        }

        return events
    }

    static func afterBlockBroken(
        on target: Combatant,
        attackerID: String?,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: target.id)
        var events: [ActionEvent] = []
        if profile.triggers.blockBrokenBlockFlat > 0 {
            events.append(contentsOf: context.applyBlock(
                profile.triggers.blockBrokenBlockFlat,
                to: target,
                source: target,
                abilityName: affixName(.cascading)
            ))
        }

        events.append(contentsOf: saintfallAfterBlockBroken(
            on: target,
            attackerID: attackerID,
            power: profile.triggers.blockBrokenSaintfallPower,
            in: &context
        ))
        return events
    }

    static func afterEnemyStunned(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for owner in [BattleParticipant.hero, .companion] {
            events.append(contentsOf: afterEnemyStunnedReactions(for: owner, in: &context))
        }
        return events
    }

    private static func afterEnemyStunnedReactions(
        for owner: BattleParticipant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let runtime = context.roster[owner]
        guard runtime.isAlive else { return [] }
        let profile = context.modifiers(for: runtime.id)
        let triggers = profile.triggers
        let shouldReact = triggers.stunDealPhysicalFlat > 0
            || triggers.enemyStunnedApplyMarked
            || triggers.enemyStunnedPurgeCount > 0
            || triggers.enemyStunnedPurgeAll
            || triggers.stunPurgeDealHolyPerEffect > 0
        guard shouldReact else { return [] }

        let actor = runtime.combatant
        let enemy = context.roster.enemy.combatant
        guard context.roster.health(for: enemy) > 0 else { return [] }

        var events: [ActionEvent] = []
        if triggers.stunDealPhysicalFlat > 0 {
            events.append(contentsOf: DoTDamage.resolveTurnDamage(
                basePotency: triggers.stunDealPhysicalFlat,
                keyword: .physical,
                target: enemy,
                sourceActorID: actor.id,
                in: &context
            ).events)
        }

        if triggers.enemyStunnedApplyMarked, context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: applyMarked(
                to: enemy,
                sourceActorID: actor.id,
                actorName: actor.name,
                abilityName: affixName(.branding),
                in: &context
            ))
        }

        if context.roster.health(for: enemy) > 0 {
            if triggers.stunPurgeDealHolyPerEffect > 0 {
                events.append(contentsOf: wardbreakerStunPurge(
                    perEffectHolyDamage: triggers.stunPurgeDealHolyPerEffect,
                    actor: actor,
                    enemy: enemy,
                    in: &context
                ))
            } else {
                events.append(contentsOf: applyPurge(
                    to: enemy,
                    source: actor,
                    abilityName: affixName(.disrupting),
                    count: triggers.enemyStunnedPurgeCount,
                    purgeAll: triggers.enemyStunnedPurgeAll,
                    in: &context
                ))
            }
        }
        return events
    }

    /// Wardbreaker purges every beneficial effect and deals Holy damage for each.
    private static func wardbreakerStunPurge(
        perEffectHolyDamage: Int,
        actor: Combatant,
        enemy: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let removableCount = context.roster.activeEffects(for: enemy)
            .filter(\.effect.isRemovableBuff)
            .count
        var events = applyPurge(
            to: enemy,
            source: actor,
            abilityName: affixName(.disrupting),
            count: 0,
            purgeAll: true,
            in: &context
        )
        if removableCount > 0, context.roster.health(for: enemy) > 0 {
            // Trigger-dealt Holy matches its burn-tick sibling: flat, no stat/item scaling.
            events.append(contentsOf: context.resolveDamage(
                DamageRequest(
                    amount: perEffectHolyDamage * removableCount,
                    target: enemy,
                    keyword: .holy,
                    sourceActorID: actor.id,
                    options: DamageOptions(
                        applyStatBonus: false,
                        applyItemBonus: false,
                        applyDodge: false,
                        isRetaliation: true
                    )
                )
            ).events)
        }
        return events
    }

    static func afterHealthDropped(
        target: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: target.id)
        var events = drawAfterHealthLoss(by: target, in: &context)
        // Seismic Roar: the Companion stuns the enemy once when dropping below half Health.
        let belowHalfThreshold = profile.triggers.onceBelowHealthPercentThreshold > 0
            && context.roster.maxHealth(for: target) > 0
            && Double(context.roster.health(for: target)) / Double(context.roster.maxHealth(for: target))
            < profile.triggers.onceBelowHealthPercentThreshold
        if profile.triggers.onceBelowHealthPercentStunAllEnemies,
           belowHalfThreshold,
           context.roster.enemy.isAlive,
           context.claimBattleGuard(.seismicRoar, actorID: target.id) {
            let threshold = ControlMeterEngine.threshold(for: context.roster.enemy.combatant, in: context)
            events.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                threshold,
                keyword: .stun,
                to: context.roster.enemy.combatant,
                sourceActorID: target.id,
                applyFightPacing: false,
                in: &context
            ))
        }
        guard profile.triggers.onceBelowHealthPercentThreshold > 0,
              profile.triggers.onceBelowHealthPercentHeal > 0,
              context.roster.maxHealth(for: target) > 0,
              let runtime = context.roster.runtime(for: target),
              !runtime.hasTriggeredSecondWind
        else { return events }

        // Death's Door owns lethal hits; Second Wind must not preempt it.
        let deathsDoorOwnsLethalHit = DeathsDoorEngine.applies(to: target)
            && context.roster.health(for: target) == 0
            && (!context.roster.hasConsumedDeathsDoor(for: target)
                || DeathsDoorEngine.hasLethalProtection(for: target, in: context))
        if deathsDoorOwnsLethalHit {
            return events
        }

        let percent = Double(context.roster.health(for: target)) / Double(context.roster.maxHealth(for: target))
        guard percent < profile.triggers.onceBelowHealthPercentThreshold else { return events }
        context.roster.mutateRuntime(for: target) { $0.hasTriggeredSecondWind = true }
        events.append(contentsOf: context.healEmitting(
            amount: profile.triggers.onceBelowHealthPercentHeal,
            target: target,
            source: target,
            abilityName: affixName(.secondWind)
        ))
        return events
    }

    static func applyPurge(
        to target: Combatant,
        source: Combatant,
        abilityName: String,
        count: Int,
        purgeAll: Bool,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard purgeAll || count > 0 else { return [] }
        var enemyEffects = context.roster.activeEffects(for: target)
        let removedKeywords = EffectRemoval.removeBuffs(
            from: &enemyEffects,
            count: count,
            removeAll: purgeAll,
            using: &context.rng
        )
        guard !removedKeywords.isEmpty else { return [] }
        context.roster.setActiveEffects(enemyEffects, for: target)
        return removedKeywords.map { keyword in
            context.nextEvent(
                kind: .effect,
                effectKind: .purgeApplied,
                actorName: source.name,
                abilityName: abilityName,
                target: target,
                amount: 0,
                keyword: keyword
            )
        }
    }

    private static func applyMarked(
        to target: Combatant,
        sourceActorID: String,
        actorName: String,
        abilityName: String,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let markedEffect = Effect.marked(Effect.standardMarkedBonus, Effect.standardMarkedDuration)
        guard !context.interceptDebuff(markedEffect, on: target) else { return [] }
        var effects = context.roster.activeEffects(for: target)
        effects.removeAll {
            if case .marked = $0.effect {
                return true
            }
            return false
        }
        effects.append(
            ActiveEffect(
                id: context.consumeNextEffectID(),
                effect: markedEffect,
                remainingTurns: Effect.standardMarkedDuration,
                sourceActorID: sourceActorID
            )
        )
        context.roster.setActiveEffects(effects, for: target)
        return [context.nextEvent(
            kind: .effect,
            effectKind: .markedApplied,
            actorName: actorName,
            abilityName: abilityName,
            target: target,
            amount: Effect.standardMarkedBonus,
            keyword: .physical
        )]
    }

    /// Dance of Blades: Dodging draws and automatically plays a card; a critical
    /// play repeats the effect, bounded by the shared auto-play depth cap.
    private static func drawPlayCascade(
        for combatant: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard context.roster.health(for: combatant) > 0 else { return [] }
        let cascadeAbility = combatant.abilityLoadout.basic
            ?? Ability(id: "dance-of-blades", name: "Dance of Blades", tier: .basic, directDamage: 0)
        var events: [ActionEvent] = []
        for _ in 0 ..< BattleState.maxDrawAndPlayDepth {
            let played = DrawAndPlayCardsHandler().apply(
                .drawAndPlayCards(1),
                ability: cascadeAbility,
                source: combatant,
                target: combatant,
                in: &context
            )
            guard played.didApply else { break }
            events.append(contentsOf: played.events)
            guard played.events.contains(where: \.isCritical) else { break }
        }
        return events
    }

    private static func applySidestepHeal(
        for combatant: Combatant,
        profile: CombatModifierProfile,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard profile.triggers.dodgeHealFlat > 0 else { return [] }
        return context.healEmitting(
            amount: profile.triggers.dodgeHealFlat,
            target: combatant,
            source: combatant,
            abilityName: affixName(.sidestep)
        )
    }

    private static func applyWhiplashStun(
        for combatant: Combatant,
        profile: CombatModifierProfile,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard profile.triggers.dodgeDealStunFlat > 0, context.roster.enemy.isAlive else { return [] }
        let enemy = context.roster.enemy.combatant
        let amount = profile.triggers.dodgeDealStunFlat
        let name = affixName(.whiplash)
        let outcome = context.resolveDamage(
            DamageRequest(
                amount: amount,
                target: enemy,
                keyword: .stun,
                sourceActorID: combatant.id,
                options: DamageOptions(
                    applyDodge: true,
                    isRetaliation: true,
                    applyControlMeter: true,
                    causedByDodge: true
                )
            )
        )
        var events = outcome.events.map { event in
            event.keyword == .stun ? event.with(abilityName: name) : event
        }
        if outcome.healthLost > 0, !events.contains(where: { $0.abilityName == name }) {
            events.append(context.nextEvent(
                kind: .effect,
                actorName: combatant.name,
                abilityName: name,
                target: enemy,
                amount: outcome.healthLost,
                keyword: .stun
            ))
        }
        return events
    }
}
