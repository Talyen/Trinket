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
            if triggers.onDodgePartyNextCardDamageBonus > 0 {
                runtime.pendingCardDamageBonus += triggers.onDodgePartyNextCardDamageBonus
            }
            if triggers.critMultiplierPerDodge > 0 {
                runtime.talentCritMultiplierBonus = min(
                    1.0,
                    runtime.talentCritMultiplierBonus + triggers.critMultiplierPerDodge
                )
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

        if triggers.onDodgePartyBlock > 0 || triggers.onDodgePartyMana > 0 {
            for owner in [BattleParticipant.hero, .companion] {
                let member = context.roster[owner]
                guard member.isAlive else { continue }
                if triggers.onDodgePartyBlock > 0 {
                    events.append(contentsOf: context.applyBlock(
                        triggers.onDodgePartyBlock,
                        to: member.combatant,
                        source: combatant,
                        abilityName: "Dodge"
                    ))
                }
                if triggers.onDodgePartyMana > 0 {
                    let restored = context.restoreMana(triggers.onDodgePartyMana, to: member.combatant)
                    if restored > 0 {
                        events.append(context.nextEvent(
                            kind: .effect,
                            effectKind: .resourceGain,
                            actorName: member.name,
                            abilityName: "Dodge",
                            target: member.combatant,
                            amount: restored,
                            keyword: .mana
                        ))
                        events.append(contentsOf: Self.afterGainMana(by: member.combatant, in: &context))
                    }
                }
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
                            isRetaliation: true
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
                                isRetaliation: true
                            )
                        )
                    ).events)
                }
            }
            if triggers.onDodgeApplyPoisonOrBleed > 0 {
                if Bool.random(using: &context.rng) {
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
            events.append(contentsOf: stealManaOnDodge(
                triggers: triggers,
                combatant: combatant,
                target: target,
                in: &context
            ))
        }

        return events
    }

    /// Steal Mana from the attacker and grant it to the dodger.
    private static func stealManaOnDodge(
        triggers: CombatTraitTriggers,
        combatant: Combatant,
        target: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard triggers.onDodgeStealMana > 0, (context.roster.runtime(for: target)?.maxMana ?? 0) > 0 else {
            return []
        }
        let stolen = context.spendMana(triggers.onDodgeStealMana, for: target)
        guard stolen > 0 else { return [] }
        var events = [
            context.nextEvent(
                kind: .effect,
                effectKind: .resourceGain,
                actorName: combatant.name,
                abilityName: "Dodge",
                target: target,
                amount: -stolen,
                keyword: .mana
            ),
        ]
        let gained = context.restoreMana(stolen, to: combatant)
        if gained > 0 {
            events.append(context.nextEvent(
                kind: .effect,
                effectKind: .resourceGain,
                actorName: combatant.name,
                abilityName: "Dodge",
                target: combatant,
                amount: gained,
                keyword: .mana
            ))
        }
        return events
    }

    static func afterBlockBroken(
        on target: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: target.id)
        guard profile.triggers.blockBrokenBlockFlat > 0 else { return [] }

        return context.applyBlock(
            profile.triggers.blockBrokenBlockFlat,
            to: target,
            source: target,
            abilityName: affixName(.cascading)
        )
    }

    static func afterEnemyStunned(in context: inout BattleState) -> [ActionEvent] {
        let profile = context.heroModifiers
        let shouldReact = profile.triggers.stunDealPhysicalFlat > 0
            || profile.triggers.enemyStunnedApplyMarked
            || profile.triggers.enemyStunnedPurgeCount > 0
            || profile.triggers.enemyStunnedPurgeAll
        guard shouldReact, context.roster.hero.isAlive else { return [] }

        let hero = context.roster.hero.combatant
        let enemy = context.roster.enemy.combatant
        guard context.roster.health(for: enemy) > 0 else { return [] }

        var events = DoTDamage.resolveTurnDamage(
            basePotency: profile.triggers.stunDealPhysicalFlat,
            keyword: .physical,
            target: enemy,
            sourceActorID: hero.id,
            in: &context
        ).events

        if profile.triggers.enemyStunnedApplyMarked, context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: applyMarked(
                to: enemy,
                sourceActorID: hero.id,
                actorName: hero.name,
                abilityName: affixName(.branding),
                in: &context
            ))
        }

        if context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: applyPurge(
                to: enemy,
                source: hero,
                abilityName: affixName(.disrupting),
                count: profile.triggers.enemyStunnedPurgeCount,
                purgeAll: profile.triggers.enemyStunnedPurgeAll,
                in: &context
            ))
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
        if profile.triggers.onceBelowHealthPercentStunAllEnemies,
           profile.triggers.onceBelowHealthPercentThreshold > 0,
           context.roster.maxHealth(for: target) > 0,
           context.roster.runtime(for: target)?.hasTriggeredSeismicRoar != true,
           context.roster.enemy.isAlive {
            let percent = Double(context.roster.health(for: target)) /
                Double(context.roster.maxHealth(for: target))
            if percent < profile.triggers.onceBelowHealthPercentThreshold {
                context.roster.mutateRuntime(for: target) { $0.hasTriggeredSeismicRoar = true }
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
        events.append(contentsOf: HealingEngine.resolveHeal(
            HealRequest(
                amount: profile.triggers.onceBelowHealthPercentHeal,
                target: target,
                sourceActorID: target.id,
                logAs: .instantHeal(
                    actorName: target.name,
                    abilityName: affixName(.secondWind),
                    keyword: .health,
                    displayAmount: profile.triggers.onceBelowHealthPercentHeal
                )
            ),
            in: &context
        ).events)
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
                effect: .marked(Effect.standardMarkedBonus, Effect.standardMarkedDuration),
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

    private static func applySidestepHeal(
        for combatant: Combatant,
        profile: CombatModifierProfile,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard profile.triggers.dodgeHealFlat > 0 else { return [] }
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: profile.triggers.dodgeHealFlat,
                target: combatant,
                sourceActorID: combatant.id,
                logAs: .instantHeal(
                    actorName: combatant.name,
                    abilityName: affixName(.sidestep),
                    keyword: .health,
                    displayAmount: profile.triggers.dodgeHealFlat
                )
            ),
            in: &context
        ).events
    }

    private static func applyWhiplashStun(
        for combatant: Combatant,
        profile: CombatModifierProfile,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard profile.triggers.dodgeDealStunFlat > 0, context.roster.enemy.isAlive else { return [] }
        // Avoid nesting a full damage pipeline inside DodgeGate (stack overflow in
        // long balance sims). Apply authored Stun damage as a direct health hit.
        let enemy = context.roster.enemy.combatant
        let amount = profile.triggers.dodgeDealStunFlat
        let lost = context.roster.runtime(for: enemy).map { runtime -> Int in
            var copy = runtime
            let dealt = copy.takeRawDamage(amount)
            context.roster.update(copy)
            return dealt
        } ?? 0
        guard lost > 0 else { return [] }
        return [context.nextEvent(
            kind: .effect,
            effectKind: nil,
            actorName: combatant.name,
            abilityName: affixName(.whiplash),
            target: enemy,
            amount: lost,
            keyword: .stun
        )]
    }
}
