import TrinketContent
import TrinketCore

extension BattleCardCombatEngine {
    @discardableResult
    package static func playCard(
        cardID: Int,
        context: inout BattleState,
    ) throws -> [ActionEvent] {
        guard let card = context.hand.card(id: cardID) else { throw BattlePlayError.cardNotInHand }
        return try playDrawnCard(card, context: &context, allowBufferedRemoval: false)
    }

    static func playDrawnCard(
        _ card: BattleCard,
        context: inout BattleState,
        allowBufferedRemoval: Bool = true,
    ) throws -> [ActionEvent] {
        if let error = playError(for: card, in: context) {
            throw error
        }
        let actor = context.roster[card.owner].combatant
        guard context.hand.card(id: card.id) != nil
            || (allowBufferedRemoval && context.hand.buffer.contains(where: { $0.id == card.id })) else {
            throw BattlePlayError.cardNotInHand
        }
        context.recordCardPlay(.cardWillPlay(card))
        if allowBufferedRemoval {
            _ = context.hand.removeFromAnyLocation(id: card.id)
        } else {
            _ = context.hand.remove(id: card.id)
        }
        context.recordCardPlay(.cardPlayed(card))
        let events = resolvePlayedCard(card, actor: actor, context: &context)
        context.recordCardPlay(.cardActions(card))
        return events
    }

    static func resolvePlayedCard(
        _ card: BattleCard,
        actor: Combatant,
        context: inout BattleState,
    ) -> [ActionEvent] {
        let previousFeedbackGroup = context.resolution.beginFeedbackGroup(eventID: context.nextEventID + 1)
        defer { context.resolution.feedbackGroupID = previousFeedbackGroup }
        let previousUniqueCard = context.uniques.card
        context.uniques.card = UniqueCombatEngine.prepareCard(card, in: &context)
        defer { context.uniques.card = previousUniqueCard }
        let playSerial = context.resolution.beginCard(
            actorID: actor.id, tier: card.ability.tier,
            previousDamageKeywords: context.heroTalents.history[actor.id]?.lastDamageKeywords ?? [],
        )
        defer { context.resolution.endCard(playSerial) }
        let abilityTarget = BattleTargetResolver.abilityTarget(for: actor, in: context)
        var events = BattleTurnEngine.performAction(
            ability: card.ability,
            actor: actor,
            abilityTarget: abilityTarget,
            origin: context.uniques.card == nil ? .card : .ordinaryCard,
            context: &context,
        )
        finishPlayedCard(card, actor: actor, events: &events, context: &context)
        return events
    }

    private static func finishPlayedCard(
        _ card: BattleCard,
        actor: Combatant,
        events: inout [ActionEvent],
        context: inout BattleState,
    ) {
        if let outcome = context.resolution.cardOutcome(for: actor.id) {
            events.append(contentsOf: CombatTriggerEngine.afterCardPlayed(outcome, in: &context))
        }
        events.append(contentsOf: CombatTriggerEngine.finishHeroCard(actor: actor, in: &context))
        events.append(contentsOf: UniqueCombatEngine.finishCardDraws(in: &context))
        context.roster.mutateRuntime(for: actor) { $0.talents.finishCard() }
        if let returned = UniqueCombatEngine.returnPlayedCard(card, in: &context) {
            events.append(returned)
        } else {
            putAbilityOnBottom(card.ability, owner: card.owner, context: &context)
        }
        discardDefeatedOwnerCards(context: &context)
        promoteFromBuffer(context: &context)
        events.append(contentsOf: context.appendDefeatMilestonesIfNeeded())
        if context.isBattleOver {
            context.phase = .ended
        }
    }
}
