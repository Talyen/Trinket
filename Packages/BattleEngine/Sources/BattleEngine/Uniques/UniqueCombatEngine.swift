import TrinketContent
import TrinketCore

package enum UniqueCombatEngine {
    static func isOrdinaryAction(actorID: String, in context: BattleState) -> Bool {
        context.resolution.actionContext?.actor.id == actorID
            && context.resolution.attackOrigin == .ordinaryCard
            && !context.resolution.isAutomaticPlay
            && context.resolution.depth(.draw) == 0
            && context.resolution.depth(.uniqueReaction) == 0
    }

    static func prepareCard(_ card: BattleCard, in context: inout BattleState) -> UniqueBattleState.CardPlay? {
        guard !context.resolution.isAutomaticPlay, context.resolution.depth(.draw) == 0,
              context.resolution.depth(.uniqueReaction) == 0 else { return nil }
        let actor = context.roster[card.owner].combatant
        let triggers = context.modifiers(for: actor.id).triggers
        var owner = context.uniques.owners[card.owner, default: .init()]
        owner.cardsPlayed += 1
        let play = UniqueBattleState.CardPlay(
            owner: card.owner,
            originalAbility: card.ability,
            targetWasBleeding: context.roster.hasAffliction(.bleed, on: context.roster.enemy.combatant),
        )
        if triggers.secondCardDrawAndDodgePercent > 0, owner.cardsPlayed == 2 {
            owner.wrenflightDodge = triggers.secondCardDrawAndDodgePercent
            var mutablePlay = play
            mutablePlay.draws.append("Wrenflight")
            context.uniques.owners[card.owner] = owner
            return mutablePlay
        }
        context.uniques.owners[card.owner] = owner
        return play
    }

    static func prepareResolvedAttack(_ facts: ResolvedActionFacts, in context: inout BattleState) {
        let actor = facts.action.actor
        guard isOrdinaryAction(actorID: actor.id, in: context), var play = context.uniques.card else { return }
        let triggers = context.modifiers(for: actor.id).triggers
        var owner = context.uniques.owners[play.owner, default: .init()]
        defer {
            context.uniques.owners[play.owner] = owner
            context.uniques.card = play
        }
        // The Returning Gale tracks the last ordinary card play, including non-damaging cards.
        if triggers.thirdCardReturnsToHand {
            owner.lastOrdinaryAbility = play.originalAbility
        }
        if triggers.firstElementCardsDraw {
            for keyword in [Keyword.burn, .freeze, .holy]
                where facts.damageKeywords.contains(keyword) && owner.usedElements.insert(keyword).inserted {
                play.draws.append("Threefold Grace")
            }
        }
        if triggers.dodgeDrawPoisonAndReadyCritical,
           owner.wildheartReady, facts.damageKeywords.contains(.poison) {
            play.guaranteedCritical = true
            owner.wildheartReady = false
        }
        // The Returning Flight returns the first Physical card each turn.
        if triggers.recoverLastAttackCardEachTurn,
           !owner.returnedFlightThisTurn,
           facts.damageKeywords.contains(.physical) {
            owner.returnedFlightThisTurn = true
            play.returnName = play.returnName ?? "The Returning Flight"
        }
        guard !facts.damageKeywords.isEmpty else { return }
        let partner: BattleParticipant = play.owner == .hero ? .companion : .hero
        if !owner.hasAttacked, context.uniques.owners[partner, default: .init()].cardsPlayed > 0 {
            play.attackBonus = triggers.partnerFirstAttackDamage
        }
        owner.hasAttacked = true
        if triggers.returnAttackAgainstBleedingOncePerTurn, !owner.returnedHarvest, play.targetWasBleeding {
            owner.returnedHarvest = true
            play.returnName = play.returnName ?? "Red Harvest"
        }
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

    static func startTurn(in context: inout BattleState) -> [ActionEvent] {
        let activeIDs = Set(BattleParticipant.allCases.flatMap { context.roster[$0].activeEffects.map(\.id) })
        context.uniques.retainedStunByEffectID = context.uniques.retainedStunByEffectID.filter { activeIDs.contains($0.key) }
        for owner in [BattleParticipant.hero, .companion] {
            context.uniques.owners[owner, default: .init()].resetTurn()
        }
        return []
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
