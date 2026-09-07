import Testing
import TrinketContent
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
    func `wrenflight and gale count only wearers ordinary cards`(owner: BattleParticipant) throws {
        var context = try battle(["wrenflight", "the_returning_gale"], owner: owner)
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
        context.isResolvingAutoPlayCard = true
        try play(attack(id: "automatic"), owner: owner, in: &context)
        context.isResolvingAutoPlayCard = false
        let third = try play(attack(.holy, id: "third"), owner: owner, in: &context)
        #expect(third.contains { $0.abilityName == "The Returning Gale" })
        #expect(context.hand.cards.contains { $0.ability.id == "third" })
        let fourth = try play(attack(id: "fourth"), owner: owner, in: &context)
        #expect(!fourth.contains { $0.abilityName == "The Returning Gale" })
        #expect(context.uniques.owners[owner]?.cardsPlayed == 4)
        _ = UniqueCombatEngine.startTurn(in: &context)
        #expect(context.uniques.owners[owner]?.wrenflightDodge == 0)
        #expect(context.uniques.owners[owner]?.cardsPlayed == 0)
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

    @Test func `returning flight recovers before ordinary turn draws`() throws {
        var context = try battle(["the_returning_flight"])
        let strike = attack(id: "last")
        context.heroDeck = CombatDeck(abilities: [attack(id: "ordinary")])
        try play(strike, in: &context)
        let events = BattleCardCombatEngine.endTurnWithoutDraw(context: &context)
        #expect(events.contains { $0.abilityName == "The Returning Flight" })
        #expect(context.hand.cards.map(\.ability.id) == ["last"])
        #expect(context.heroDeck.abilities.map(\.id) == ["ordinary"])
        #expect(BattleCardCombatEngine.drawNextTurnStartCard(context: &context))
        #expect(context.hand.cards.map(\.ability.id) == ["last", "ordinary"])
        _ = BattleCardCombatEngine.finalizeTurnStart(context: &context)
        #expect(context.uniques.owners[.hero]?.lastAttack == nil)
    }

    @Test func `returning flight does not duplicate harvest return or missing card`() throws {
        for inHand in [true, false] {
            var context = try battle(["the_returning_flight", "red_harvest"])
            context.appendEffect(.bleed(1), to: context.roster.enemy.combatant, sourceID: context.roster.hero.id, remainingTurns: 2)
            try play(attack(id: "last"), in: &context)
            if !inHand {
                context.hand = BattleHand()
            }
            let count = context.hand.totalCount
            let events = UniqueCombatEngine.startTurn(in: &context)
            #expect(events.isEmpty)
            #expect(context.hand.totalCount == count)
        }
    }

    @Test func `patient edge counts owned visible and buffered cards for one hit`() throws {
        var context = try battle(["the_patient_edge"])
        context.hand = BattleHand(
            cards: [BattleCard(id: 91, ability: attack(), owner: .hero), BattleCard(id: 92, ability: attack(), owner: .companion)],
            buffer: [BattleCard(id: 93, ability: attack(), owner: .hero)],
        )
        _ = BattleCardCombatEngine.endTurnWithoutDraw(context: &context)
        #expect(context.uniques.owners[.hero]?.heldCardDamage == 4)
        let ability = Ability(
            id: "two",
            name: "two",
            tier: .basic,
            damageComponents: [DamageComponent(10, keyword: .holy), DamageComponent(10, keyword: .physical)],
            criticalChanceBonus: -1,
        )
        let before = context.roster.enemy.currentHealth
        try play(ability, in: &context)
        #expect(before - context.roster.enemy.currentHealth == 24)
        try play(attack(), in: &context)
        #expect(before - context.roster.enemy.currentHealth == 34)
    }

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
        #expect(context.hand.cards.contains { $0.ability.id == "random" } == dealsDamage)
        #expect((context.uniques.owners[.hero]?.lastAttack?.id == "random") == dealsDamage)
    }
}
