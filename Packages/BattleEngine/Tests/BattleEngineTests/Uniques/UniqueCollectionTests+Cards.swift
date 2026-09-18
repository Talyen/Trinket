import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

extension UniqueCollectionTests {
    @Test(arguments: [BattleParticipant.hero, .companion])
    func `harvest returns only first attack against existing bleed`(owner: BattleParticipant) throws {
        var context = try battle(["red_harvest"], owner: owner)
        let actor = context.roster[owner].combatant
        let enemy = context.roster.enemy.combatant
        try play(attack(.bleed, id: "opening"), owner: owner, in: &context)
        #expect(context.hand.isEmpty)
        #expect(context.roster.hasAffliction(.bleed, on: enemy))
        try play(attack(.holy, id: "harvest"), owner: owner, in: &context)
        #expect(context.hand.cards.map(\.ability.id) == ["harvest"])
        #expect(!BattleCardCombatEngine.deck(for: owner, in: context).abilities.contains { $0.id == "harvest" })
        try play(attack(id: "later"), owner: owner, in: &context)
        #expect(context.hand.totalCount == 1)
        #expect(context.roster.health(for: actor) > 0)
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `wrenflight counts only wearers ordinary cards`(owner: BattleParticipant) throws {
        var context = try battle(["wrenflight"], owner: owner)
        let other: BattleParticipant = owner == .hero ? .companion : .hero
        let draw = attack(id: "drawn")
        if owner == .hero {
            context.heroDeck = CombatDeck(abilities: [draw])
        } else {
            context.companionDeck = CombatDeck(abilities: [draw])
        }
        try play(attack(id: "first"), owner: owner, in: &context)
        try play(attack(id: "other"), owner: other, in: &context)
        let second = try play(attack(id: "second"), owner: owner, in: &context)
        #expect(second.contains { $0.abilityName == "Wrenflight" && $0.effectKind == .cardsDrawn })
        #expect(context.uniques.owners[owner]?.wrenflightDodge == 0.1)
        _ = try context.withAutomaticPlay { context in
            try play(attack(id: "automatic"), owner: owner, in: &context)
        }
        // Automatic plays do not advance the wearer's ordinary card count.
        try #expect(context.uniques.owners[owner]?.cardsPlayed == 2)
        _ = UniqueCombatEngine.startTurn(in: &context)
        #expect(context.uniques.owners[owner]?.wrenflightDodge == 0)
        #expect(context.uniques.owners[owner]?.cardsPlayed == 0)
        // The Returning Gale third-card rule is retired; Dodge-triggered returns are covered
        // by ReturningGaleRegressionTests (ordinary vs automatic, non-damaging, FIFO, no duplicates).
    }

    @Test func `card return uses buffer after draws without deck copy`() throws {
        var context = try battle(["red_harvest"])
        let actor = context.roster.hero.combatant
        context.appendEffect(.bleed(1), to: context.roster.enemy.combatant, sourceID: actor.id, remainingTurns: 2)
        context.heroDeck = CombatDeck(abilities: [attack(id: "drawn")])
        context.hand = BattleHand(cards: [
            BattleCard(id: 90, ability: attack(id: "held1"), owner: .hero),
            BattleCard(id: 91, ability: attack(id: "held2"), owner: .hero),
        ])
        let card = Ability(id: "return", name: "return", tier: .basic, directDamage: 1, effects: [.drawCards(1)])
        try play(card, in: &context)
        #expect(context.hand.cards.map(\.ability.id) == ["held1", "held2", "drawn"])
        #expect(context.hand.buffer.map(\.ability.id) == ["return"])
        #expect(context.heroDeck.isEmpty)
    }

    // The Returning Flight turn-start recovery rule is retired (replaced by immediate
    // first-Physical return). Coverage survives in ReturningGaleRegressionTests
    // (`flight returns first physical once and moves without deck cycle`,
    // `gale and flight together do not duplicate`).

    // The Patient Edge partner-damage rule is retired (replaced by Block-prepares-Crit).
    // Coverage survives in KeywordCohesionMechanicsTests
    // (`patient edge block prepares crit and refreshes`).

    @Test func `threefold grace uses each matching element once without drawing resolving card`() throws {
        var context = try battle(["threefold_grace"])
        context.heroDeck = CombatDeck(abilities: [attack(id: "a"), attack(id: "b"), attack(id: "c")])
        let mixed = Ability(
            id: "mixed",
            name: "mixed",
            tier: .basic,
            damageComponents: [
                DamageComponent(1, keyword: .burn),
                DamageComponent(1, keyword: .freeze),
                DamageComponent(1, keyword: .holy),
            ],
            criticalChanceBonus: -1,
        )
        let events = try play(mixed, in: &context)
        #expect(events.count(where: { $0.abilityName == "Threefold Grace" && $0.effectKind == .cardsDrawn }) == 3)
        #expect(context.hand.cards.map(\.ability.id) == ["a", "b", "c"])
        #expect(context.heroDeck.abilities.map(\.id) == ["mixed"])
        let next = try play(mixed, in: &context)
        #expect(!next.contains { $0.abilityName == "Threefold Grace" })
    }

    @Test(
        arguments: [
            CombatantFixtures.deterministicBattleSeed,
            CombatantFixtures.deterministicBattleSeedVariant(1),
        ],
        [false, true],
    )
    func `cinderbloom spends only resolved element allowances`(seed: UInt64, automatic: Bool) throws {
        var context = try battle(["threefold_grace", "wildhearts_favor"])
        context.rng = SeededRandomNumberGenerator(seed: seed)
        context.uniques.owners[.hero, default: .init()].wildheartReady = true
        context.heroDeck = CombatDeck(abilities: [attack(id: "drawn")])
        let events: [ActionEvent] = if automatic {
            try context.withAutomaticPlay { context in try play(.cinderbloom, in: &context) }
        } else {
            try play(.cinderbloom, in: &context)
        }
        let hit = try #require(events.first { $0.kind == .abilityDamage && $0.abilityID == "cinderbloom" })
        let draws = events.count { $0.abilityName == "Threefold Grace" && $0.effectKind == .cardsDrawn }
        #expect(draws == (!automatic && hit.keyword == .burn ? 1 : 0))
        #expect(context.uniques.owners[.hero]?.usedElements == (!automatic && hit.keyword == .burn ? [.burn] : []))
        #expect(context.uniques.owners[.hero]?.wildheartReady == (automatic || hit.keyword != .poison))
        if !automatic {
            #expect(hit.isCritical == (hit.keyword == .poison))
        }
    }

    @Test func `draw and play does not spend unique card allowances`() throws {
        var context = try battle(["wrenflight", "the_returning_gale", "threefold_grace"])
        context.heroDeck = CombatDeck(abilities: [attack(.holy, id: "auto")])
        let ability = Ability(id: "draw", name: "draw", tier: .basic, effects: [.drawAndPlayCards(1)])
        try play(ability, in: &context)
        #expect(context.uniques.owners[.hero]?.cardsPlayed == 1)
        #expect(context.uniques.owners[.hero]?.usedElements.isEmpty == true)
        #expect(context.hand.isEmpty)
    }

    @Test(arguments: [false, true])
    func `attack returns use resolved random outcome`(dealsDamage: Bool) throws {
        var context = try battle(["red_harvest", "the_returning_flight"])
        context.appendEffect(
            .bleed(1),
            to: context.roster.enemy.combatant,
            sourceID: context.roster.hero.id,
            remainingTurns: 2,
        )
        let branch = dealsDamage
            ? AbilityOutcomeBranch(damageComponents: [DamageComponent(1, keyword: .holy)])
            : AbilityOutcomeBranch(effects: [.instantHeal(.health, 1)])
        let ability = Ability(id: "random", name: "Random", tier: .basic, outcomeBranches: [branch])
        try play(ability, in: &context)
        // Red Harvest returns damaging attacks vs Bleeding immediately (any damage, including Holy).
        // The Returning Flight returns only Physical cards (Holy does not qualify).
        #expect(context.hand.cards.contains { $0.ability.id == "random" } == dealsDamage)
        #expect((context.uniques.owners[.hero]?.returnedFlightThisTurn ?? false) == false)
    }

    @Test(arguments: ["red_harvest", "the_returning_flight"])
    func `damage effect cards qualify for attack card recovery`(itemID: String) throws {
        var context = try battle([itemID])
        context.appendEffect(.bleed(1), to: context.roster.enemy.combatant, sourceID: context.roster.hero.id, remainingTurns: 2)
        let card = Ability.blizzard
        try play(card, in: &context)
        if itemID == "the_returning_flight" {
            // The Returning Flight returns only Physical cards; Blizzard (Freeze) cycles to the deck.
            #expect(context.hand.isEmpty)
            #expect(context.heroDeck.abilities.map(\.id) == [card.id])
        } else {
            // Red Harvest returns damaging attacks vs Bleeding (including Freeze damage effects) immediately.
            #expect(context.hand.cards.map(\.ability.id) == [card.id])
            #expect(context.heroDeck.isEmpty)
        }
    }
}
