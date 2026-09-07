import TrinketContent
import TrinketCore

extension UniqueCombatEngine {
    static func repeatCardDamage(actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard isOrdinaryAction(actorID: actor.id, in: context),
              let play = context.uniques.card, play.repeatDamage
        else { return [] }
        context.uniques.card?.repeatDamage = false
        context.uniques.reactionDepth += 1
        defer { context.uniques.reactionDepth -= 1 }
        var events: [ActionEvent] = []
        for var request in play.damageRequests where !context.isBattleOver && context.roster.health(for: actor) > 0 {
            request.options.isOriginalCardDamage = false
            request.options.isOrdinaryUniqueCardDamage = false
            request.options.applyControlMeter = true
            events.append(contentsOf: repeatHit(request, actor: actor, name: "The Final Spark", in: &context))
            if let keyword = request.keyword {
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
        guard context.uniques.reactionDepth == 0 else { return [] }
        var events = answerBlockedAttack(damage, in: &context)
        guard damage.options.isOrdinaryUniqueCardDamage,
              damage.healthLost > 0,
              damage.combatant.role == .enemy,
              let source = damage.partySource(in: context), source.isAlive,
              let owner = context.roster.participant(for: source.combatant)
        else { return events }
        let triggers = context.modifiers(for: source.id).triggers
        context.uniques.reactionDepth += 1
        defer { context.uniques.reactionDepth -= 1 }
        if context.uniques.owners[owner]?.viperReady == true {
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
        guard damage.isCritical else { return events }
        if triggers.firstCriticalHitRepeatsPerTurn, context.uniques.owners[owner]?.repeatedCritical != true {
            context.uniques.owners[owner, default: .init()].repeatedCritical = true
            var options = damage.options
            options.isOriginalCardDamage = false
            options.isOrdinaryUniqueCardDamage = false
            options.usesResolvedOutgoingDamage = true
            options.guaranteedCritical = true
            options.applyControlMeter = true
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
        if triggers.firstCriticalHitCompanionBasicPerTurn, context.uniques.owners[owner]?.calledCompanion != true {
            context.uniques.owners[owner, default: .init()].calledCompanion = true
            events.append(contentsOf: useBasic(owner: .companion, in: &context))
        }
        return events
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
        context.uniques.reactionDepth += 1
        defer { context.uniques.reactionDepth -= 1 }
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
        let wasAutoPlay = context.isResolvingAutoPlayCard
        context.isResolvingAutoPlayCard = true
        defer { context.isResolvingAutoPlayCard = wasAutoPlay }
        return BattleTurnEngine.performAction(
            ability: ability,
            actor: actor,
            abilityTarget: BattleTargetResolver.abilityTarget(for: actor, in: context),
            context: &context,
        )
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
}
