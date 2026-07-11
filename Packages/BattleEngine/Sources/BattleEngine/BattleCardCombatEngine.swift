import Foundation
import TrinketContent
import TrinketCore

/// Orchestrates player card plays, the enemy turn, and end-of-round effect ticks.
public enum BattleCardCombatEngine {
    public static func bootstrapDecksAndOpeningHand(context: inout BattleEngineContext) {
        context.heroDeck = CombatDeck.shuffled(
            from: context.hero.abilityLoadout,
            rng: &context.rng
        )
        context.petDeck = CombatDeck.shuffled(
            from: context.pet.abilityLoadout,
            rng: &context.rng
        )
        context.hand = BattleHand()
        drawCards(heroCount: 2, petCount: 2, context: &context)
        context.phase = .playerTurn
        context.ownersSkippingThisPlayerTurn = skippingOwners(in: context)
    }

    @discardableResult
    public static func playCard(
        cardID: Int,
        matchup: BattleMatchup,
        context: inout BattleEngineContext
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
        var events = BattleTurnEngine.performAbility(
            card.ability,
            actor: actor,
            matchup: matchup,
            context: &context,
            spendMana: false
        )
        events.append(contentsOf: context.appendDefeatMilestonesIfNeeded(matchup: matchup))
        if context.isBattleOver {
            context.phase = .ended
        }
        return events
    }

    @discardableResult
    public static func endTurn(
        matchup: BattleMatchup,
        context: inout BattleEngineContext
    ) -> [ActionEvent] {
        guard !context.isBattleOver, context.phase == .playerTurn else {
            return []
        }

        var events: [ActionEvent] = []

        // Clear party control skips that blocked card play this turn.
        for owner in context.ownersSkippingThisPlayerTurn {
            let combatant = matchup.combatant(for: owner)
            if context.roster.hasPendingActionSkip(for: combatant) {
                events.append(contentsOf: BattleTurnEngine.consumeActionSkip(
                    for: combatant,
                    context: &context
                ))
            }
        }
        context.ownersSkippingThisPlayerTurn = []

        if context.isBattleOver {
            events.append(contentsOf: context.appendDefeatMilestonesIfNeeded(matchup: matchup))
            context.phase = .ended
            return events
        }

        // Enemy phase
        events.append(contentsOf: resolveEnemyTurn(matchup: matchup, context: &context))
        events.append(contentsOf: context.appendDefeatMilestonesIfNeeded(matchup: matchup))
        if context.isBattleOver {
            context.phase = .ended
            return events
        }

        // End of round: advance round clock, tick effects once.
        for participant in BattleParticipant.allCases {
            context.roster.mutateRuntime(for: context.roster[participant].combatant) {
                $0.deathsDoorExpiredAtTick = nil
            }
        }
        context.tickCount += 1
        events.append(contentsOf: EffectTickEngine.tickAll(context: &context, matchup: matchup))
        for combatant in [context.roster.hero.combatant, context.roster.pet.combatant, context.roster.enemy.combatant] {
            DefensePoolEngine.decayBlockAtEndOfRound(on: combatant, in: &context)
        }
        events.append(contentsOf: context.appendDefeatMilestonesIfNeeded(matchup: matchup))
        if context.isBattleOver {
            context.phase = .ended
            return events
        }

        // Draw for next player turn
        drawCards(heroCount: 1, petCount: 1, context: &context)
        context.ownersSkippingThisPlayerTurn = skippingOwners(in: context)
        context.phase = .playerTurn
        return events
    }

    public static func isCardPlayable(_ card: BattleCard, in context: BattleEngineContext) -> Bool {
        guard context.phase == .playerTurn, !context.isBattleOver else { return false }
        let runtime = context.roster[card.owner]
        guard runtime.isAlive else { return false }
        return !context.ownersSkippingThisPlayerTurn.contains(card.owner)
    }

    // MARK: - Private

    /// Draws up to `count` cards for `owner` from their deck into the hand.
    /// Returns how many cards were actually drawn (soft-cap / empty deck may reduce this).
    @discardableResult
    public static func drawCards(
        count: Int,
        for owner: BattleParticipant,
        context: inout BattleEngineContext
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
        matchup: BattleMatchup,
        context: inout BattleEngineContext
    ) -> [ActionEvent] {
        let enemy = matchup.enemy
        guard context.roster.enemy.isAlive else { return [] }

        if context.roster.hasPendingActionSkip(for: enemy) {
            return BattleTurnEngine.consumeActionSkip(for: enemy, context: &context)
        }

        let turnNumber = context.roster.enemy.actionCount + 1
        guard let ability = BattleTurnEngine.selectedEnemyAbility(for: enemy, turnNumber: turnNumber) else {
            return []
        }
        return BattleTurnEngine.performAbility(
            ability,
            actor: enemy,
            matchup: matchup,
            context: &context,
            spendMana: false
        )
    }

    private static func skippingOwners(in context: BattleEngineContext) -> Set<BattleParticipant> {
        var skipping: Set<BattleParticipant> = []
        for owner in [BattleParticipant.hero, .pet] {
            let combatant = context.roster[owner].combatant
            if context.roster[owner].isAlive, context.roster.hasPendingActionSkip(for: combatant) {
                skipping.insert(owner)
            }
        }
        return skipping
    }

    private static func drawCards(heroCount: Int, petCount: Int, context: inout BattleEngineContext) {
        _ = drawCards(count: heroCount, for: .hero, context: &context)
        _ = drawCards(count: petCount, for: .pet, context: &context)
    }

    @discardableResult
    private static func drawOne(owner: BattleParticipant, context: inout BattleEngineContext) -> Bool {
        guard context.roster[owner].isAlive else { return false }
        guard !context.hand.isAtSoftCap else { return false }

        let ability: Ability? = switch owner {
        case .hero:
            context.heroDeck.draw()
        case .pet:
            context.petDeck.draw()
        case .enemy:
            nil
        }
        guard let ability else { return false }

        context.nextCardID += 1
        context.hand.append(BattleCard(id: context.nextCardID, ability: ability, owner: owner))
        return true
    }

    private static func putAbilityOnBottom(
        _ ability: Ability,
        owner: BattleParticipant,
        context: inout BattleEngineContext
    ) {
        switch owner {
        case .hero:
            context.heroDeck.putOnBottom(ability)
        case .pet:
            context.petDeck.putOnBottom(ability)
        case .enemy:
            break
        }
    }
}
