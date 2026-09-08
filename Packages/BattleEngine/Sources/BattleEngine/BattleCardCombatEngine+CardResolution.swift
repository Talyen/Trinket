import TrinketContent
import TrinketCore

extension BattleCardCombatEngine {
    @discardableResult
    public static func playCard(
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
        let previousUniqueCard = context.uniques.card
        context.uniques.card = UniqueCombatEngine.prepareCard(card, in: &context)
        context.uniques.pendingOrdinaryActorID = context.uniques.card == nil ? nil : actor.id
        defer { context.uniques.card = previousUniqueCard }
        var facts = HeroTalentCardFacts(actorID: actor.id, tier: card.ability.tier)
        facts.playSerial = context.heroTalents.nextPlaySerial
        facts.previousDamageKeywords = context.heroTalents.history[actor.id]?.lastDamageKeywords ?? []
        context.heroTalents.nextPlaySerial += 1
        context.heroTalents.cards.append(facts)
        let abilityTarget = BattleTargetResolver.abilityTarget(for: actor, in: context)
        var events = BattleTurnEngine.performAction(
            ability: card.ability,
            actor: actor,
            abilityTarget: abilityTarget,
            context: &context,
        )
        events.append(contentsOf: CombatTriggerEngine.afterCardPlayed(
            ability: card.ability,
            by: actor,
            abilityTarget: abilityTarget,
            in: &context,
        ))
        events.append(contentsOf: CombatTriggerEngine.finishHeroCard(actor: actor, in: &context))
        events.append(contentsOf: UniqueCombatEngine.finishCardDraws(in: &context))
        if context.roster.runtime(for: actor)?.goldenTouchActiveThisCard == true {
            context.roster.mutateRuntime(for: actor) { $0.goldenTouchActiveThisCard = false }
        }
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
