import Foundation
import TrinketContent
import TrinketCore

/// Orchestrates player card plays, the enemy turn, and end-of-round effect ticks.
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
        context.phase = .playerTurn
        context.ownersSkippingThisPlayerTurn = []
    }

    /// Headless / test convenience: bootstrap decks and fill the opening hand immediately.
    public static func bootstrapDecksAndOpeningHand(context: inout BattleState) {
        bootstrapDecks(context: &context)
        drawOpeningHand(context: &context)
    }

    /// Draws the full opening hand (up to `BattleHand.maxSize`) and refreshes skip owners.
    public static func drawOpeningHand(context: inout BattleState) {
        while drawNextOpeningHandCard(context: &context) {}
        finalizeOpeningHand(context: &context)
    }

    /// Draws one opening-hand card using the same owner-pick rules as bulk opening draw.
    /// Returns `false` when the hand is full or no eligible deck remains.
    @discardableResult
    public static func drawNextOpeningHandCard(context: inout BattleState) -> Bool {
        guard context.hand.count < BattleHand.maxSize else { return false }
        let eligible = [BattleParticipant.hero, .companion].filter { owner in
            context.roster[owner].isAlive && !deck(for: owner, in: context).isEmpty
        }
        guard let owner = eligible.randomElement(using: &context.rng) else { return false }
        return drawOne(owner: owner, context: &context)
    }

    /// Call after a paced opening deal finishes so skip owners match a bulk draw.
    public static func finalizeOpeningHand(context: inout BattleState) {
        context.ownersSkippingThisPlayerTurn = skippingOwners(in: context)
    }

    @discardableResult
    public static func playCard(
        cardID: Int,
        context: inout BattleState
    ) throws -> [ActionEvent] {
        guard !context.isBattleOver else { throw BattlePlayError.battleOver }
        guard context.phase == .playerTurn else { throw BattlePlayError.notPlayerTurn }
        guard let card = context.hand.card(id: cardID) else { throw BattlePlayError.cardNotInHand }

        let ownerRuntime = context.roster[card.owner]
        guard ownerRuntime.isAlive else { throw BattlePlayError.ownerDefeated }
        guard !context.ownersSkippingThisPlayerTurn.contains(card.owner) else {
            throw BattlePlayError.ownerSkipping
        }

        _ = context.hand.remove(id: cardID)
        putAbilityOnBottom(card.ability, owner: card.owner, context: &context)

        let actor = ownerRuntime.combatant
        let abilityTarget = actor.role == .enemy ? context.roster.enemyAttackTarget : context.enemy
        var events = BattleTurnEngine.performAction(
            ability: card.ability,
            actor: actor,
            abilityTarget: abilityTarget,
            context: &context
        )
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

        // Enemy phase
        events.append(contentsOf: resolveEnemyTurn(context: &context))
        events.append(contentsOf: context.appendDefeatMilestonesIfNeeded())
        if context.isBattleOver {
            context.phase = .ended
            return events
        }

        // End of round: advance round clock, tick effects once.
        for participant in BattleParticipant.allCases {
            context.roster.mutateRuntime(for: context.roster[participant].combatant) {
                $0.deathsDoorExpiredAtTurn = nil
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

        // Draw for next player turn
        discardDefeatedOwnerCards(context: &context)
        drawCardsBalanced(heroCount: 1, companionCount: 1, context: &context)
        promoteFromBuffer(context: &context)
        context.ownersSkippingThisPlayerTurn = skippingOwners(in: context)
        events.append(contentsOf: restoreManaAtPlayerTurnStart(context: &context))
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
            if drawOne(owner: owner, context: &context) {
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

        if context.roster.hasPendingActionSkip(for: enemy) {
            return BattleTurnEngine.consumeActionSkip(for: enemy, context: &context)
        }

        // Drop post-skip linger so the enemy does not look CC'd while attacking.
        context.roster.clearControlStatusLinger(for: enemy)

        let turnNumber = context.roster.enemy.actionCount + 1
        guard let ability = BattleTurnEngine.selectedEnemyAbility(for: enemy, turnNumber: turnNumber) else {
            return []
        }
        return BattleTurnEngine.performAction(
            ability: ability,
            actor: enemy,
            abilityTarget: context.roster.enemyAttackTarget,
            context: &context
        )
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

            let owner: BattleParticipant = if context.hand.isFull {
                // Hand is full — exhaust remaining quotas into the buffer without re-balancing.
                candidates.contains(tieWinner) ? tieWinner : candidates[0]
            } else {
                candidates.min { lhs, rhs in
                    let lhsCount = context.hand.cards.count { $0.owner == lhs }
                    let rhsCount = context.hand.cards.count { $0.owner == rhs }
                    if lhsCount == rhsCount {
                        return lhs == tieWinner && rhs != tieWinner
                    }
                    return lhsCount < rhsCount
                } ?? tieWinner
            }

            remaining[owner, default: 0] -= 1
            if !drawOne(owner: owner, context: &context) {
                remaining[owner] = 0
            }
        }
    }

    /// Returns defeated-owner cards from hand/buffer to their decks so dead
    /// companion/hero cards cannot permanently fill hand slots.
    private static func discardDefeatedOwnerCards(context: inout BattleState) {
        guard !context.roster.hero.isAlive || !context.roster.companion.isAlive else { return }
        var survivingHand: [BattleCard] = []
        for card in context.hand.cards {
            if context.roster[card.owner].isAlive {
                survivingHand.append(card)
            } else {
                putAbilityOnBottom(card.ability, owner: card.owner, context: &context)
            }
        }
        context.hand = BattleHand(cards: survivingHand)

        var survivingBuffer = BattleHandBuffer()
        for card in context.handBuffer.cards {
            if context.roster[card.owner].isAlive {
                survivingBuffer.enqueue(card)
            } else {
                putAbilityOnBottom(card.ability, owner: card.owner, context: &context)
            }
        }
        context.handBuffer = survivingBuffer
    }

    /// Moves buffered cards into the hand in FIFO order until the hand is full.
    /// Skips defeated-owner cards (defensive; callers also purge before promote).
    private static func promoteFromBuffer(context: inout BattleState) {
        guard !context.handBuffer.isEmpty else { return }
        while !context.hand.isFull {
            guard let card = context.handBuffer.dequeue() else { return }
            guard context.roster[card.owner].isAlive else {
                putAbilityOnBottom(card.ability, owner: card.owner, context: &context)
                continue
            }
            context.hand.append(card)
        }
    }

    @discardableResult
    private static func drawOne(owner: BattleParticipant, context: inout BattleState) -> Bool {
        guard context.roster[owner].isAlive else { return false }

        let ability: Ability? = switch owner {
        case .hero:
            context.heroDeck.draw()
        case .companion:
            context.companionDeck.draw()
        case .enemy:
            nil
        }
        guard let ability else { return false }

        context.nextCardID += 1
        let card = BattleCard(id: context.nextCardID, ability: ability, owner: owner)
        if context.hand.isFull {
            context.handBuffer.enqueue(card)
        } else {
            context.hand.append(card)
        }
        return true
    }

    private static func deck(for owner: BattleParticipant, in context: BattleState) -> CombatDeck {
        switch owner {
        case .hero: context.heroDeck
        case .companion: context.companionDeck
        case .enemy: CombatDeck()
        }
    }

    private static func putAbilityOnBottom(
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
