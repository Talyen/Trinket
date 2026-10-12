import TrinketContent
import TrinketCore

extension BattleCardCombatEngine {
    @discardableResult
    package static func playCard(
        cardID: Int,
        context: inout BattleState,
    ) async throws -> [ActionEvent] {
        guard let card = context.hand.card(id: cardID) else { throw BattlePlayError.cardNotInHand }
        return try await playDrawnCard(card, context: &context, allowBufferedRemoval: false)
    }

    static func playDrawnCard(
        _ card: BattleCard,
        context: inout BattleState,
        allowBufferedRemoval: Bool = true,
    ) async throws -> [ActionEvent] {
        try await context.collectingEvents { context in
            await CombatExecutor.suspend()
            if let error = playError(for: card, in: context, allowsTurnPreparation: allowBufferedRemoval) {
                throw error
            }
            let actor = context.roster[card.owner].combatant
            guard context.hand.card(id: card.id) != nil
                || (allowBufferedRemoval && context.hand.buffer.contains(where: { $0.id == card.id })) else {
                throw BattlePlayError.cardNotInHand
            }
            // A caller supplying its own hand may skip the optional opening deal.
            // Only a manual command consumes it; automatic turn-start cards do not.
            if !allowBufferedRemoval {
                context.turnState = .playerTurn
            }
            if allowBufferedRemoval {
                _ = context.hand.removeFromAnyLocation(id: card.id)
            } else {
                _ = context.hand.remove(id: card.id)
            }
            discardPlayedCard(card, context: &context)
            context.commandOutput?.beginCard(card)
            await resolvePlayedCard(card, actor: actor, context: &context)
            context.commandOutput?.endCard()
        }
    }

    static func resolvePlayedCard(
        _ card: BattleCard,
        actor: Combatant,
        context: inout BattleState,
    ) async {
        let previousFeedbackGroup = context.resolution.beginFeedbackGroup(eventID: context.nextEventID + 1)
        defer { context.resolution.feedbackGroupID = previousFeedbackGroup }
        let previousUniqueCard = context.uniques.card
        context.uniques.card = UniqueCombatEngine.prepareCard(card, in: &context)
        defer { context.uniques.card = previousUniqueCard }
        let livingParty = [context.roster.hero, context.roster.companion].filter(\.isAlive).map(\.id)
        let partyDamageBonus = context.resolution.reservePartyCardDamage(livingSourceIDs: livingParty)
        let playSerial = context.resolution.beginCard(
            actorID: actor.id,
            partyDamageBonus: partyDamageBonus,
        )
        defer { context.resolution.endCard(playSerial) }
        let abilityTarget = BattleActionContext(actor: actor, in: context).selectedTarget
        _ = await BattleTurnEngine.performAction(
            ability: card.ability,
            actor: actor,
            abilityTarget: abilityTarget,
            origin: context.uniques.card == nil ? .card : .ordinaryCard,
            context: &context,
        )
        await finishPlayedCard(card, actor: actor, context: &context)
    }

    private static func finishPlayedCard(
        _ card: BattleCard,
        actor: Combatant,
        context: inout BattleState,
    ) async {
        if let outcome = context.resolution.cardOutcome(for: actor.id) {
            _ = await CombatTriggerEngine.afterCardPlayed(outcome, in: &context)
            _ = await CombatTriggerEngine.afterPartyCardPlayed(in: &context)
        }
        _ = CombatTriggerEngine.finishHeroCard(actor: actor, in: &context)
        _ = UniqueCombatEngine.finishCardDraws(in: &context)
        _ = UniqueCombatEngine.returnPlayedCard(card, in: &context)
        discardDefeatedOwnerCards(context: &context)
        promoteFromBuffer(context: &context)
        _ = await context.appendDefeatMilestonesIfNeeded()
        if context.isBattleOver {
            context.turnState = .ended
        }
    }
}
