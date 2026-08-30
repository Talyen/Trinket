import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct BattleCardCombatTests {
    private func makeBattle(
        heroAbilities: [Ability],
        companionAbilities: [Ability] = [],
        enemyAbilities: [Ability] = [],
        enemyMaxHealth: Int = 100,
        heroMaxMana: Int = 0,
        heroMana: Int? = nil,
        rngSeed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed,
    ) -> BattleState {
        BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: heroAbilities,
            companionAbilities: companionAbilities,
            enemyAbilities: enemyAbilities,
            enemyMaxHealth: enemyMaxHealth,
            heroMaxMana: heroMaxMana,
            heroMana: heroMana,
            rngSeed: rngSeed,
        )
    }

    @Test func `opening hand draws three cards from random owners`() throws {
        let battle = makeBattle(
            heroAbilities: [.slash, .heal, .smite],
            companionAbilities: [.bash, .fangs, .bloodthorn],
        )
        try #expect(battle.hand.count == BattleHand.maxSize)
        try #expect(battle.handBuffer.isEmpty)
        try #expect(battle.phase == .playerTurn)

        let heroDrawn = battle.hand.cards.count(where: { $0.owner == .hero })
        let companionDrawn = battle.hand.cards.count(where: { $0.owner == .companion })
        try #expect(heroDrawn + companionDrawn == BattleHand.maxSize)
        try #expect(battle.hand.cards.allSatisfy { $0.owner == .hero || $0.owner == .companion })
        try #expect(battle.heroDeck.count == battle.hero.abilityLoadout.abilities.count - heroDrawn)
        try #expect(battle.companionDeck.count == battle.companion.abilityLoadout.abilities.count - companionDrawn)
    }

    @Test func `paced opening hand matches immediate draw for same seed`() throws {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            abilities: [.slash, .heal, .smite],
        )
        let companion = Combatant(
            id: "companion",
            name: "Companion",
            role: .companion,
            maxHealth: 50,
            abilities: [.bash, .fangs, .bloodthorn],
        )
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: [],
        )
        let seed: UInt64 = 42
        let immediate = BattleState(
            hero: hero,
            companion: companion,
            enemy: enemy,
            rngSeed: seed,
            tracksLog: false,
        )
        var paced = BattleState(
            hero: hero,
            companion: companion,
            enemy: enemy,
            rngSeed: seed,
            tracksLog: false,
            dealOpeningHand: false,
        )
        try #expect(paced.hand.isEmpty)

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

    @Test func `play puts card on bottom of owner deck`() throws {
        var battle = makeBattle(
            heroAbilities: [.slash, .heal, .smite],
            companionAbilities: [.bash, .fangs, .bloodthorn],
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

    @Test func `dark pact draws two cards for owner`() throws {
        var battle = makeBattle(
            heroAbilities: [.darkPact, .slash, .heal, .smite],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            enemyMaxHealth: 500,
        )
        battle.heroDeck.putOnBottom(.heal)
        battle.heroDeck.putOnBottom(.smite)

        battle.hand = BattleHand()
        battle.handBuffer = BattleHandBuffer()
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: .darkPact, owner: .hero))
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: .slash, owner: .hero))
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: .bash, owner: .companion))

        let events = try BattleTestFixtures.playCardNamed("Dark Pact", owner: .hero, on: &battle)

        try #expect(battle.hand.count == BattleHand.maxSize)
        try #expect(battle.handBuffer.count == 1)
        try #expect(events.contains { $0.effectKind == .cardsDrawn && $0.amount == 2 })
        try #expect(battle.health(of: battle.hero) == 49)
    }

    @Test func `dark pact health cost ignores block`() throws {
        var battle = makeBattle(
            heroAbilities: [.darkPact, .slash, .heal, .smite],
            enemyMaxHealth: 500,
        )
        battle.heroDeck.putOnBottom(.heal)
        battle.heroDeck.putOnBottom(.smite)
        battle.withEngineContext { context in
            context.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 20), remainingTurns: 6)],
                for: context.roster.hero.combatant,
            )
        }
        battle.hand = BattleHand()
        battle.handBuffer = BattleHandBuffer()
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: .darkPact, owner: .hero))

        _ = try BattleTestFixtures.playCardNamed("Dark Pact", owner: .hero, on: &battle)

        try #expect(battle.health(of: battle.hero) == 49)
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

    @Test func `end turn at full hand draws into buffer`() throws {
        var battle = makeBattle(
            heroAbilities: [.slash, .heal, .smite],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            enemyAbilities: [],
            enemyMaxHealth: 500,
        )
        while battle.hand.count < BattleHand.maxSize {
            battle.nextCardID += 1
            let owner: BattleParticipant = battle.hand.count.isMultiple(of: 2) ? .hero : .companion
            battle.hand.append(
                BattleCard(id: battle.nextCardID, ability: .slash, owner: owner),
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

    @Test func `playing card promotes oldest buffered card FIFO`() throws {
        var battle = makeBattle(
            heroAbilities: [.slash, .heal, .smite],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            enemyMaxHealth: 500,
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

        try #expect(battle.hand.count == BattleHand.maxSize)
        try #expect(battle.hand.cards.contains { $0.id == firstBuffered.id })
        try #expect(battle.handBuffer.count == 1)
        try #expect(battle.handBuffer.cards.first?.ability.id == Ability.bloodthorn.id)
    }

    @Test func `automatic open slot goes to owner with fewer cards`() throws {
        var battle = makeBattle(
            heroAbilities: [.slash, .heal, .smite],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            enemyMaxHealth: 500,
        )
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
    func `automatic open slot alternates tied owner by round`(
        startingRound: Int,
        expectedOwner: BattleParticipant,
    ) throws {
        var battle = makeBattle(
            heroAbilities: [.slash, .heal, .smite],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            enemyMaxHealth: 500,
        )
        battle.turnCount = startingRound
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

    @Test func `end of round advances effects once`() throws {
        var battle = makeBattle(
            heroAbilities: [],
            companionAbilities: [],
            enemyAbilities: [],
        )
        battle.withEngineContext { context in
            context.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0)],
                for: context.enemy,
            )
        }
        let before = battle.health(of: battle.enemy)
        let events = battle.endTurn()

        try #expect(battle.turnCount == 1)
        try #expect(events.count(where: { $0.kind == .status && $0.keyword == .burn }) == 1)
        try #expect(battle.health(of: battle.enemy) < before)
    }

    @Test func `dead owner cards are unplayable`() throws {
        var battle = makeBattle(heroAbilities: [.slash], companionAbilities: [.bash])
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.hero) { $0.currentHealth = 0 }
        }
        let heroCard = try #require(battle.hand.cards.first { $0.owner == .hero })
        try #expect(!battle.isCardPlayable(heroCard))

        do {
            _ = try battle.playCard(cardID: heroCard.id)
            Issue.record("Expected ownerDefeated")
        } catch BattlePlayError.ownerDefeated {}

        let companionCard = try #require(battle.hand.cards.first { $0.owner == .companion })
        try #expect(battle.isCardPlayable(companionCard))
    }

    @Test func `played card returns to deck after effects so draw cannot fetch it`() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: Combatant(
                id: "hero",
                name: "Hero",
                role: .hero,
                maxHealth: 50,
                abilities: [.packTactics],
            ),
            companion: Combatant(
                id: "companion",
                name: "Companion",
                role: .companion,
                maxHealth: 50,
                abilities: [.slash],
            ),
            dealOpeningHand: false,
        )
        battle.heroDeck = CombatDeck()
        battle.companionDeck = CombatDeck(abilities: [.slash])
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: .packTactics, owner: .hero))

        let packTacticsID = try #require(battle.hand.cards.first?.id)
        let events = try battle.playCard(cardID: packTacticsID)

        try #expect(battle.heroDeck.abilities.last?.id == Ability.packTactics.id)
        try #expect(events.contains { $0.kind == .abilityDamage && $0.abilityName == Ability.slash.name })
        try #expect(events.count(where: { $0.kind == .ability && $0.abilityID == Ability.packTactics.id }) == 1)
        try #expect(battle.drawAndPlayDepth == 0)
    }
}
