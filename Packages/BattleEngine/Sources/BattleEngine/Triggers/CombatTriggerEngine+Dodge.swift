import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    // swiftlint:disable:next function_body_length cyclomatic_complexity - dodge triggers share one ordered cadence
    static func afterDodge(
        by combatant: Combatant,
        attackerID: String?,
        allowsCounterattacks: Bool = true,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: combatant.id)
        let triggers = profile.triggers
        var events: [ActionEvent] = []

        context.roster.mutateRuntime(for: combatant) { runtime in
            if triggers.damageAfterDodgeBonus > 0 {
                runtime.talents.pending.damageAfterDodge += triggers.damageAfterDodgeBonus
            }
            if triggers.nextAttackDoubleAfterDodge {
                runtime.talents.pending.doubleDamageAfterDodge = true
            }
            if triggers.onDodgeNextPartyHitGuaranteedCritical {
                runtime.talents.pending.guaranteedCriticalAfterDodge = true
            }
            if triggers.onDodgeNextAttackGuaranteedCritical {
                runtime.talents.pending.guaranteedCriticalAfterDodge = true
            }
            if triggers.nextAttackBleedAfterDodge > 0 {
                runtime.talents.pending.bleedAfterDodge = triggers.nextAttackBleedAfterDodge
            }
            if triggers.critMultiplierPerDodge > 0 {
                runtime.talents.battle.criticalMultiplierBonus = min(
                    1.0,
                    runtime.talents.battle.criticalMultiplierBonus + triggers.critMultiplierPerDodge,
                )
            }
        }
        if triggers.onDodgePartyNextCardDamageBonus > 0 {
            context.resolution.preparePartyCardDamage(triggers.onDodgePartyNextCardDamageBonus, sourceID: combatant.id)
        }
        if triggers.onCompanionDodgeGrantHeroDodgePercent > 0,
           combatant.id == context.roster.companion.id,
           context.roster.hero.isAlive {
            context.roster.mutateRuntime(for: context.roster.hero.combatant) {
                $0.talents.grantDodgeUntilNextTurn(triggers.onCompanionDodgeGrantHeroDodgePercent)
            }
        }

        if triggers.dodgeGoldFlat > 0 {
            events.append(contentsOf: emitGold(
                "dodgeGoldFlat", "Payday", amount: triggers.dodgeGoldFlat, to: combatant, in: &context,
            ))
        }

        if triggers.dodgeBlockFlat > 0 {
            events.append(contentsOf: emitBlock(
                "dodgeBlockFlat", "Untouchable",
                amount: triggers.dodgeBlockFlat, to: combatant, source: combatant, in: &context,
            ))
        }

        if triggers.onDodgeGrantHeroBlock > 0, context.roster.hero.isAlive {
            events.append(contentsOf: emitBlock(
                "onDodgeGrantHeroBlock", "Aerial Cover",
                amount: triggers.onDodgeGrantHeroBlock,
                to: context.roster.hero.combatant, source: combatant, in: &context,
            ))
        }

        if triggers.onDodgePartyMana > 0 {
            for (_, member) in livingPartyMembers(in: context) {
                events.append(contentsOf: emitMana(
                    "onDodgePartyMana", "Dodge",
                    amount: triggers.onDodgePartyMana, to: member.combatant, nameFrom: combatant, in: &context,
                ))
            }
        }

        if triggers.onDodgeDrawCardForHero > 0, context.roster.hero.isAlive {
            let drawn = BattleCardCombatEngine.drawCards(
                count: triggers.onDodgeDrawCardForHero,
                for: .hero,
                context: &context,
            )
            if drawn > 0 {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .cardsDrawn,
                    actorName: context.roster.hero.name,
                    abilityName: triggerAbilityName("onDodgeDrawCardForHero", for: combatant, fallback: "Tailwind", in: context),
                    target: context.roster.hero.combatant,
                    amount: drawn,
                    keyword: .physical,
                ))
            }
        }

        if allowsCounterattacks, triggers.onDodgeDrawAndPlayCardChainOnCrit {
            events.append(contentsOf: drawPlayCascade(for: combatant, in: &context))
        }

        events.append(contentsOf: applySidestepHeal(for: combatant, profile: profile, in: &context))
        if allowsCounterattacks, context.roster.enemy.isAlive {
            if triggers.dodgeBleedDamage > 0,
               BattleChance.succeeds(probability: triggers.dodgeBleedChancePercent, using: &context.rng) {
                events.append(contentsOf: applyDoT(
                    keyword: .bleed,
                    potency: triggers.dodgeBleedDamage,
                    to: context.roster.enemy.combatant,
                    sourceActorID: combatant.id,
                    in: &context,
                ))
            }
            if triggers.dodgeBurnDamage > 0,
               BattleChance.succeeds(probability: triggers.dodgeBurnChancePercent, using: &context.rng) {
                events.append(contentsOf: applyDoT(
                    keyword: .burn,
                    potency: triggers.dodgeBurnDamage,
                    to: context.roster.enemy.combatant,
                    sourceActorID: combatant.id,
                    in: &context,
                ))
            }
        }
        if allowsCounterattacks {
            events.append(contentsOf: applyDodgeCounterDamage(
                keyword: .stun,
                amount: profile.triggers.dodgeDealStunFlat,
                key: "dodgeDealStunFlat",
                fallback: "Whiplash",
                for: combatant,
                in: &context,
            ))
            events.append(contentsOf: applyDodgeCounterDamage(
                keyword: .freeze,
                amount: profile.triggers.dodgeDealFreezeFlat,
                key: "dodgeDealFreezeFlat",
                fallback: "Wing Buffet",
                for: combatant,
                in: &context,
            ))
        }

        if triggers.dodgeApplyPoison > 0, context.roster.enemy.isAlive {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison,
                potency: triggers.dodgeApplyPoison,
                to: context.roster.enemy.combatant,
                sourceActorID: combatant.id,
                application: .ability,
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

            if allowsCounterattacks, triggers.onDodgeCounterDamage > 0 {
                events.append(contentsOf: context.resolveDamage(
                    DamageRequest(
                        amount: triggers.onDodgeCounterDamage,
                        target: target,
                        keyword: .physical,
                        sourceActorID: combatant.id,
                        options: .reaction(),
                    ),
                ).events)
            }
            if allowsCounterattacks, triggers.onDodgeCounterBasicAttack {
                events.append(contentsOf: counterWithBasicAttack(by: combatant, in: &context))
            }
            if triggers.onDodgeApplyPoisonOrBleed > 0 {
                if BattleChance.succeeds(probability: 0.5, using: &context.rng) {
                    events.append(contentsOf: context.applyDecayingDoT(
                        keyword: .poison,
                        potency: triggers.onDodgeApplyPoisonOrBleed,
                        to: target,
                        sourceActorID: combatant.id,
                        application: .reaction,
                    ))
                } else {
                    events.append(contentsOf: DoTApplicator.applyBleed(
                        potency: triggers.onDodgeApplyPoisonOrBleed,
                        to: target,
                        sourceActorID: combatant.id,
                        application: .reaction,
                        in: &context,
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
                    in: &context,
                ))
            }
        }

        if allowsCounterattacks, triggers.phantomCounter,
           context.resolution.depth(.damage) < ReactionScope.maxDepth,
           context.resolution.depth(.dot) < ReactionScope.maxDepth,
           context.resolution.depth(.draw) < BattleState.maxDrawAndPlayDepth,
           !context.resolution.isAutomaticPlay,
           let owner = context.roster.participant(for: combatant),
           let card = BattleCardCombatEngine.drawFirstCard(matching: .physical, for: owner, context: &context) {
            context.resolution.enter(.damage)
            context.resolution.enter(.dot)
            context.resolution.enter(.draw)
            defer {
                context.resolution.leave(.damage)
                context.resolution.leave(.dot)
                context.resolution.leave(.draw)
            }
            events.append(contentsOf: context.withAutomaticPlay { context in
                (try? BattleCardCombatEngine.playDrawnCard(card, context: &context)) ?? []
            })
        }

        events.append(contentsOf: afterCompanionDodge(by: combatant, in: &context))
        events.append(contentsOf: afterFinalCompanionDodge(by: combatant, in: &context))
        return events
    }

    private static func counterWithBasicAttack(
        by actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard !context.isBattleOver, context.roster.health(for: actor) > 0,
              let owner = context.roster.participant(for: actor),
              !context.ownersSkippingThisPlayerTurn.contains(owner),
              !context.roster.hasPendingActionSkip(for: actor),
              let ability = actor.abilityLoadout.basic,
              BattleAbilityRules.canPayHealthCost(ability, actor: actor, in: context)
        else { return [] }
        // Defer while inside damage resolution, like UniqueCombatEngine's
        // out-of-turn summons: a full Basic nested in the damage pipeline
        // overflows small worker-thread stacks.
        guard context.resolution.depth(.damage) == 0 else {
            context.uniques.pendingCounterAttackActorIDs.append(actor.id)
            return []
        }
        return BattleTurnEngine.performAction(
            ability: ability,
            actor: actor,
            abilityTarget: BattleTargetResolver.abilityTarget(for: actor, in: context),
            origin: .counterattack,
            context: &context,
        )
    }

    static func drainPendingCounterAttacks(in context: inout BattleState) -> [ActionEvent] {
        guard !context.uniques.pendingCounterAttackActorIDs.isEmpty else { return [] }
        var events: [ActionEvent] = []
        while !context.uniques.pendingCounterAttackActorIDs.isEmpty {
            let actorID = context.uniques.pendingCounterAttackActorIDs.removeFirst()
            guard let actor = context.roster.combatant(for: actorID)?.combatant else { continue }
            events.append(contentsOf: counterWithBasicAttack(by: actor, in: &context))
        }
        return events
    }

    private static func drawPlayCascade(
        for combatant: Combatant,
        in context: inout BattleState,
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
                in: &context,
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
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard profile.triggers.dodgeHealFlat > 0 else { return [] }
        let target = BattleTargetResolver.lowestHealthAlly(for: combatant, in: context)
        return emitHeal(
            "dodgeHealFlat", "Sidestep",
            amount: profile.triggers.dodgeHealFlat, to: target, source: combatant, in: &context,
        )
    }

    private static func applyDodgeCounterDamage(
        keyword: Keyword,
        amount: Int,
        key: String,
        fallback: String,
        for combatant: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard amount > 0, context.roster.enemy.isAlive else { return [] }
        let enemy = context.roster.enemy.combatant
        let name = triggerAbilityName(key, for: combatant, fallback: fallback, in: context)
        let outcome = context.resolveDamage(
            DamageRequest(
                amount: amount,
                target: enemy,
                keyword: keyword,
                sourceActorID: combatant.id,
                options: .reaction(cause: .dodge, accuracy: .normal),
            ),
        )
        var events = outcome.events.map { event in
            event.keyword == keyword ? event.with(abilityName: name) : event
        }
        if outcome.healthLost > 0, !events.contains(where: { $0.abilityName == name }) {
            events.append(context.nextEvent(
                kind: .effect,
                actorName: combatant.name,
                abilityName: name,
                target: enemy,
                amount: outcome.healthLost,
                keyword: keyword,
            ))
        }
        return events
    }
}
