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
                abilityName: triggerAbilityName("dodgeGoldFlat", for: combatant, fallback: "Payday", in: context)
            ))
        }

        if triggers.dodgeBlockFlat > 0 {
            events.append(contentsOf: context.applyBlock(
                triggers.dodgeBlockFlat,
                to: combatant,
                source: combatant,
                abilityName: triggerAbilityName("dodgeBlockFlat", for: combatant, fallback: "Untouchable", in: context)
            ))
        }

        if triggers.onDodgeGrantHeroBlock > 0, context.roster.hero.isAlive {
            events.append(contentsOf: context.applyBlock(
                triggers.onDodgeGrantHeroBlock,
                to: context.roster.hero.combatant,
                source: combatant,
                abilityName: triggerAbilityName("onDodgeGrantHeroBlock", for: combatant, fallback: "Aerial Cover", in: context)
            ))
        }

        if triggers.onDodgePartyMana > 0 {
            for owner in [BattleParticipant.hero, .companion] {
                let member = context.roster[owner]
                guard member.isAlive else { continue }
                events.append(contentsOf: context.restoreManaEmitting(
                    triggers.onDodgePartyMana,
                    to: member.combatant,
                    abilityName: triggerAbilityName("onDodgePartyMana", for: combatant, fallback: "Dodge", in: context)
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
                    abilityName: triggerAbilityName("onDodgeDrawCardForHero", for: combatant, fallback: "Tailwind", in: context),
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
                        options: .flatReaction
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
                            options: .flatReaction
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
            abilityName: triggerAbilityName("dodgeHealFlat", for: combatant, fallback: "Sidestep", in: context)
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
        let name = triggerAbilityName("dodgeDealStunFlat", for: combatant, fallback: "Whiplash", in: context)
        let outcome = context.resolveDamage(
            DamageRequest(
                amount: amount,
                target: enemy,
                keyword: .stun,
                sourceActorID: combatant.id,
                options: .dodgeTriggeredControlReaction
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
