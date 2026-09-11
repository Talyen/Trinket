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
        let ownerRuntime = context.roster[card.owner]
        let removed: BattleCard? = if allowBufferedRemoval {
            context.hand.removeFromAnyLocation(id: card.id)
        } else {
            context.hand.remove(id: card.id)
        }
        guard removed != nil else {
            throw BattlePlayError.cardNotInHand
        }
        return resolvePlayedCard(card, ownerRuntime: ownerRuntime, context: &context)
    }

    static func resolvePlayedCard(
        _ card: BattleCard,
        ownerRuntime: CombatantRuntime,
        context: inout BattleState,
    ) -> [ActionEvent] {
        let actor = ownerRuntime.combatant
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
        return events
    }
}
