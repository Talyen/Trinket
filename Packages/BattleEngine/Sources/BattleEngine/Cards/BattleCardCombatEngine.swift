import Foundation
import TrinketContent
import TrinketCore

package enum BattleCardCombatEngine {
    package static func bootstrapDecks(context: inout BattleState) {
        context.heroDeck = CombatDeck.shuffled(
            from: context.hero.abilityLoadout,
            rng: &context.rng,
        )
        context.companionDeck = CombatDeck.shuffled(
            from: context.companion.abilityLoadout,
            rng: &context.rng,
        )
        context.hand = BattleHand()
        context.nextScheduledDrawOwner = .hero
        context.turnState = .opening(scheduledDraws(in: &context))
        context.ownersSkippingThisPlayerTurn = []
    }

    package static func drawOpeningHand(
        context: inout BattleState,
    ) async {
        guard case let .opening(draws) = context.turnState else { return }
        context.turnState = .resolving
        for owner in draws {
            drawOne(for: owner, context: &context)
        }
        context.ownersSkippingThisPlayerTurn = skippingOwners(in: context)
        // Later rounds receive this grant during effect advancement; opening
        // has no preceding round to advance.
        for participant in BattleParticipant.effectTurnOrder {
            guard !context.isBattleOver else { break }
            CombatTriggerEngine.turnBlock(for: context.roster[participant].combatant, in: &context)
        }
        await CombatTriggerEngine.atPlayerTurnStart(in: &context)
        await finishPlayerTurnStart(context: &context)
    }

    static func finishPlayerTurnStart(context: inout BattleState) async {
        discardDefeatedOwnerCards(context: &context)
        promoteFromBuffer(context: &context)
        context.ownersSkippingThisPlayerTurn = skippingOwners(in: context)
        await context.appendDefeatMilestonesIfNeeded()
        context.turnState = context.isBattleOver ? .ended : .playerTurn
    }

    package static func endTurn(
        context: inout BattleState,
    ) async {
        guard !context.isBattleOver, context.phase == .playerTurn else {
            return
        }

        context.turnState = .resolving
        await advanceRoundCommon(context: &context)
        guard context.phase != .ended else { return }

        UniqueCombatEngine.startTurn(in: &context)
        context.heroDeck.recycleDiscards()
        context.companionDeck.recycleDiscards()
        for owner in scheduledDraws(in: &context) {
            drawOne(for: owner, context: &context)
        }
        promoteFromBuffer(context: &context)
        context.ownersSkippingThisPlayerTurn = skippingOwners(in: context)
        await CombatTriggerEngine.atPlayerTurnStart(in: &context)
        for owner in BattleParticipant.party {
            UniqueCombatEngine.recoverStunBeforeClearing(on: context.roster[owner].combatant, in: &context)
            context.roster.clearControlStatusLinger(for: context.roster[owner].combatant)
        }
        await finishPlayerTurnStart(context: &context)
    }

    static func restoreManaAtPlayerTurnStart(
        context: inout BattleState,
    ) async {
        for owner in BattleParticipant.party {
            guard !context.isBattleOver else { break }
            let runtime = context.roster[owner]
            guard runtime.isAlive, runtime.maxMana > 0 else { continue }
            let combatant = runtime.combatant
            await context.restoreManaEmitting(1, to: combatant, abilityName: Keyword.mana.rawValue)
        }
    }

    package static func isCardPlayable(_ card: BattleCard, in context: BattleState) -> Bool {
        context.hand.card(id: card.id) == card && playError(for: card, in: context) == nil
    }

    static func playError(
        for card: BattleCard, in context: BattleState, allowsTurnPreparation: Bool = false,
    ) -> BattlePlayError? {
        guard !context.isBattleOver else { return .battleOver }
        guard allowsTurnPreparation || context.phase == .playerTurn else { return .notPlayerTurn }
        let runtime = context.roster[card.owner]
        guard runtime.isAlive else { return .ownerDefeated }
        guard !context.ownersSkippingThisPlayerTurn.contains(card.owner),
              !context.roster.hasPendingActionSkip(for: runtime.combatant) else { return .ownerSkipping }
        guard BattleAbilityRules.canPayHealthCost(card.ability, actor: runtime.combatant, in: context) else {
            return .insufficientHealth
        }
        return nil
    }

    @discardableResult
    package static func drawCards(
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
    ) async {
        let enemy = context.enemy
        guard context.roster.enemy.isAlive else { return }

        await DefensePoolEngine.decayBlock(on: enemy, in: &context)

        if context.roster.hasPendingActionSkip(for: enemy) {
            await BattleTurnEngine.consumeActionSkip(for: enemy, context: &context)
            return
        }

        UniqueCombatEngine.recoverStunBeforeClearing(on: enemy, in: &context)
        let wasFrozen = context.roster.hasControlStatus(for: enemy, keyword: .freeze)
        context.roster.clearControlStatusLinger(for: enemy)
        if wasFrozen {
            CombatTriggerEngine.afterEnemyFreezeRecover(in: &context)
        }

        let turnNumber = context.roster.enemy.actionCount + 1
        guard let ability = BattleTurnEngine.selectedEnemyAbility(for: enemy, turnNumber: turnNumber) else {
            return
        }
        let bleed = CombatTriggerEngine.beforeEnemyActBleedReactions(in: &context)
        if bleed {
            return
        }

        let avoidance = CombatTriggerEngine.consumeEnemyActionDelay(in: &context)
        if avoidance {
            return
        }

        let abilityTarget = BattleActionContext(actor: enemy, in: context).selectedTarget
        let action = await BattleTurnEngine.performEnemyAction(ability: ability, abilityTarget: abilityTarget, context: &context)
        if action {
            await CombatTriggerEngine.afterEnemyAbility(in: &context)
        }
    }

    static func skippingOwners(in context: BattleState) -> Set<BattleParticipant> {
        var skipping: Set<BattleParticipant> = []
        for owner in BattleParticipant.party {
            let combatant = context.roster[owner].combatant
            if context.roster[owner].isAlive, context.roster.hasPendingActionSkip(for: combatant) {
                skipping.insert(owner)
            }
        }
        return skipping
    }

    static func advanceRoundCommon(context: inout BattleState) async {
        for owner in BattleParticipant.party where context.ownersSkippingThisPlayerTurn.contains(owner) {
            let combatant = context.roster[owner].combatant
            if context.roster.hasPendingActionSkip(for: combatant) {
                await BattleTurnEngine.consumeActionSkip(for: combatant, context: &context)
            }
        }
        context.ownersSkippingThisPlayerTurn = []

        if await finishRoundIfBattleOver(context: &context) {
            return
        }

        await CombatTriggerEngine.atPlayerEndTurn(in: &context)
        for owner in BattleParticipant.party {
            context.roster.mutateRuntime(for: context.roster[owner].combatant) { $0.talents.turn.primedRepeatKeywords.removeAll() }
        }
        if await finishRoundIfBattleOver(context: &context) {
            return
        }

        await resolveEnemyTurn(context: &context)
        if await finishRoundIfBattleOver(context: &context) {
            return
        }

        for participant in BattleParticipant.allCases {
            context.roster.mutateRuntime(for: context.roster[participant].combatant) { runtime in
                if let expiredAt = runtime.deathsDoorExpiredAtTurn, expiredAt != context.turnCount {
                    runtime.deathsDoorExpiredAtTurn = nil
                }
            }
        }
        context.turnCount += 1
        await EffectTurnEngine.advanceAll(context: &context)
        for combatant in [context.roster.hero.combatant, context.roster.companion.combatant] {
            await DefensePoolEngine.decayBlock(on: combatant, in: &context)
        }
        if await finishRoundIfBattleOver(context: &context) {
            return
        }

        discardDefeatedOwnerCards(context: &context)
    }

    private static func finishRoundIfBattleOver(context: inout BattleState) async -> Bool {
        // Milestones can trigger victory rewards; finish them before checking the final roster.
        await context.appendDefeatMilestonesIfNeeded()
        guard context.isBattleOver else { return false }
        context.turnState = .ended
        return true
    }

    @discardableResult
    static func drawOne(for owner: BattleParticipant, context: inout BattleState) -> BattleCard? {
        drawSelecting(for: owner, context: &context) { $0.drawEntry() }
    }

    static func drawFirstCard(
        matching keyword: Keyword,
        for owner: BattleParticipant,
        context: inout BattleState,
    ) -> BattleCard? {
        drawSelecting(for: owner, context: &context) { $0.drawFirstEntry(where: { $0.keywords.contains(keyword) }) }
    }

    /// Shared guard, deck selection, and deal for every deck-draw path.
    static func drawSelecting(
        for owner: BattleParticipant,
        context: inout BattleState,
        select: (inout CombatDeck) -> CombatDeck.Entry?,
    ) -> BattleCard? {
        guard canDrawFromDeck(for: owner, in: context) else { return nil }
        let entry: CombatDeck.Entry? = switch owner {
        case .hero: select(&context.heroDeck)
        case .companion: select(&context.companionDeck)
        case .enemy: nil
        }
        guard let entry else { return nil }
        return deal(entry, owner: owner, context: &context)
    }

    static func canDrawFromDeck(for owner: BattleParticipant, in context: BattleState) -> Bool {
        guard owner.isPartyMember, context.roster[owner].isAlive else { return false }
        let combatant = context.roster[owner].combatant
        return !context.roster.hasPendingActionSkip(for: combatant, keyword: .freeze)
            && !context.roster.hasPendingActionSkip(for: combatant, keyword: .stun)
    }

    static func deck(for owner: BattleParticipant, in context: BattleState) -> CombatDeck {
        switch owner {
        case .hero: context.heroDeck
        case .companion: context.companionDeck
        case .enemy: CombatDeck()
        }
    }
}

// MARK: - Hand maintenance

extension BattleCardCombatEngine {
    /// Returns an owner's hand cards to the bottom of their deck ("purge"
    /// is reserved for stripping enemy buffs via `EffectRemovalOperation`).
    static func recycleControlledOwnerCards(
        for owner: BattleParticipant,
        context: inout BattleState,
    ) {
        guard owner.isPartyMember else { return }

        let removed = context.hand.removeAll { $0.owner == owner }
        for card in removed {
            putCardOnBottom(card, context: &context)
        }
        promoteFromBuffer(context: &context)
    }

    static func discardDefeatedOwnerCards(context: inout BattleState) {
        guard !context.roster.hero.isAlive || !context.roster.companion.isAlive else { return }

        let removed = context.hand.removeAll { !context.roster[$0.owner].isAlive }
        for card in removed {
            putCardOnBottom(card, context: &context)
        }
    }

    static func promoteFromBuffer(context: inout BattleState) {
        let isAlive: (BattleParticipant) -> Bool = { context.roster[$0].isAlive }
        let discarded = context.hand.promoteFromBuffer(isOwnerAlive: isAlive)
        for card in discarded {
            putCardOnBottom(card, context: &context)
        }
    }
}
