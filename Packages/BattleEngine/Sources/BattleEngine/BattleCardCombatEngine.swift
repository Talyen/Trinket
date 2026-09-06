import Foundation
import TrinketContent
import TrinketCore

public enum BattleCardCombatEngine {
    public static func bootstrapDecks(context: inout BattleState) {
        context.heroDeck = CombatDeck.shuffled(
            from: context.hero.abilityLoadout,
            rng: &context.rng,
        )
        context.companionDeck = CombatDeck.shuffled(
            from: context.companion.abilityLoadout,
            rng: &context.rng,
        )
        context.hand = BattleHand()
        context.openingHandDealPlan = makeOpeningHandDealPlan(in: context)
        context.phase = .playerTurn
        context.ownersSkippingThisPlayerTurn = []
    }

    public static func bootstrapDecksAndOpeningHand(context: inout BattleState) {
        bootstrapDecks(context: &context)
        drawOpeningHand(context: &context)
    }

    @discardableResult
    public static func drawOpeningHand(context: inout BattleState) -> [ActionEvent] {
        while drawNextOpeningHandCard(context: &context) {}
        return finalizeOpeningHand(context: &context)
    }

    @discardableResult
    public static func drawNextOpeningHandCard(context: inout BattleState) -> Bool {
        guard context.hand.count < BattleHand.maxSize else { return false }

        while !context.openingHandDealPlan.isEmpty {
            let slot = context.openingHandDealPlan.removeFirst()
            if dealCard(matching: slot.tier, owner: slot.owner, context: &context) != nil {
                return true
            }
        }

        let eligible = [BattleParticipant.hero, .companion].filter { owner in
            context.roster[owner].isAlive
                && !isDeckDrawBlocked(for: owner, in: context)
                && !deck(for: owner, in: context).isEmpty
        }
        guard !eligible.isEmpty else { return false }
        guard context.hand.count < BattleHand.maxSize else { return false }
        guard let owner = eligible.randomElement(using: &context.rng) else { return false }
        return drawOne(for: owner, context: &context) != nil
    }

    @discardableResult
    public static func finalizeOpeningHand(context: inout BattleState) -> [ActionEvent] {
        context.ownersSkippingThisPlayerTurn = skippingOwners(in: context)
        return CombatTriggerEngine.atPlayerTurnStart(in: &context)
    }

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
        guard !context.isBattleOver else { throw BattlePlayError.battleOver }
        guard context.phase == .playerTurn else { throw BattlePlayError.notPlayerTurn }
        let ownerRuntime = context.roster[card.owner]
        guard ownerRuntime.isAlive else { throw BattlePlayError.ownerDefeated }
        guard !context.ownersSkippingThisPlayerTurn.contains(card.owner) else {
            throw BattlePlayError.ownerSkipping
        }
        guard BattleAbilityRules.canPayHealthCost(card.ability, actor: ownerRuntime.combatant, in: context) else {
            throw BattlePlayError.insufficientHealth
        }
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

    private static func resolvePlayedCard(
        _ card: BattleCard,
        ownerRuntime: CombatantRuntime,
        context: inout BattleState,
    ) -> [ActionEvent] {
        let actor = ownerRuntime.combatant
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
        if context.roster.runtime(for: actor)?.goldenTouchActiveThisCard == true {
            context.roster.mutateRuntime(for: actor) { $0.goldenTouchActiveThisCard = false }
        }
        putAbilityOnBottom(card.ability, owner: card.owner, context: &context)
        discardDefeatedOwnerCards(context: &context)
        promoteFromBuffer(context: &context)
        events.append(contentsOf: context.appendDefeatMilestonesIfNeeded())
        if context.isBattleOver {
            context.phase = .ended
        }
        return events
    }

    @discardableResult
    public static func endTurn(
        context: inout BattleState,
    ) -> [ActionEvent] {
        guard !context.isBattleOver, context.phase == .playerTurn else {
            assertionFailure("BattleCardCombatEngine.endTurn called outside playerTurn or after battle ended")
            return []
        }

        var events = endTurnWithoutDraw(context: &context)
        if context.phase == .ended {
            return events
        }

        while drawNextTurnStartCard(context: &context) {}
        promoteFromBuffer(context: &context)
        events.append(contentsOf: finalizeTurnStart(context: &context))
        return events
    }

    static func restoreManaAtPlayerTurnStart(
        context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for owner in [BattleParticipant.hero, .companion] {
            let runtime = context.roster[owner]
            guard runtime.isAlive, runtime.maxMana > 0 else { continue }
            let combatant = runtime.combatant
            events.append(contentsOf: context.restoreManaEmitting(
                1,
                to: combatant,
                abilityName: Keyword.mana.rawValue,
            ))
        }
        return events
    }

    public static func isCardPlayable(_ card: BattleCard, in context: BattleState) -> Bool {
        guard context.phase == .playerTurn, !context.isBattleOver else { return false }
        let runtime = context.roster[card.owner]
        guard runtime.isAlive else { return false }
        return !context.ownersSkippingThisPlayerTurn.contains(card.owner)
            && BattleAbilityRules.canPayHealthCost(card.ability, actor: runtime.combatant, in: context)
    }

    @discardableResult
    public static func drawCards(
        count: Int,
        for owner: BattleParticipant,
        context: inout BattleState,
    ) -> Int {
        var drawn = 0
        for _ in 0 ..< count {
            if drawOne(for: owner, context: &context) != nil {
                drawn += 1
            } else {
                break
            }
        }
        return drawn
    }

    static func resolveEnemyTurn(
        context: inout BattleState,
    ) -> [ActionEvent] {
        let enemy = context.enemy
        guard context.roster.enemy.isAlive else { return [] }

        let bleed = CombatTriggerEngine.beforeEnemyActBleedReactions(in: &context)
        var leadingEvents = bleed.events
        if bleed.cancelled {
            return leadingEvents
        }

        if context.roster.hasPendingActionSkip(for: enemy) {
            return leadingEvents + BattleTurnEngine.consumeActionSkip(for: enemy, context: &context)
        }

        context.roster.clearControlStatusLinger(for: enemy)

        let avoidance = CombatTriggerEngine.enemyActAvoidance(in: &context)
        leadingEvents.append(contentsOf: avoidance.events)
        if avoidance.cancelled {
            return leadingEvents
        }

        let abilityTarget = BattleTargetResolver.abilityTarget(for: enemy, in: context)
        let turnNumber = context.roster.enemy.actionCount + 1
        guard let ability = BattleTurnEngine.selectedEnemyAbility(for: enemy, turnNumber: turnNumber) else {
            return leadingEvents
        }
        var events = BattleTurnEngine.performAction(
            ability: ability,
            actor: enemy,
            abilityTarget: abilityTarget,
            context: &context,
        )
        events.append(contentsOf: CombatTriggerEngine.afterEnemyAbility(in: &context))
        if context.roster.runtime(for: enemy)?.goldenTouchActiveThisCard == true {
            context.roster.mutateRuntime(for: enemy) { $0.goldenTouchActiveThisCard = false }
        }
        return leadingEvents + events
    }

    static func skippingOwners(in context: BattleState) -> Set<BattleParticipant> {
        var skipping: Set<BattleParticipant> = []
        for owner in [BattleParticipant.hero, .companion] {
            let combatant = context.roster[owner].combatant
            if context.roster[owner].isAlive, context.roster.hasPendingActionSkip(for: combatant) {
                skipping.insert(owner)
            }
        }
        return skipping
    }

    static func pickBalancedOwner(
        candidates: [BattleParticipant],
        isHandFull: Bool,
        tieWinner: BattleParticipant,
        heroHandCount: Int,
        companionHandCount: Int,
    ) -> BattleParticipant {
        if isHandFull {
            return candidates.contains(tieWinner) ? tieWinner : candidates[0]
        }
        if candidates.count == 1 {
            return candidates[0]
        }
        if heroHandCount == companionHandCount {
            return tieWinner
        }
        return heroHandCount < companionHandCount ? .hero : .companion
    }

    static func advanceRoundCommon(context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for owner in context.ownersSkippingThisPlayerTurn {
            let combatant = context.roster[owner].combatant
            if context.roster.hasPendingActionSkip(for: combatant) {
                events.append(contentsOf: BattleTurnEngine.consumeActionSkip(
                    for: combatant,
                    context: &context,
                ))
            }
        }
        context.ownersSkippingThisPlayerTurn = []

        if context.isBattleOver {
            events.append(contentsOf: context.appendDefeatMilestonesIfNeeded())
            context.phase = .ended
            return events
        }

        events.append(contentsOf: resolveEnemyTurn(context: &context))
        events.append(contentsOf: context.appendDefeatMilestonesIfNeeded())
        if context.isBattleOver {
            context.phase = .ended
            return events
        }

        events.append(contentsOf: CombatTriggerEngine.atPlayerEndTurn(in: &context))
        context.primedRepeatKeywords.removeAll()

        for participant in BattleParticipant.allCases {
            context.roster.mutateRuntime(for: context.roster[participant].combatant) { runtime in
                if let expiredAt = runtime.deathsDoorExpiredAtTurn, expiredAt != context.turnCount {
                    runtime.deathsDoorExpiredAtTurn = nil
                }
            }
        }
        context.turnCount += 1
        events.append(contentsOf: EffectTurnEngine.advanceAll(context: &context))
        for combatant in [context.roster.hero.combatant, context.roster.companion.combatant, context.roster.enemy.combatant] {
            DefensePoolEngine.decayBlockAtEndOfRound(on: combatant, in: &context)
        }
        events.append(contentsOf: context.appendDefeatMilestonesIfNeeded())
        if context.isBattleOver {
            context.phase = .ended
            return events
        }

        discardDefeatedOwnerCards(context: &context)
        return events
    }

    @discardableResult
    static func drawOne(for owner: BattleParticipant, context: inout BattleState) -> BattleCard? {
        guard canDrawFromDeck(for: owner, in: context) else { return nil }
        let ability: Ability? = switch owner {
        case .hero: context.heroDeck.draw()
        case .companion: context.companionDeck.draw()
        case .enemy: nil
        }
        guard let ability else { return nil }
        return deal(ability, owner: owner, context: &context)
    }

    static func drawFirstCard(
        matching keyword: Keyword,
        for owner: BattleParticipant,
        context: inout BattleState,
    ) -> BattleCard? {
        guard canDrawFromDeck(for: owner, in: context) else { return nil }
        let ability: Ability? = switch owner {
        case .hero: context.heroDeck.drawFirst(where: { $0.keywords.contains(keyword) })
        case .companion: context.companionDeck.drawFirst(where: { $0.keywords.contains(keyword) })
        case .enemy: nil
        }
        guard let ability else { return nil }
        return deal(ability, owner: owner, context: &context)
    }

    static func canDrawFromDeck(for owner: BattleParticipant, in context: BattleState) -> Bool {
        guard context.roster[owner].isAlive else { return false }
        guard owner == .hero || owner == .companion else { return false }
        return !isDeckDrawBlocked(for: owner, in: context)
    }

    static func isDeckDrawBlocked(for owner: BattleParticipant, in context: BattleState) -> Bool {
        guard owner.isPartyMember else { return false }
        let combatant = context.roster[owner].combatant
        return context.roster.hasPendingActionSkip(for: combatant, keyword: .freeze)
            || context.roster.hasPendingActionSkip(for: combatant, keyword: .stun)
    }

    static func deck(for owner: BattleParticipant, in context: BattleState) -> CombatDeck {
        switch owner {
        case .hero: context.heroDeck
        case .companion: context.companionDeck
        case .enemy: CombatDeck()
        }
    }

    static func putAbilityOnBottom(
        _ ability: Ability,
        owner: BattleParticipant,
        context: inout BattleState,
    ) {
        switch owner {
        case .hero: context.heroDeck.putOnBottom(ability)
        case .companion: context.companionDeck.putOnBottom(ability)
        case .enemy: return
        }
    }
}
