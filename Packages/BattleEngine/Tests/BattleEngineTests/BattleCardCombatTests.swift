import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct BattleCardCombatTests {
    private func makeBattle(
        heroAbilities: [Ability],
        petAbilities: [Ability] = [],
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
        let pet = Combatant(
            id: "pet",
            name: "Pet",
            role: .pet,
            maxHealth: 50,
            abilities: petAbilities
        )
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: enemyMaxHealth,
            abilities: enemyAbilities
        )
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)
        if let heroMana {
            battle.withEngineContext { context in
                context.roster.mutateRuntime(for: hero) { $0.currentMana = heroMana }
            }
        }
        return battle
    }

    @Test func openingHandIsTwoHeroAndTwoPet() throws {
        // Decks need ≥2 abilities each so opening draw of 2+2 can succeed.
        let battle = makeBattle(
            heroAbilities: [.slash, .heal, .smite],
            petAbilities: [.bash, .fangs, .bloodthorn]
        )
        try #expect(battle.hand.count == 4)
        try #expect(battle.hand.cards.filter { $0.owner == .hero }.count == 2)
        try #expect(battle.hand.cards.filter { $0.owner == .pet }.count == 2)
        try #expect(battle.phase == .playerTurn)
    }

    @Test func playPutsCardOnBottomOfOwnerDeck() throws {
        var battle = makeBattle(
            heroAbilities: [.slash, .heal, .smite],
            petAbilities: [.bash, .fangs, .bloodthorn]
        )
        let card = try #require(battle.hand.cards.first { $0.owner == .hero })
        let abilityID = card.ability.id
        let deckBefore = battle.heroDeck.count

        _ = try battle.playCard(cardID: card.id)

        try #expect(battle.hand.card(id: card.id) == nil)
        try #expect(battle.heroDeck.count == deckBefore + 1)
        try #expect(battle.heroDeck.abilities.last?.id == abilityID)
    }

    @Test func darkPactDrawsTwoCardsForOwner() throws {
        var battle = makeBattle(
            heroAbilities: [.darkPact, .slash, .heal, .smite],
            petAbilities: [.bash, .fangs, .bloodthorn],
            enemyMaxHealth: 500
        )
        let handBefore = battle.hand.count
        let events = try BattleTestFixtures.playCardNamed("Dark Pact", owner: .hero, on: &battle)

        // Dark Pact costs 1 hand card to play, then draws 2 → net +1.
        try #expect(battle.hand.count == handBefore + 1)
        try #expect(events.contains { $0.effectKind == .cardsDrawn && $0.amount == 2 })
        try #expect(battle.health(of: battle.hero) == 48)
    }

    @Test func handSoftCapSkipsDrawAtEight() throws {
        // Loadouts only hold 3 abilities, so seed the hand to the soft cap directly.
        var battle = makeBattle(
            heroAbilities: [.slash, .heal, .smite],
            petAbilities: [.bash, .fangs, .bloodthorn],
            enemyAbilities: [],
            enemyMaxHealth: 500
        )
        while battle.hand.count < BattleHand.softCap {
            battle.nextCardID += 1
            let owner: BattleParticipant = battle.hand.count.isMultiple(of: 2) ? .hero : .pet
            battle.hand.append(
                BattleCard(id: battle.nextCardID, ability: .slash, owner: owner)
            )
        }
        try #expect(battle.hand.count == BattleHand.softCap)

        let countAtCap = battle.hand.count
        _ = battle.endTurn()
        try #expect(battle.hand.count == countAtCap)
    }

    @Test func enemyCadenceUsesBasicSkillAndUltimate() throws {
        let basic = Ability(id: "e-basic", name: "E Basic", tier: .basic, directDamage: 1, description: "B")
        let skill = Ability(id: "e-skill", name: "E Skill", tier: .skill, directDamage: 2, description: "S")
        let ultimate = Ability(id: "e-ult", name: "E Ult", tier: .ultimate, directDamage: 3, description: "U")
        var battle = makeBattle(
            heroAbilities: [],
            petAbilities: [],
            enemyAbilities: [basic, skill, ultimate],
            enemyMaxHealth: 500
        )

        var abilityNames: [String] = []
        for _ in 0 ..< 6 {
            let events = battle.endTurn()
            if let name = events.first(where: { $0.kind == .ability && $0.actorID == "enemy" })?.abilityName {
                abilityNames.append(name)
            }
        }

        try #expect(abilityNames == ["E Basic", "E Basic", "E Skill", "E Basic", "E Basic", "E Ult"])
    }

    @Test func endOfRoundTicksEffectsOnce() throws {
        var battle = makeBattle(
            heroAbilities: [],
            petAbilities: [],
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
        var battle = makeBattle(heroAbilities: [.slash], petAbilities: [.bash])
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

        // Pet cards remain playable.
        let petCard = try #require(battle.hand.cards.first { $0.owner == .pet })
        try #expect(battle.isCardPlayable(petCard))
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
            petAbilities: [.bash],
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
