import TrinketContent
import TrinketCore

extension UniqueCombatEngine {
    static func repeatCardDamage(actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard isOrdinaryAction(actorID: actor.id, in: context),
              let play = context.uniques.card, play.repeatDamage
        else { return [] }
        context.uniques.card?.repeatDamage = false
        context.resolution.enter(.uniqueReaction)
        defer { context.resolution.leave(.uniqueReaction) }
        var events: [ActionEvent] = []
        for var request in play.damageRequests where !context.isBattleOver && context.roster.health(for: actor) > 0 {
            request.options = request.options.repeated()
            request.provenance = nil
            events.append(contentsOf: repeatHit(request, actor: actor, name: "The Final Spark", in: &context))
            if request.options.isAttackHit, let keyword = request.keyword {
                events.append(contentsOf: BattleTurnEngine.applyDoTStackFromDamage(
                    keyword: keyword,
                    potency: request.amount,
                    to: request.target,
                    sourceActorID: actor.id,
                    context: &context,
                ))
            }
        }
        return events
    }

    static func afterDamage(_ damage: DamageResolutionState, in context: inout BattleState) -> [ActionEvent] {
        guard context.resolution.depth(.uniqueReaction) == 0 else { return [] }
        var events = answerBlockedAttack(damage, in: &context)
        events.append(contentsOf: huntBleedFollowUp(damage, in: &context))
        guard damage.options.isOrdinaryUniqueCardDamage,
              damage.amount > 0,
              damage.combatant.role == .enemy,
              let source = damage.partySource(in: context), source.isAlive,
              let owner = context.roster.participant(for: source.combatant)
        else { return events }
        let triggers = context.modifiers(for: source.id).triggers
        context.resolution.enter(.uniqueReaction)
        defer { context.resolution.leave(.uniqueReaction) }
        if damage.healthLost > 0, context.uniques.owners[owner]?.viperReady == true {
            context.uniques.owners[owner]?.viperReady = false
            let potency = CombatRounding.scaled(damage.healthLost, multiplier: triggers.dodgeNextHitPoisonAndBleedPercent)
            for keyword in [Keyword.poison, .bleed] where !context.isBattleOver {
                events.append(contentsOf: CombatTriggerEngine.applyDoT(
                    keyword: keyword,
                    potency: potency,
                    to: damage.combatant,
                    sourceActorID: source.id,
                    in: &context,
                ))
            }
        }
        guard damage.isCritical, damage.damageKeyword == .physical else { return events }
        if triggers.firstCriticalHitRepeatsPerTurn, context.uniques.owners[owner]?.repeatedCritical != true {
            context.uniques.owners[owner, default: .init()].repeatedCritical = true
            let options = damage.options.repeated(origin: .criticalRepeat, scaling: .resolved, guaranteedCritical: true)
            events.append(contentsOf: repeatHit(
                DamageRequest(
                    amount: damage.uniqueOutgoingDamage,
                    target: damage.combatant,
                    keyword: damage.damageKeyword,
                    sourceActorID: source.id,
                    options: options,
                ),
                actor: source.combatant,
                name: "Everkeen",
                in: &context,
            ))
        }
        return events
    }

    private static func huntBleedFollowUp(
        _ damage: DamageResolutionState,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard damage.damageKeyword == .bleed,
              damage.healthLost > 0,
              damage.combatant.role == .enemy,
              let source = damage.partySource(in: context), source.isAlive,
              let owner = context.roster.participant(for: source.combatant),
              context.modifiers(for: source.id).triggers.firstCriticalHitCompanionBasicPerTurn,
              context.uniques.owners[owner]?.calledCompanion != true
        else { return [] }
        context.uniques.owners[owner, default: .init()].calledCompanion = true
        // Defer while inside damage resolution: a full Basic nested in the
        // damage pipeline overflows small worker-thread stacks. The claim
        // above already spent the once-per-turn allowance; the outermost
        // damage drains the queue on completion.
        guard context.resolution.depth(.damage) == 0 else {
            context.uniques.pendingCompanionSummons += 1
            return []
        }
        context.resolution.enter(.uniqueReaction)
        defer { context.resolution.leave(.uniqueReaction) }
        return useBasic(owner: .companion, in: &context)
    }

    private static func answerBlockedAttack(
        _ damage: DamageResolutionState,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard damage.blockedAmount > 0, damage.options.isAttackHit,
              damage.sourceActorID == context.roster.enemy.id,
              let owner = context.roster.participant(for: damage.combatant), owner.isPartyMember,
              context.modifiers(for: damage.combatant.id).triggers.blockedAttackBasicOncePerTurn,
              context.uniques.owners[owner]?.answeredBlock != true
        else { return [] }
        context.uniques.owners[owner, default: .init()].answeredBlock = true
        // Same deferral as Huntsmaster's Call above: never nest a full Basic
        // inside damage resolution.
        guard context.resolution.depth(.damage) == 0 else {
            if !context.uniques.pendingBlockAnswerOwners.contains(owner) {
                context.uniques.pendingBlockAnswerOwners.append(owner)
            }
            return []
        }
        context.resolution.enter(.uniqueReaction)
        defer { context.resolution.leave(.uniqueReaction) }
        return useBasic(owner: owner, in: &context)
    }

    private static func useBasic(owner: BattleParticipant, in context: inout BattleState) -> [ActionEvent] {
        let actor = context.roster[owner].combatant
        guard !context.isBattleOver, context.roster[owner].isAlive,
              !context.ownersSkippingThisPlayerTurn.contains(owner),
              !context.roster.hasPendingActionSkip(for: actor),
              let ability = actor.abilityLoadout.basic,
              BattleAbilityRules.canPayHealthCost(ability, actor: actor, in: context)
        else { return [] }
        return BattleTurnEngine.performAction(
            ability: ability,
            actor: actor,
            abilityTarget: BattleTargetResolver.abilityTarget(for: actor, in: context),
            origin: .counterattack,
            context: &context,
        )
    }

    static func drainPendingSummons(in context: inout BattleState) -> [ActionEvent] {
        guard context.uniques.pendingCompanionSummons > 0 || !context.uniques.pendingBlockAnswerOwners.isEmpty else {
            return []
        }
        var events: [ActionEvent] = []
        // Drain in pipeline phase order: block answers were recorded before
        // companion summons within committed reactions.
        while !context.uniques.pendingBlockAnswerOwners.isEmpty {
            let owner = context.uniques.pendingBlockAnswerOwners.removeFirst()
            events.append(contentsOf: useBasic(owner: owner, in: &context))
        }
        while context.uniques.pendingCompanionSummons > 0 {
            context.uniques.pendingCompanionSummons -= 1
            events.append(contentsOf: useBasic(owner: .companion, in: &context))
        }
        return events
    }

    static func repeatHit(
        _ request: DamageRequest,
        actor: Combatant,
        name: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard !context.isBattleOver, context.roster.health(for: actor) > 0,
              context.roster.health(for: request.target) > 0 else { return [] }
        let result = context.resolveDamage(request)
        return result.events + [context.nextEvent(
            kind: .abilityDamage,
            actorID: actor.id,
            actorName: actor.name,
            abilityName: name,
            target: request.target,
            amount: result.healthLost,
            keyword: request.keyword ?? .physical,
            isCritical: result.isCritical,
        )]
    }

    static func afterUniqueDodge(
        by actor: Combatant,
        attackerID: String?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.resolution.depth(.uniqueReaction) == 0,
              let owner = context.roster.participant(for: actor), owner.isPartyMember,
              context.roster[owner].isAlive
        else { return [] }
        var events: [ActionEvent] = []
        events.append(contentsOf: galeDodgeReturn(by: actor, owner: owner, in: &context))
        let triggers = context.modifiers(for: actor.id).triggers
        if triggers.dodgeNextHitPoisonAndBleedPercent > 0 {
            context.uniques.owners[owner, default: .init()].viperReady = true
        }
        if triggers.dodgeDrawPoisonAndReadyCritical {
            context.uniques.owners[owner, default: .init()].wildheartReady = true
            if BattleCardCombatEngine.drawFirstCard(matching: .poison, for: owner, context: &context) != nil {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .cardsDrawn,
                    actorName: actor.name,
                    abilityName: "Wildheart’s Favor",
                    target: actor,
                    amount: 1,
                    keyword: .poison,
                ))
            }
        }
        guard triggers.dodgeSpendsHalfBlockAsPhysical else { return events }
        let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: actor))
        let spent = block / 2
        guard spent > 0 else { return events }
        DefensePoolEngine.set(block - spent, on: actor, in: &context)
        events.append(context.nextEvent(
            kind: .effect,
            effectKind: .shieldHalved,
            actorName: actor.name,
            abilityName: "Laughing Guard",
            target: actor,
            amount: spent,
            keyword: .block,
        ))
        guard let attackerID, let attacker = context.roster.combatant(for: attackerID), attacker.isAlive else { return events }
        context.resolution.enter(.uniqueReaction)
        defer { context.resolution.leave(.uniqueReaction) }
        events.append(contentsOf: repeatHit(
            DamageRequest(
                amount: spent,
                target: attacker.combatant,
                keyword: .physical,
                sourceActorID: actor.id,
                options: DamageOperation.reaction(cause: .dodge, scaling: .statsAndItems, accuracy: .normal),
            ),
            actor: actor,
            name: "Laughing Guard",
            in: &context,
        ))
        return events
    }

    private static func galeDodgeReturn(
        by actor: Combatant,
        owner: BattleParticipant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.modifiers(for: actor.id).triggers.thirdCardReturnsToHand,
              let tracked = context.uniques.owners[owner]?.lastOrdinaryAbility,
              !context.isBattleOver,
              BattleCardCombatEngine.canDrawFromDeck(for: owner, in: context)
        else { return [] }
        // Do nothing if already held or buffered, absent from the deck, or unavailable.
        if (context.hand.cards + context.hand.buffer).contains(where: {
            $0.owner == owner && $0.ability.id == tracked.id
        }) {
            return []
        }
        let recovered: Ability? = switch owner {
        case .hero:
            context.heroDeck.drawFirst { $0.id == tracked.id }
        case .companion:
            context.companionDeck.drawFirst { $0.id == tracked.id }
        case .enemy:
            nil
        }
        guard let recovered else { return [] }
        _ = BattleCardCombatEngine.deal(recovered, owner: owner, context: &context)
        return [context.nextEvent(
            kind: .effect,
            effectKind: .cardsDrawn,
            actorName: actor.name,
            abilityName: "The Returning Gale",
            target: actor,
            amount: 1,
            keyword: .dodge,
        )]
    }

    static func retainStun(
        _ buildup: Int,
        on target: Combatant,
        sourceActorID: String?,
        in context: inout BattleState,
    ) {
        guard target.role == .enemy, let sourceActorID,
              let effect = context.roster.activeEffects(for: target).first(where: {
                  $0.keyword == .stun && $0.effect.isActionSkipPending
              })
        else { return }
        let percent = context.modifiers(for: sourceActorID).triggers.stunRetainedBuildupPercent
        let retained = CombatRounding.scaled(buildup, multiplier: percent)
        if retained > 0 {
            context.uniques.retainedStunByEffectID[effect.id] = retained
        }
    }

    static func recoveredStun(_ active: ActiveEffect, in context: inout BattleState) -> ActiveEffect? {
        guard let retained = context.uniques.retainedStunByEffectID.removeValue(forKey: active.id),
              let values = active.effect.controlMeterValues
        else { return nil }
        var updated = active
        updated.effect = .controlMeter(.stun, retained, values.threshold)
        updated.remainingTurns = 0
        return updated
    }

    static func recoverStunBeforeClearing(on actor: Combatant, in context: inout BattleState) {
        var effects = context.roster.activeEffects(for: actor)
        for index in effects.indices {
            let active = effects[index]
            if active.effect.isActionSkipPending, !active.isAwaitingActionSkip,
               let restored = recoveredStun(active, in: &context) {
                effects[index] = restored
            }
        }
        context.roster.setActiveEffects(effects, for: actor)
    }

    static func afterEmpowermentSpend(
        _ payment: ManaPayment,
        in context: inout BattleState,
    ) {
        guard let actor = context.roster.combatant(for: payment.payerID)?.combatant else { return }
        let triggers = context.modifiers(for: actor.id).triggers
        if payment.spentLastMana,
           triggers.lastManaEmpowermentRepeatsDamage,
           isOrdinaryAction(actorID: actor.id, in: context),
           let owner = context.roster.participant(for: actor),
           context.uniques.owners[owner]?.usedFinalSpark != true {
            context.uniques.owners[owner, default: .init()].usedFinalSpark = true
            context.uniques.card?.repeatDamage = true
        }
    }
}
