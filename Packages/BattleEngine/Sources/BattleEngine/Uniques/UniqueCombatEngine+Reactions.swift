import TrinketContent
import TrinketCore

extension UniqueCombatEngine {
    static func repeatCardDamage(actor: Combatant, in context: inout BattleState) async {
        guard isOrdinaryAction(actorID: actor.id, in: context),
              let play = context.uniques.card, play.repeatDamage
        else { return }
        context.uniques.card?.repeatDamage = false
        context.resolution.enter(.uniqueReaction)
        defer { context.resolution.leave(.uniqueReaction) }

        for damage in play.damageRequests where !context.isBattleOver && context.roster.health(for: actor) > 0 {
            await repeatHit(
                damage.request, actor: actor, name: "The Final Spark",
                attachDoT: true, stackPotency: damage.stackPotency, in: &context,
            )
        }
    }

    static func afterDamage(_ damage: DamageResolutionState, in context: inout BattleState) async {
        guard context.resolution.depth(.uniqueReaction) == 0 else { return }
        answerBlockedAttack(damage, in: &context)
        await physicalCriticalRewards(damage, in: &context)
        guard damage.options.isOrdinaryUniqueCardDamage,
              damage.amount > 0,
              damage.combatant.role == .enemy,
              let source = damage.partySource(in: context), source.isAlive,
              let owner = context.roster.participant(for: source.combatant)
        else { return }
        let triggers = context.modifiers(for: source.id).triggers
        context.resolution.enter(.uniqueReaction)
        defer { context.resolution.leave(.uniqueReaction) }
        if damage.healthLost > 0, context.roster[owner].uniques.viperReady == true {
            context.roster[owner].uniques.viperReady = false
            let potency = CombatRounding.scaled(damage.healthLost, multiplier: triggers.dodgeNextHitPoisonAndBleedPercent)
            for keyword in [Keyword.poison, .bleed] where !context.isBattleOver {
                await DoTApplicator.applyDoT(
                    keyword: keyword,
                    potency: potency,
                    to: damage.combatant,
                    sourceActorID: source.id,
                    in: &context,
                )
            }
        }
        guard damage.isCritical, damage.damageKeyword == .physical else { return }
        if triggers.firstCriticalHitRepeatsPerTurn, context.roster[owner].uniques.repeatedCritical != true {
            context.roster[owner].uniques.repeatedCritical = true
            let options = damage.options.repeated(origin: .criticalRepeat, scaling: .resolved, guaranteedCritical: true)
            await repeatHit(
                DamageRequest(
                    amount: damage.unique.outgoingDamage,
                    target: damage.combatant,
                    keyword: damage.damageKeyword,
                    sourceActorID: source.id,
                    options: options,
                ),
                actor: source.combatant,
                name: "Everkeen",
                in: &context,
            )
        }
    }

    private static func physicalCriticalRewards(
        _ damage: DamageResolutionState,
        in context: inout BattleState,
    ) async {
        guard damage.damageKeyword == .physical,
              damage.isCritical,
              damage.options.isAttackHit,
              damage.healthLost > 0,
              damage.combatant.role == .enemy,
              let source = damage.partySource(in: context), source.isAlive,
              let owner = context.roster.participant(for: source.combatant)
        else { return }
        let triggers = context.modifiers(for: source.id).triggers

        if triggers.redHarvestPhysicalCriticalDetonatesBleed,
           context.roster.health(for: damage.combatant) > 0 {
            await CombatTriggerEngine.detonateBleed(on: damage.combatant, sourceActorID: source.id, in: &context)
        }
        if owner == .hero, triggers.huntsmasterPhysicalCriticalDrawsCompanion {
            CombatTriggerEngine.drawCards(
                1,
                for: .companion,
                actor: context.roster.companion.combatant,
                abilityName: "Huntsmaster’s Call",
                in: &context,
            )
        }
    }

    private static func answerBlockedAttack(
        _ damage: DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard damage.options.isAttackHit, damage.sourceActorID == context.roster.enemy.id else { return }

        for actor in damage.blockAbsorbingOwners {
            guard let owner = context.roster.participant(for: actor), owner.isPartyMember,
                  context.modifiers(for: actor.id).triggers.blockedAttackBasicOncePerTurn,
                  context.roster[owner].uniques.answeredBlock != true
            else { continue }
            context.roster[owner].uniques.answeredBlock = true
            // Never nest a full Basic inside damage resolution; CombatResolver drains queued answers after damage completes.
            if !context.uniques.pendingBlockAnswerOwners.contains(owner) {
                context.uniques.pendingBlockAnswerOwners.append(owner)
            }
        }
    }

    private static func useBasic(owner: BattleParticipant, in context: inout BattleState) async {
        let actor = context.roster[owner].combatant
        guard !context.isBattleOver, context.roster[owner].isAlive,
              !context.ownersSkippingThisPlayerTurn.contains(owner),
              !context.roster.hasPendingActionSkip(for: actor),
              let ability = actor.abilityLoadout.basic,
              BattleAbilityRules.canPayHealthCost(ability, actor: actor, in: context)
        else { return }
        await BattleTurnEngine.performAction(
            ability: ability,
            actor: actor,
            abilityTarget: BattleActionContext(actor: actor, in: context).selectedTarget,
            origin: .counterattack,
            context: &context,
        )
    }

    static func drainPendingBlockAnswers(in context: inout BattleState) async {
        while !context.uniques.pendingBlockAnswerOwners.isEmpty {
            let owner = context.uniques.pendingBlockAnswerOwners.removeFirst()
            await useBasic(owner: owner, in: &context)
        }
    }

    static func repeatHit(
        _ request: DamageRequest,
        actor: Combatant,
        name: String,
        attachDoT: Bool = false,
        stackPotency: Int? = nil,
        in context: inout BattleState,
    ) async {
        guard !context.isBattleOver, context.roster.health(for: actor) > 0,
              context.roster.health(for: request.target) > 0 else { return }
        let result = await context.resolveDamage(request)
        if result.isCritical {
            context.resolution.recordCardAttackCritical(by: actor.id)
        }
        context.nextEvent(
            kind: .abilityDamage,
            source: .init(actor),
            abilityName: name,
            target: request.target,
            amount: result.healthLost,
            keyword: request.keyword ?? .physical,
            isCritical: result.isCritical,
        )
        if attachDoT, request.options.isAttackHit, case .landed = result.damageImpact, let keyword = request.keyword {
            await BattleTurnEngine.applyDoTStackFromDamage(
                keyword: keyword,
                potency: keyword == .burn || keyword == .poison ? result.healthLost : (stackPotency ?? request.amount),
                to: request.target, sourceActorID: actor.id, isCritical: result.isCritical, context: &context,
            )
        }
    }

    static func afterUniqueDodge(
        by actor: Combatant,
        attackerID: String?,
        in context: inout BattleState,
    ) async {
        guard context.resolution.depth(.uniqueReaction) == 0,
              let owner = context.roster.participant(for: actor), owner.isPartyMember,
              context.roster[owner].isAlive
        else { return }

        galeDodgeReturn(by: actor, owner: owner, in: &context)
        let triggers = context.modifiers(for: actor.id).triggers
        if triggers.dodgeNextHitPoisonAndBleedPercent > 0 {
            context.roster[owner].uniques.viperReady = true
        }
        if triggers.dodgeDrawPoisonAndReadyCritical {
            context.roster[owner].uniques.wildheartReady = true
            if BattleCardCombatEngine.drawFirstCard(matching: .poison, for: owner, context: &context) != nil {
                context.nextEvent(
                    kind: .effect(.cardsDrawn),
                    source: .init(actor),
                    abilityName: "Wildheart’s Favor",
                    target: actor,
                    amount: 1,
                    keyword: .poison,
                )
            }
        }
        guard triggers.dodgeSpendsHalfBlockAsPhysical else { return }
        let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: actor))
        let spent = block / 2
        guard spent > 0 else { return }
        DefensePoolEngine.set(block - spent, on: actor, in: &context)
        context.nextEvent(
            kind: .effect(.shieldHalved),
            source: .init(actor),
            abilityName: "Laughing Guard",
            target: actor,
            amount: spent,
            keyword: .block,
        )
        guard let attackerID, let attacker = context.roster.combatant(for: attackerID), attacker.isAlive else { return }
        context.resolution.enter(.uniqueReaction)
        defer { context.resolution.leave(.uniqueReaction) }
        await repeatHit(
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
        )
    }

    private static func galeDodgeReturn(
        by actor: Combatant,
        owner: BattleParticipant,
        in context: inout BattleState,
    ) {
        guard context.modifiers(for: actor.id).triggers.thirdCardReturnsToHand,
              !context.roster[owner].uniques.returnedGaleThisTurn,
              let copyID = context.roster[owner].uniques.lastOrdinaryCopyID,
              !context.isBattleOver,
              BattleCardCombatEngine.canDrawFromDeck(for: owner, in: context)
        else { return }
        guard BattleCardCombatEngine.recoverCard(copyID: copyID, owner: owner, context: &context) != nil else { return }
        context.roster[owner].uniques.returnedGaleThisTurn = true
        context.nextEvent(
            kind: .effect(.cardsDrawn),
            source: .init(actor),
            abilityName: "The Returning Gale",
            target: actor,
            amount: 1,
            keyword: .dodge,
        )
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
        recoveredStun(active, retained: &context.uniques.retainedStunByEffectID)
    }

    static func recoverStunBeforeClearing(on actor: Combatant, in context: inout BattleState) {
        guard let participant = context.roster.participant(for: actor) else { return }
        recoverStunBeforeClearing(
            effects: &context.roster[participant].activeEffects,
            retained: &context.uniques.retainedStunByEffectID,
        )
    }

    private static func recoverStunBeforeClearing(effects: inout [ActiveEffect], retained: inout [Int: Int]) {
        for index in effects.indices {
            let active = effects[index]
            if active.effect.isActionSkipPending, !active.isAwaitingActionSkip,
               let restored = recoveredStun(active, retained: &retained) {
                effects[index] = restored
            }
        }
    }

    private static func recoveredStun(_ active: ActiveEffect, retained: inout [Int: Int]) -> ActiveEffect? {
        guard let amount = retained.removeValue(forKey: active.id),
              let values = active.effect.controlMeterValues else { return nil }
        var updated = active
        updated.effect = .controlMeter(.stun, amount, values.threshold)
        updated.remainingTurns = 0
        return updated
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
           context.roster[owner].uniques.usedFinalSpark != true {
            context.roster[owner].uniques.usedFinalSpark = true
            context.uniques.card?.repeatDamage = true
        }
    }
}
