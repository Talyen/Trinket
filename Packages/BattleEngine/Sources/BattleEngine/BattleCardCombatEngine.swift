import Foundation
import TrinketContent
import TrinketCore

/// Orchestrates player card plays, the enemy turn, and the end-of-round effect pass.
public enum BattleCardCombatEngine {
    /// Shuffles loadout decks and clears hand state. Does not draw the opening hand.
    public static func bootstrapDecks(context: inout BattleState) {
        context.heroDeck = CombatDeck.shuffled(
            from: context.hero.abilityLoadout,
            rng: &context.rng
        )
        context.companionDeck = CombatDeck.shuffled(
            from: context.companion.abilityLoadout,
            rng: &context.rng
        )
        context.hand = BattleHand()
        context.handBuffer = BattleHandBuffer()
        context.openingHandDealPlan = makeOpeningHandDealPlan(in: context)
        context.phase = .playerTurn
        context.ownersSkippingThisPlayerTurn = []
    }

    /// Headless / test convenience: bootstrap decks and fill the opening hand immediately.
    public static func bootstrapDecksAndOpeningHand(context: inout BattleState) {
        bootstrapDecks(context: &context)
        drawOpeningHand(context: &context)
    }

    /// Draws the full opening hand (up to `BattleHand.maxSize`) and refreshes skip owners.
    @discardableResult
    public static func drawOpeningHand(context: inout BattleState) -> [ActionEvent] {
        while drawNextOpeningHandCard(context: &context) {}
        return finalizeOpeningHand(context: &context)
    }

    /// Draws one opening-hand card. Guaranteed-plan slots (one Basic per party
    /// member plus one Skill) are dealt first; any remaining slots fall back to
    /// the legacy random-owner pick.
    /// Returns `false` when the hand is full or no eligible deck remains.
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
            context.roster[owner].isAlive && !deck(for: owner, in: context).isEmpty
        }
        guard let owner = eligible.randomElement(using: &context.rng) else { return false }
        return drawOne(owner: owner, context: &context) != nil
    }

    /// Call after a paced opening deal finishes so skip owners match a bulk draw.
    @discardableResult
    public static func finalizeOpeningHand(context: inout BattleState) -> [ActionEvent] {
        context.ownersSkippingThisPlayerTurn = skippingOwners(in: context)
        return CombatTriggerEngine.atPlayerTurnStart(in: &context)
    }

    @discardableResult
    public static func playCard(
        cardID: Int,
        branchIndex: Int? = nil,
        context: inout BattleState
    ) throws -> [ActionEvent] {
        guard let card = context.hand.card(id: cardID) else { throw BattlePlayError.cardNotInHand }
        return try playDrawnCard(card, branchIndex: branchIndex, context: &context)
    }

    /// Plays a just-drawn card from the hand or overflow buffer. Does not
    /// substitute a different in-hand card when the draw overflowed.
    static func playDrawnCard(
        _ card: BattleCard,
        branchIndex: Int? = nil,
        context: inout BattleState
    ) throws -> [ActionEvent] {
        guard !context.isBattleOver else { throw BattlePlayError.battleOver }
        guard context.phase == .playerTurn else { throw BattlePlayError.notPlayerTurn }
        let ownerRuntime = context.roster[card.owner]
        guard ownerRuntime.isAlive else { throw BattlePlayError.ownerDefeated }
        guard !context.ownersSkippingThisPlayerTurn.contains(card.owner) else {
            throw BattlePlayError.ownerSkipping
        }
        try validateBranchSelection(branchIndex, for: card)
        if context.hand.remove(id: card.id) == nil {
            guard context.handBuffer.remove(id: card.id) != nil else {
                throw BattlePlayError.cardNotInHand
            }
        }
        return resolvePlayedCard(card, branchIndex: branchIndex, ownerRuntime: ownerRuntime, context: &context)
    }

    private static func validateBranchSelection(
        _ branchIndex: Int?,
        for card: BattleCard
    ) throws {
        guard let branchIndex else { return }
        guard let branches = card.ability.outcomeBranches,
              branches.indices.contains(branchIndex)
        else { throw BattlePlayError.invalidBranchSelection }
    }

    private static func resolvePlayedCard(
        _ card: BattleCard,
        branchIndex: Int?,
        ownerRuntime: CombatantRuntime,
        context: inout BattleState
    ) -> [ActionEvent] {
        let actor = ownerRuntime.combatant
        let abilityTarget = actor.role == .enemy ? context.roster.enemyAttackTarget : context.enemy
        var events = BattleTurnEngine.performAction(
            ability: card.ability,
            actor: actor,
            abilityTarget: abilityTarget,
            context: &context,
            chosenBranchIndex: branchIndex
        )
        events.append(contentsOf: CombatTriggerEngine.afterCardPlayed(
            ability: card.ability,
            by: actor,
            abilityTarget: abilityTarget,
            in: &context
        ))
        // Recycle after the card's effects (and on-play triggers) so a draw
        // cannot fetch the card still resolving — empty personal decks stay empty.
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
        context: inout BattleState
    ) -> [ActionEvent] {
        guard !context.isBattleOver, context.phase == .playerTurn else {
            return []
        }

        var events: [ActionEvent] = []

        // Clear party control skips that blocked card play this turn.
        for owner in context.ownersSkippingThisPlayerTurn {
            let combatant = context.roster[owner].combatant
            if context.roster.hasPendingActionSkip(for: combatant) {
                events.append(contentsOf: BattleTurnEngine.consumeActionSkip(
                    for: combatant,
                    context: &context
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

        // End of turn triggers fire before round clock advances and block decays
        events.append(contentsOf: CombatTriggerEngine.atPlayerEndTurn(in: &context))

        // End of round: advance round clock, then one effect pass.
        context.turnCount += 1
        events.append(contentsOf: EffectTurnEngine.advanceAll(context: &context))
        for combatant in [context.roster.hero.combatant, context.roster.companion.combatant, context.roster.enemy.combatant] {
            DefensePoolEngine.decayBlockAtEndOfRound(on: combatant, in: &context)
        }
        events.append(contentsOf: context.appendDefeatMilestonesIfNeeded())
        // Death's Door expiry grace covers this round's effect pass so a DoT
        // cannot kill in the same moment the effect falls off. Clear it before
        // the next player turn.
        for participant in BattleParticipant.allCases {
            context.roster.mutateRuntime(for: context.roster[participant].combatant) {
                $0.deathsDoorExpiredAtTurn = nil
            }
        }
        if context.isBattleOver {
            context.phase = .ended
            return events
        }

        discardDefeatedOwnerCards(context: &context)
        drawCardsBalanced(heroCount: 1, companionCount: 1, context: &context)
        promoteFromBuffer(context: &context)
        context.ownersSkippingThisPlayerTurn = skippingOwners(in: context)
        events.append(contentsOf: restoreManaAtPlayerTurnStart(context: &context))
        events.append(contentsOf: CombatTriggerEngine.atPlayerTurnStart(in: &context))
        // Party members act this turn: drop any post-skip control linger so a
        // recovered hero/companion no longer shows Stunned/Frozen while acting.
        for owner in [BattleParticipant.hero, .companion] {
            context.roster.clearControlStatusLinger(for: context.roster[owner].combatant)
        }
        context.phase = .playerTurn
        return events
    }

    /// Restores +1 Mana to living party members with a Mana pool.
    private static func restoreManaAtPlayerTurnStart(
        context: inout BattleState
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for owner in [BattleParticipant.hero, .companion] {
            let runtime = context.roster[owner]
            guard runtime.isAlive, runtime.maxMana > 0 else { continue }
            let combatant = runtime.combatant
            let restored = context.restoreMana(1, to: combatant)
            guard restored > 0 else { continue }
            events.append(
                context.nextEvent(
                    kind: .effect,
                    effectKind: .resourceGain,
                    actorName: combatant.name,
                    abilityName: Keyword.mana.rawValue,
                    target: combatant,
                    amount: restored,
                    keyword: .mana
                )
            )
            events.append(contentsOf: CombatTriggerEngine.afterGainMana(by: combatant, in: &context))
        }
        return events
    }

    public static func isCardPlayable(_ card: BattleCard, in context: BattleState) -> Bool {
        guard context.phase == .playerTurn, !context.isBattleOver else { return false }
        let runtime = context.roster[card.owner]
        guard runtime.isAlive else { return false }
        return !context.ownersSkippingThisPlayerTurn.contains(card.owner)
    }

    // MARK: - Private

    /// Draws up to `count` cards for `owner` from their deck into the hand or buffer.
    /// Returns how many cards were actually taken from the deck (empty deck / dead owner may reduce this).
    @discardableResult
    public static func drawCards(
        count: Int,
        for owner: BattleParticipant,
        context: inout BattleState
    ) -> Int {
        var drawn = 0
        for _ in 0 ..< count {
            if drawOne(owner: owner, context: &context) != nil {
                drawn += 1
            } else {
                break
            }
        }
        return drawn
    }

    private static func resolveEnemyTurn(
        context: inout BattleState
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

        let abilityTarget = context.talentAdjustedEnemyTarget
        let turnNumber = context.roster.enemy.actionCount + 1
        guard let ability = BattleTurnEngine.selectedEnemyAbility(for: enemy, turnNumber: turnNumber) else {
            return leadingEvents
        }
        var events = BattleTurnEngine.performAction(
            ability: ability,
            actor: enemy,
            abilityTarget: abilityTarget,
            context: &context
        )
        events.append(contentsOf: CombatTriggerEngine.afterEnemyAbility(in: &context))
        return leadingEvents + events
    }

    private static func skippingOwners(in context: BattleState) -> Set<BattleParticipant> {
        var skipping: Set<BattleParticipant> = []
        for owner in [BattleParticipant.hero, .companion] {
            let combatant = context.roster[owner].combatant
            if context.roster[owner].isAlive, context.roster.hasPendingActionSkip(for: combatant) {
                skipping.insert(owner)
            }
        }
        return skipping
    }

    /// Resolves simultaneous automatic draws one card at a time so open hand
    /// slots go to the owner with fewer cards. Round parity rotates the
    /// tie-break. Quotas continue after the hand is full so overflow enters
    /// the hand buffer.
    private static func drawCardsBalanced(
        heroCount: Int,
        companionCount: Int,
        context: inout BattleState
    ) {
        var remaining: [BattleParticipant: Int] = [.hero: heroCount, .companion: companionCount]
        let tieWinner: BattleParticipant = context.turnCount.isMultiple(of: 2) ? .hero : .companion

        while true {
            let candidates = [BattleParticipant.hero, .companion].filter {
                remaining[$0, default: 0] > 0
            }
            guard !candidates.isEmpty else { return }

            let owner: BattleParticipant
            if context.hand.isFull {
                // Hand is full — exhaust remaining quotas into the buffer without re-balancing.
                owner = candidates.contains(tieWinner) ? tieWinner : candidates[0]
            } else if candidates.count == 1 {
                owner = candidates[0]
            } else {
                let heroHandCount = context.hand.cards.count { $0.owner == .hero }
                let companionHandCount = context.hand.cards.count { $0.owner == .companion }
                if heroHandCount == companionHandCount {
                    owner = tieWinner
                } else {
                    owner = heroHandCount < companionHandCount ? .hero : .companion
                }
            }

            remaining[owner, default: 0] -= 1
            if drawOne(owner: owner, context: &context) == nil {
                remaining[owner] = 0
            }
        }
    }

    /// Draws one card for `owner` into the hand or overflow buffer.
    static func drawOneCard(for owner: BattleParticipant, context: inout BattleState) -> BattleCard? {
        drawOne(owner: owner, context: &context)
    }

    @discardableResult
    private static func drawOne(owner: BattleParticipant, context: inout BattleState) -> BattleCard? {
        guard context.roster[owner].isAlive else { return nil }

        let ability: Ability? = switch owner {
        case .hero:
            context.heroDeck.draw()
        case .companion:
            context.companionDeck.draw()
        case .enemy:
            nil
        }
        guard let ability else { return nil }
        return deal(ability, owner: owner, context: &context)
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
        context: inout BattleState
    ) {
        switch owner {
        case .hero:
            context.heroDeck.putOnBottom(ability)
        case .companion:
            context.companionDeck.putOnBottom(ability)
        case .enemy:
            break
        }
    }
}
