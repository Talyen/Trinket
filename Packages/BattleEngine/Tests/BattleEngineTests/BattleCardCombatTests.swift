import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct BattleCardCombatTests {
    private func makeBattle(
        heroAbilities: [Ability],
        companionAbilities: [Ability] = [],
        enemyAbilities: [Ability] = [],
        enemyMaxHealth: Int = 100,
        heroMana: Int? = nil
    ) -> BattleState {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            maxMana: heroMana ?? 0,
            abilities: heroAbilities
        )
        let companion = Combatant(
            id: "companion",
            name: "Companion",
            role: .companion,
            maxHealth: 50,
            abilities: companionAbilities
        )
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: enemyMaxHealth,
            abilities: enemyAbilities
        )
        var battle = BattleStateTestFactory.makeBattle(hero: hero, companion: companion, enemy: enemy)
        if let heroMana {
            battle.withEngineContext { context in
                context.roster.mutateRuntime(for: hero) { $0.currentMana = heroMana }
            }
        }
        return battle
    }

    @Test func openingHandDrawsThreeCardsFromRandomOwners() throws {
        let battle = makeBattle(
            heroAbilities: [.slash, .heal, .smite],
            companionAbilities: [.bash, .fangs, .bloodthorn]
        )
        try #expect(battle.hand.count == BattleHand.maxSize)
        try #expect(battle.handBuffer.isEmpty)
        try #expect(battle.phase == .playerTurn)

        let heroDrawn = battle.hand.cards.filter { $0.owner == .hero }.count
        let companionDrawn = battle.hand.cards.filter { $0.owner == .companion }.count
        try #expect(heroDrawn + companionDrawn == BattleHand.maxSize)
        try #expect(battle.hand.cards.allSatisfy { $0.owner == .hero || $0.owner == .companion })
        // Remaining deck sizes match what was not drawn (loadouts may be <3 after tier collapse).
        try #expect(battle.heroDeck.count == battle.hero.abilityLoadout.abilities.count - heroDrawn)
        try #expect(battle.companionDeck.count == battle.companion.abilityLoadout.abilities.count - companionDrawn)
    }

    @Test func pacedOpeningHandMatchesImmediateDrawForSameSeed() throws {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            abilities: [.slash, .heal, .smite]
        )
        let companion = Combatant(
            id: "companion",
            name: "Companion",
            role: .companion,
            maxHealth: 50,
            abilities: [.bash, .fangs, .bloodthorn]
        )
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: []
        )
        let seed: UInt64 = 42
        let immediate = BattleState(
            hero: hero,
            companion: companion,
            enemy: enemy,
            rngSeed: seed,
            tracksLog: false
        )
        var paced = BattleState(
            hero: hero,
            companion: companion,
            enemy: enemy,
            rngSeed: seed,
            tracksLog: false,
            dealOpeningHand: false
        )
        try #expect(paced.hand.count == 0)

        var draws = 0
        while paced.drawNextOpeningHandCard(rebuildLog: false) {
            draws += 1
        }
        paced.finalizeOpeningHand()

        try #expect(draws == BattleHand.maxSize)
        try #expect(paced.hand.cards.map(\.ability.id) == immediate.hand.cards.map(\.ability.id))
        try #expect(paced.hand.cards.map(\.owner) == immediate.hand.cards.map(\.owner))
        try #expect(paced.ownersSkippingThisPlayerTurn == immediate.ownersSkippingThisPlayerTurn)
    }

    @Test func playPutsCardOnBottomOfOwnerDeck() throws {
        var battle = makeBattle(
            heroAbilities: [.slash, .heal, .smite],
            companionAbilities: [.bash, .fangs, .bloodthorn]
        )
        battle.hand = BattleHand()
        battle.handBuffer = BattleHandBuffer()
        battle.nextCardID += 1
        let card = BattleCard(id: battle.nextCardID, ability: .slash, owner: .hero)
        battle.hand.append(card)
        let deckBefore = battle.heroDeck.count

        _ = try battle.playCard(cardID: card.id)

        try #expect(battle.hand.card(id: card.id) == nil)
        try #expect(battle.heroDeck.count == deckBefore + 1)
        try #expect(battle.heroDeck.abilities.last?.id == Ability.slash.id)
    }

    @Test func darkPactDrawsTwoCardsForOwner() throws {
        var battle = makeBattle(
            heroAbilities: [.darkPact, .slash, .heal, .smite],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            enemyMaxHealth: 500
        )
        // Loadouts hold at most one card per tier (basic/skill/ultimate), so
        // this hero's real deck is only 2 cards (Slash + Dark Pact) and the
        // opening hand draw may exhaust it. Pad the deck so playing Dark Pact
        // has enough supply left to draw a full 2 cards.
        battle.heroDeck.putOnBottom(.heal)
        battle.heroDeck.putOnBottom(.smite)

        // Ensure Dark Pact is in hand at max size so overflow exercises the buffer.
        battle.hand = BattleHand()
        battle.handBuffer = BattleHandBuffer()
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: .darkPact, owner: .hero))
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: .slash, owner: .hero))
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: .bash, owner: .companion))

        let events = try BattleTestFixtures.playCardNamed("Dark Pact", owner: .hero, on: &battle)

        // Play frees 1 slot; draw 2 → 1 into hand, 1 into buffer; promote is a no-op.
        try #expect(battle.hand.count == BattleHand.maxSize)
        try #expect(battle.handBuffer.count == 1)
        try #expect(events.contains { $0.effectKind == .cardsDrawn && $0.amount == 2 })
        try #expect(battle.health(of: battle.hero) == 48)
    }

    @Test func darkPactHealthCostIgnoresBlock() throws {
        var battle = makeBattle(
            heroAbilities: [.darkPact, .slash, .heal, .smite],
            enemyMaxHealth: 500
        )
        battle.heroDeck.putOnBottom(.heal)
        battle.heroDeck.putOnBottom(.smite)
        battle.withEngineContext { context in
            context.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 20), remainingTicks: 6)],
                for: context.roster.hero.combatant
            )
        }
        battle.hand = BattleHand()
        battle.handBuffer = BattleHandBuffer()
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: .darkPact, owner: .hero))

        _ = try BattleTestFixtures.playCardNamed("Dark Pact", owner: .hero, on: &battle)

        try #expect(battle.health(of: battle.hero) == 48)
        let shield = battle.activeEffects(of: battle.hero).first {
            if case .shield = $0.effect {
                return true
            }
            return false
        }
        guard case let .shield(_, buffer) = shield?.effect else {
            Issue.record("Block should survive Dark Pact's Lose 2 Health cost")
            return
        }
        try #expect(buffer == 20)
    }

    @Test func endTurnAtFullHandDrawsIntoBuffer() throws {
        var battle = makeBattle(
            heroAbilities: [.slash, .heal, .smite],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            enemyAbilities: [],
            enemyMaxHealth: 500
        )
        while battle.hand.count < BattleHand.maxSize {
            battle.nextCardID += 1
            let owner: BattleParticipant = battle.hand.count.isMultiple(of: 2) ? .hero : .companion
            battle.hand.append(
                BattleCard(id: battle.nextCardID, ability: .slash, owner: owner)
            )
        }
        battle.heroDeck.putOnBottom(.slash)
        battle.companionDeck.putOnBottom(.bash)
        try #expect(battle.hand.count == BattleHand.maxSize)
        try #expect(battle.handBuffer.isEmpty)

        let countAtCap = battle.hand.count
        _ = battle.endTurn()
        try #expect(battle.hand.count == countAtCap)
        try #expect(battle.handBuffer.count == 2)
    }

    @Test func playingCardPromotesOldestBufferedCardFIFO() throws {
        var battle = makeBattle(
            heroAbilities: [.slash, .heal, .smite],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            enemyMaxHealth: 500
        )
        battle.hand = BattleHand()
        battle.handBuffer = BattleHandBuffer()
        battle.nextCardID += 1
        let firstBuffered = BattleCard(id: battle.nextCardID, ability: .fangs, owner: .companion)
        battle.handBuffer.enqueue(firstBuffered)
        battle.nextCardID += 1
        battle.handBuffer.enqueue(BattleCard(id: battle.nextCardID, ability: .bloodthorn, owner: .companion))
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: .slash, owner: .hero))
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: .heal, owner: .hero))
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: .smite, owner: .hero))

        let played = try #require(battle.hand.cards.first { $0.ability.id == Ability.slash.id })
        _ = try battle.playCard(cardID: played.id)

        // After effects, FIFO promote fills the freed slot with the oldest buffer card.
        try #expect(battle.hand.count == BattleHand.maxSize)
        try #expect(battle.hand.cards.contains { $0.id == firstBuffered.id })
        try #expect(battle.handBuffer.count == 1)
        try #expect(battle.handBuffer.cards.first?.ability.id == Ability.bloodthorn.id)
    }

    @Test func automaticOpenSlotGoesToOwnerWithFewerCards() throws {
        var battle = makeBattle(
            heroAbilities: [.slash, .heal, .smite],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            enemyMaxHealth: 500
        )
        // Leave one open slot with hero owning both hand cards so the balanced
        // draw prefers companion for the open slot; the second quota card buffers.
        battle.hand = BattleHand()
        battle.handBuffer = BattleHandBuffer()
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: .slash, owner: .hero))
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: .heal, owner: .hero))
        battle.heroDeck.putOnBottom(.smite)
        battle.companionDeck.putOnBottom(.fangs)

        _ = battle.endTurn()

        try #expect(battle.hand.count == BattleHand.maxSize)
        try #expect(battle.hand.cards.count { $0.owner == .hero } == 2)
        try #expect(battle.hand.cards.count { $0.owner == .companion } == 1)
        try #expect(battle.hand.cards.last?.owner == .companion)
        try #expect(battle.handBuffer.count == 1)
        try #expect(battle.handBuffer.cards.first?.owner == .hero)
    }

    @Test(arguments: [(0, BattleParticipant.companion), (1, BattleParticipant.hero)])
    func automaticOpenSlotAlternatesTiedOwnerByRound(
        startingTick: Int,
        expectedOwner: BattleParticipant
    ) throws {
        var battle = makeBattle(
            heroAbilities: [.slash, .heal, .smite],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            enemyMaxHealth: 500
        )
        battle.tickCount = startingTick
        // One open slot, tied owner counts (1 hero + 1 companion) → tie-break picks the open-slot owner.
        battle.hand = BattleHand()
        battle.handBuffer = BattleHandBuffer()
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: .slash, owner: .hero))
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: .bash, owner: .companion))
        battle.heroDeck.putOnBottom(.slash)
        battle.companionDeck.putOnBottom(.bash)

        _ = battle.endTurn()

        try #expect(battle.hand.count == BattleHand.maxSize)
        try #expect(battle.hand.cards.last?.owner == expectedOwner)
        try #expect(battle.handBuffer.count == 1)
    }

    @Test func endOfRoundTicksEffectsOnce() throws {
        var battle = makeBattle(
            heroAbilities: [],
            companionAbilities: [],
            enemyAbilities: []
        )
        battle.withEngineContext { context in
            context.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0)],
                for: context.enemy
            )
        }
        let before = battle.health(of: battle.enemy)
        let events = battle.endTurn()

        try #expect(battle.tickCount == 1)
        try #expect(events.filter { $0.kind == .status && $0.keyword == .burn }.count == 1)
        try #expect(battle.health(of: battle.enemy) < before)
    }

    @Test func deadOwnerCardsAreUnplayable() throws {
        var battle = makeBattle(heroAbilities: [.slash], companionAbilities: [.bash])
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.hero) { $0.currentHealth = 0 }
        }
        let heroCard = try #require(battle.hand.cards.first { $0.owner == .hero })
        try #expect(!battle.isCardPlayable(heroCard))

        do {
            _ = try battle.playCard(cardID: heroCard.id)
            Issue.record("Expected ownerDefeated")
        } catch BattlePlayError.ownerDefeated {
            // expected
        }

        // Companion cards remain playable.
        let companionCard = try #require(battle.hand.cards.first { $0.owner == .companion })
        try #expect(battle.isCardPlayable(companionCard))
    }

    @Test func manaCostIgnoredWhenPlayingCards() throws {
        let expensive = Ability(
            id: "expensive-skill",
            name: "Expensive Skill",
            tier: .skill,
            directDamage: 5,
            description: "Costs mana but card play ignores it.",
            manaCost: 9
        )
        var battle = makeBattle(
            heroAbilities: [expensive],
            companionAbilities: [.bash],
            heroMana: 0
        )
        try #expect(battle.mana(of: battle.hero) == 0)

        let card = try #require(battle.hand.cards.first { $0.ability.id == expensive.id })
        let events = try battle.playCard(cardID: card.id)

        try #expect(events.contains { $0.kind == .ability && $0.abilityID == expensive.id })
        try #expect(battle.mana(of: battle.hero) == 0)
        try #expect(100 - battle.health(of: battle.enemy) >= 5 || battle.health(of: battle.enemy) < 100)
    }
}
