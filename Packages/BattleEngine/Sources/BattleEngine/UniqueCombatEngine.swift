import TrinketContent
import TrinketCore

package enum UniqueCombatEngine {
    static func isOrdinaryAction(actorID: String, in context: BattleState) -> Bool {
        context.uniques.ordinaryActionActorID == actorID
            && !context.isResolvingAutoPlayCard
            && context.drawAndPlayDepth == 0
            && context.uniques.reactionDepth == 0
    }

    static func prepareCard(_ card: BattleCard, in context: inout BattleState) -> UniqueBattleState.CardPlay? {
        guard !context.isResolvingAutoPlayCard, context.drawAndPlayDepth == 0,
              context.uniques.reactionDepth == 0 else { return nil }
        let actor = context.roster[card.owner].combatant
        let triggers = context.modifiers(for: actor.id).triggers
        var owner = context.uniques.owners[card.owner, default: .init()]
        owner.cardsPlayed += 1
        var play = UniqueBattleState.CardPlay(
            owner: card.owner,
            originalAbility: card.ability,
            targetWasBleeding: context.roster.hasAffliction(.bleed, on: context.roster.enemy.combatant),
        )
        if triggers.thirdCardReturnsToHand, owner.cardsPlayed == 3 {
            play.returnName = "The Returning Gale"
        }
        if triggers.secondCardDrawAndDodgePercent > 0, owner.cardsPlayed == 2 {
            owner.wrenflightDodge = triggers.secondCardDrawAndDodgePercent
            play.draws.append("Wrenflight")
        }
        if triggers.firstElementCardsDraw {
            for keyword in [Keyword.burn, .freeze, .holy]
                where card.ability.keywords.contains(keyword) && owner.usedElements.insert(keyword).inserted {
                play.draws.append("Threefold Grace")
            }
        }
        if triggers.dodgeDrawPoisonAndReadyCritical,
           owner.wildheartReady, card.ability.keywords.contains(.poison) {
            play.guaranteedCritical = true
            owner.wildheartReady = false
        }
        context.uniques.owners[card.owner] = owner
        return play
    }

    static func prepareResolvedAttack(_ ability: Ability, actor: Combatant, in context: inout BattleState) {
        guard isOrdinaryAction(actorID: actor.id, in: context), var play = context.uniques.card,
              ability.damageComponents.contains(where: { $0.target != .actor }) else { return }
        let triggers = context.modifiers(for: actor.id).triggers
        var owner = context.uniques.owners[play.owner, default: .init()]
        play.attackBonus = owner.heldCardDamage
        owner.heldCardDamage = 0
        if triggers.recoverLastAttackCardEachTurn {
            owner.lastAttack = play.originalAbility
        }
        if triggers.returnAttackAgainstBleedingOncePerTurn, !owner.returnedHarvest, play.targetWasBleeding {
            owner.returnedHarvest = true
            play.returnName = play.returnName ?? "Red Harvest"
        }
        context.uniques.owners[play.owner] = owner
        context.uniques.card = play
    }

    static func finishCardDraws(in context: inout BattleState) -> [ActionEvent] {
        guard let play = context.uniques.card else { return [] }
        let actor = context.roster[play.owner].combatant
        var events: [ActionEvent] = []
        for name in play.draws where !context.isBattleOver {
            events.append(contentsOf: CombatTriggerEngine.drawCards(
                1,
                for: play.owner,
                actor: actor,
                abilityName: name,
                in: &context,
            ))
        }
        return events
    }

    static func returnPlayedCard(_ card: BattleCard, in context: inout BattleState) -> ActionEvent? {
        guard let name = context.uniques.card?.returnName,
              !context.isBattleOver,
              BattleCardCombatEngine.canDrawFromDeck(for: card.owner, in: context)
        else { return nil }
        _ = BattleCardCombatEngine.deal(card.ability, owner: card.owner, context: &context)
        return cardReturnEvent(owner: card.owner, name: name, in: &context)
    }

    static func captureHeldCards(in context: inout BattleState) {
        for owner in [BattleParticipant.hero, .companion] {
            let actor = context.roster[owner]
            let perCard = context.modifiers(for: actor.id).triggers.heldCardNextAttackDamage
            let held = (context.hand.cards + context.hand.buffer).count { $0.owner == owner }
            context.uniques.owners[owner, default: .init()].heldCardDamage = actor.isAlive ? perCard * held : 0
        }
    }

    static func startTurn(in context: inout BattleState) -> [ActionEvent] {
        let activeIDs = Set(BattleParticipant.allCases.flatMap { context.roster[$0].activeEffects.map(\.id) })
        context.uniques.retainedStunByEffectID = context.uniques.retainedStunByEffectID.filter { activeIDs.contains($0.key) }
        var events: [ActionEvent] = []
        for owner in [BattleParticipant.hero, .companion] {
            let lastAttack = context.uniques.owners[owner]?.lastAttack
            context.uniques.owners[owner, default: .init()].resetTurn()
            guard let lastAttack,
                  BattleCardCombatEngine.canDrawFromDeck(for: owner, in: context),
                  !(context.hand.cards + context.hand.buffer).contains(where: {
                      $0.owner == owner && $0.ability.id == lastAttack.id
                  })
            else { continue }
            let recovered: Ability? = switch owner {
            case .hero: context.heroDeck.drawFirst { $0.id == lastAttack.id }
            case .companion: context.companionDeck.drawFirst { $0.id == lastAttack.id }
            case .enemy: nil
            }
            guard let recovered else { continue }
            _ = BattleCardCombatEngine.deal(recovered, owner: owner, context: &context)
            events.append(cardReturnEvent(owner: owner, name: "The Returning Flight", in: &context))
        }
        return events
    }

    private static func cardReturnEvent(
        owner: BattleParticipant,
        name: String,
        in context: inout BattleState,
    ) -> ActionEvent {
        let actor = context.roster[owner].combatant
        return context.nextEvent(
            kind: .effect,
            effectKind: .cardsDrawn,
            actorName: actor.name,
            abilityName: name,
            target: actor,
            amount: 1,
            keyword: .physical,
        )
    }
}
