import Foundation
import TrinketContent
import TrinketCore

// swiftlint:disable file_length

/// Orchestrates player card plays, the enemy turn, and end-of-round effect ticks.
public enum BattleCardCombatEngine { // swiftlint:disable:this type_body_length
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
    @discardableResult
    public static func drawOpeningHand(context: inout BattleState) -> [ActionEvent] {
        while drawNextOpeningHandCard(context: &context) {}
        return finalizeOpeningHand(context: &context)
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
        context: inout BattleState
    ) throws -> [ActionEvent] {
        guard let card = context.hand.card(id: cardID) else { throw BattlePlayError.cardNotInHand }
        return try playDrawnCard(card, context: &context)
    }

    /// Plays a just-drawn card from the hand or overflow buffer. Does not
    /// substitute a different in-hand card when the draw overflowed.
    static func playDrawnCard(_ card: BattleCard, context: inout BattleState) throws -> [ActionEvent] {
        guard !context.isBattleOver else { throw BattlePlayError.battleOver }
        guard context.phase == .playerTurn else { throw BattlePlayError.notPlayerTurn }
        let ownerRuntime = context.roster[card.owner]
        guard ownerRuntime.isAlive else { throw BattlePlayError.ownerDefeated }
        guard !context.ownersSkippingThisPlayerTurn.contains(card.owner) else {
            throw BattlePlayError.ownerSkipping
        }
        if context.hand.remove(id: card.id) == nil {
            guard context.handBuffer.remove(id: card.id) != nil else {
                throw BattlePlayError.cardNotInHand
            }
        }
        return resolvePlayedCard(card, ownerRuntime: ownerRuntime, context: &context)
    }

    // swiftlint:disable:next function_body_length
    private static func resolvePlayedCard(
        _ card: BattleCard,
        ownerRuntime: CombatantRuntime,
        context: inout BattleState
    ) -> [ActionEvent] {
        putAbilityOnBottom(card.ability, owner: card.owner, context: &context)

        let actor = ownerRuntime.combatant
        let abilityTarget = actor.role == .enemy ? context.roster.enemyAttackTarget : context.enemy
        var events = BattleTurnEngine.performAction(
            ability: card.ability,
            actor: actor,
            abilityTarget: abilityTarget,
            context: &context
        )
        // Spell Echo: this combatant's first Skill card each battle plays twice.
        if card.ability.tier == .skill {
            let skillCount = context.skillCardsPlayedThisTurn[card.owner, default: 0] + 1
            context.skillCardsPlayedThisTurn[card.owner] = skillCount
            if skillCount == 1, context.modifiers(for: actor.id).triggers.firstSkillCardPlaysTwicePerBattle,
               !context.skillEchoOwnersThisBattle.contains(actor.id) {
                context.skillEchoOwnersThisBattle.insert(actor.id)
                events.append(contentsOf: BattleTurnEngine.performAction(
                    ability: card.ability,
                    actor: actor,
                    abilityTarget: abilityTarget,
                    context: &context
                ))
            }
        }
        events.append(contentsOf: CombatTriggerEngine.afterCardPlayed(by: actor, in: &context))
        // Scholarly Smite: when the Hero uses a Holy ability, the Owl deals Holy damage.
        if actor.role == .hero, card.ability.keywords.contains(.holy),
           context.roster.companion.isAlive,
           context.companionModifiers.triggers.onHeroHolyAbilityCompanionHolyDamage > 0,
           context.roster.enemy.isAlive {
            events.append(contentsOf: context.resolveDamage(
                DamageRequest(
                    amount: context.companionModifiers.triggers.onHeroHolyAbilityCompanionHolyDamage,
                    target: context.roster.enemy.combatant,
                    keyword: .holy,
                    sourceActorID: context.roster.companion.id,
                    options: DamageOptions(
                        applyStatBonus: false,
                        applyItemBonus: true,
                        applyDodge: false
                    )
                )
            ).events)
        }
        // Inferno Barrage: the Ultimate card applies Burn equal to the authored potency.
        if card.ability.tier == .ultimate,
           context.modifiers(for: actor.id).triggers.ultimateAppliesBurnPotency > 0,
           context.roster.enemy.isAlive {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .burn,
                potency: context.modifiers(for: actor.id).triggers.ultimateAppliesBurnPotency,
                to: context.roster.enemy.combatant,
                sourceActorID: actor.id,
                dealImmediateDamage: false,
                suppressAffixReactions: true
            ))
        }
        // Blizzard: playing 3 Freeze cards in one turn Freezes the enemy.
        if card.ability.keywords.contains(.freeze) {
            let freezeCount = context.freezeCardsPlayedThisTurn[card.owner, default: 0] + 1
            context.freezeCardsPlayedThisTurn[card.owner] = freezeCount
            let threshold = context.modifiers(for: actor.id).triggers.freezeCardsPlayedThisTurnFreezeAll
            if threshold > 0, freezeCount >= threshold, context.roster.enemy.isAlive {
                let enemyThreshold = ControlMeterEngine.threshold(for: context.roster.enemy.combatant, in: context)
                events.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                    enemyThreshold,
                    keyword: .freeze,
                    to: context.roster.enemy.combatant,
                    sourceActorID: actor.id,
                    applyFightPacing: false,
                    in: &context
                ))
            }
        }
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

        // End of turn triggers fire before round clock advances and block decays
        events.append(contentsOf: CombatTriggerEngine.atPlayerEndTurn(in: &context))

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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private static func resolveEnemyTurn(
        context: inout BattleState
    ) -> [ActionEvent] {
        let enemy = context.enemy
        guard context.roster.enemy.isAlive else { return [] }

        // Pinning Strike: a Bleeding enemy takes damage whenever it attacks.
        var leadingEvents: [ActionEvent] = []
        let enemyIsBleeding = context.roster.activeEffects(for: enemy).contains { $0.effect.keyword == .bleed }
        if enemyIsBleeding {
            let pin = max(
                context.heroModifiers.triggers.bleedingEnemyAttackDealDamage,
                context.companionModifiers.triggers.bleedingEnemyAttackDealDamage
            )
            if pin > 0 {
                leadingEvents = context.resolveDamage(
                    DamageRequest(
                        amount: pin,
                        target: enemy,
                        keyword: .physical,
                        sourceActorID: context.roster.hero.id,
                        options: DamageOptions(
                            applyStatBonus: false,
                            applyItemBonus: false,
                            applyDodge: false,
                            isRetaliation: true
                        )
                    )
                ).events
                guard context.roster.enemy.isAlive else { return leadingEvents }
            }
            // Hamstring Shot: a Bleeding enemy has a chance to skip its action this round.
            let skipChance = max(
                context.heroModifiers.triggers.bleedingEnemyActionSkipChancePercent,
                context.companionModifiers.triggers.bleedingEnemyActionSkipChancePercent
            )
            if skipChance > 0,
               BattleChance.succeeds(probability: skipChance, using: &context.rng) {
                leadingEvents.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .controlActionSkipped,
                    actorName: context.roster.enemy.name,
                    abilityName: "Hamstring Shot",
                    target: enemy,
                    amount: 0,
                    keyword: .bleed
                ))
                return leadingEvents
            }
        }

        if context.roster.hasPendingActionSkip(for: enemy) {
            return leadingEvents + BattleTurnEngine.consumeActionSkip(for: enemy, context: &context)
        }

        // Drop post-skip linger so the enemy does not look CC'd while attacking.
        context.roster.clearControlStatusLinger(for: enemy)

        // Companion negation talents: Warning Bark (once per combat) and Shadow Shift (once per round).
        let companion = context.roster.companion
        if companion.isAlive {
            let companionTriggers = context.companionModifiers.triggers
            if companionTriggers.negateFirstEnemyAttack || companionTriggers.negateFirstEnemyAttackChance > 0,
               !companion.hasNegatedFirstEnemyAttack {
                context.roster.mutateRuntime(for: companion.combatant) { $0.hasNegatedFirstEnemyAttack = true }
                let negated = companionTriggers.negateFirstEnemyAttack
                    || BattleChance.succeeds(
                        probability: companionTriggers.negateFirstEnemyAttackChance,
                        using: &context.rng
                    )
                if negated {
                    leadingEvents.append(context.nextEvent(
                        kind: .effect,
                        effectKind: .dodgeApplied,
                        actorName: companion.name,
                        abilityName: companionTriggers.negateFirstEnemyAttack ? "Warning Bark" : "Shadow Shift",
                        target: context.roster.enemy.combatant,
                        amount: 0,
                        keyword: .dodge
                    ))
                    return leadingEvents
                }
            }
            if companionTriggers.negateFirstEnemyAttackPerRound, !companion.hasNegatedEnemyAttackThisRound {
                context.roster.mutateRuntime(for: companion.combatant) { $0.hasNegatedEnemyAttackThisRound = true }
                leadingEvents.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .dodgeApplied,
                    actorName: companion.name,
                    abilityName: "Shadow Shift",
                    target: context.roster.enemy.combatant,
                    amount: 0,
                    keyword: .dodge
                ))
                return leadingEvents
            }
        }

        let abilityTarget = context.talentAdjustedEnemyTarget
        // Miss-chance talents (reuse the Dodge pipeline): Paralytic Poison and Subzero Mist.
        if context.roster.activeEffects(for: enemy).contains(where: { $0.effect.keyword == .poison }) {
            let missChance = max(
                context.heroModifiers.triggers.poisonedEnemyMissChancePercent,
                context.companionModifiers.triggers.poisonedEnemyMissChancePercent
            )
            if missChance > 0, BattleChance.succeeds(probability: missChance, using: &context.rng) {
                leadingEvents.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .dodgeApplied,
                    actorName: context.roster.enemy.name,
                    abilityName: "Paralytic Poison",
                    target: abilityTarget,
                    amount: 0,
                    keyword: .dodge
                ))
                return leadingEvents
            }
        }
        if context.roster.hasControlStatus(for: enemy, keyword: .freeze),
           abilityTarget.id == context.roster.companion.id,
           context.roster.companion.isAlive,
           context.companionModifiers.triggers.frozenEnemyMissChanceVsCompanionPercent > 0,
           BattleChance.succeeds(
               probability: context.companionModifiers.triggers.frozenEnemyMissChanceVsCompanionPercent,
               using: &context.rng
           ) {
            leadingEvents.append(context.nextEvent(
                kind: .effect,
                effectKind: .dodgeApplied,
                actorName: context.roster.enemy.name,
                abilityName: "Subzero Mist",
                target: abilityTarget,
                amount: 0,
                keyword: .dodge
            ))
            return leadingEvents
        }
        // Decoy Swap: the Fox swaps with the Hero and Dodges on their behalf.
        if abilityTarget.id == context.roster.hero.id,
           context.roster.companion.isAlive,
           context.companionModifiers.triggers.swapAndDodgeForHeroChance > 0,
           BattleChance.succeeds(probability: context.companionModifiers.triggers.swapAndDodgeForHeroChance, using: &context.rng) {
            context.prependEffect(.evadeNextHit, to: context.roster.hero.combatant, remainingTurns: 0)
        }

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
        // Fetch!: the Retriever draws a card and gains Gold when the enemy plays an ability.
        if context.roster.companion.isAlive {
            let retrieverTriggers = context.companionModifiers.triggers
            if retrieverTriggers.onEnemyAbilityGold > 0 {
                events.append(contentsOf: context.grantGoldEvent(
                    retrieverTriggers.onEnemyAbilityGold,
                    to: context.roster.companion.combatant,
                    abilityName: "Fetch!"
                ))
            }
            if retrieverTriggers.onEnemyAbilityDrawAndGoldDraw > 0 {
                let drawn = Self.drawCards(
                    count: retrieverTriggers.onEnemyAbilityDrawAndGoldDraw,
                    for: .companion,
                    context: &context
                )
                if drawn > 0 {
                    events.append(context.nextEvent(
                        kind: .effect,
                        effectKind: .cardsDrawn,
                        actorName: context.roster.companion.name,
                        abilityName: "Fetch!",
                        target: context.roster.companion.combatant,
                        amount: drawn,
                        keyword: .physical
                    ))
                }
            }
        }
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

        context.nextCardID += 1
        let card = BattleCard(id: context.nextCardID, ability: ability, owner: owner)
        if context.hand.isFull {
            context.handBuffer.enqueue(card)
        } else {
            context.hand.append(card)
        }
        return card
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
