import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ReturningGaleRegressionTests {
    private func battle(
        _ ids: [String],
        owner: BattleParticipant = .hero,
        heroDeck: [Ability] = [],
        companionDeck: [Ability] = [],
    ) throws -> BattleState {
        var profile = CombatModifierProfile.zero
        for id in ids {
            let item = try #require(GameContent.unique(matching: id))
            let signature = try #require(item.affixPowers?.first)
            profile.merge(signature.modifiers)
            signature.triggers.apply(to: &profile)
        }
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 200, maxMana: 12),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 200, maxMana: 12),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 2000),
            heroModifiers: owner == .hero ? profile : .zero,
            companionModifiers: owner == .companion ? profile : .zero,
        )
        context.appliesFightPacing = false
        if !heroDeck.isEmpty {
            context.heroDeck = CombatDeck(abilities: heroDeck)
        }
        if !companionDeck.isEmpty {
            context.companionDeck = CombatDeck(abilities: companionDeck)
        }
        return context
    }

    private func attack(id: String = "strike", keyword: Keyword = .physical) -> Ability {
        Ability(id: id, name: id, tier: .basic, directDamage: 2, damageKeyword: keyword, criticalChanceBonus: -1)
    }

    private func support(id: String) -> Ability {
        Ability(id: id, name: id, tier: .basic, effects: [.shield(.block, 1)])
    }

    @discardableResult
    private func play(_ ability: Ability, owner: BattleParticipant, in context: inout BattleState) throws -> [ActionEvent] {
        let card = BattleCardCombatEngine.deal(ability, owner: owner, context: &context)
        return try BattleCardCombatEngine.playDrawnCard(card, context: &context)
    }

    // 1-5: Play ordinary card, end turn, Dodge during enemy turn, assert return from deck
    // without another copy, complete turn, assert retained in hand/buffer.
    @Test func `gale dodge returns last ordinary play across enemy turn`() throws {
        var context = try battle(
            ["the_returning_gale"],
            heroDeck: [attack(id: "other")],
        )
        // 1. Play an ordinary card (goes to deck bottom, tracked as last ordinary).
        try play(attack(id: "played"), owner: .hero, in: &context)
        try #require(context.uniques.owners[.hero]?.lastOrdinaryAbility?.id == "played")
        // 2. Force the wearer to Dodge during the enemy turn.
        context.prependEffect(.evadeNextHit, to: context.hero, sourceID: context.hero.id, remainingTurns: 0)
        let heroDeckBefore = context.heroDeck.abilities.map(\.id)
        try #require(heroDeckBefore.contains("played"))
        _ = BattleTurnEngine.performAction(
            ability: attack(id: "enemy-hit"), actor: context.enemy,
            abilityTarget: context.hero, context: &context,
        )
        // 3. Same ability returns from deck, no copy remains in deck.
        try #expect((context.hand.cards + context.hand.buffer).contains { $0.owner == .hero && $0.ability.id == "played" })
        try #expect(!context.heroDeck.abilities.contains { $0.id == "played" })
        // 4. Complete enemy turn, state resets, normal next-turn draws.
        _ = BattleCardCombatEngine.endTurnWithoutDraw(context: &context)
        _ = BattleCardCombatEngine.drawNextTurnStartCard(context: &context)
        _ = BattleCardCombatEngine.finalizeTurnStart(context: &context)
        // 5. Returned ability remains available in visible hand or buffer.
        try #expect((context.hand.cards + context.hand.buffer).contains { $0.owner == .hero && $0.ability.id == "played" })
    }

    // 6: Full hand + buffered cards preserves FIFO, no loss, later promotion.
    @Test func `gale return respects full hand fifo and promotes later`() throws {
        var context = try battle(
            ["the_returning_gale"],
            heroDeck: [attack(id: "played")],
        )
        try play(attack(id: "played"), owner: .hero, in: &context)
        // Fill visible hand (3) + buffer with existing cards.
        context.hand = BattleHand(cards: [
            BattleCard(id: 101, ability: attack(id: "held1"), owner: .hero),
            BattleCard(id: 102, ability: attack(id: "held2"), owner: .hero),
            BattleCard(id: 103, ability: attack(id: "held3"), owner: .hero),
        ])
        _ = BattleCardCombatEngine.deal(attack(id: "buffered"), owner: .hero, context: &context)
        try #require(context.hand.buffer.map(\.ability.id) == ["buffered"])
        context.prependEffect(.evadeNextHit, to: context.hero, sourceID: context.hero.id, remainingTurns: 0)
        _ = BattleTurnEngine.performAction(
            ability: attack(id: "enemy-hit"), actor: context.enemy,
            abilityTarget: context.hero, context: &context,
        )
        // Returned card enters buffer FIFO (no overflow loss), visible hand unchanged.
        try #expect(context.hand.cards.map(\.ability.id) == ["held1", "held2", "held3"])
        try #expect(context.hand.buffer.map(\.ability.id) == ["buffered", "played"])
        // Later promotion when a slot opens preserves order.
        _ = context.hand.remove(id: 101)
        _ = BattleCardCombatEngine.promoteNextFromBuffer(context: &context)
        try #expect(context.hand.cards.map(\.ability.id) == ["held2", "held3", "buffered"])
        try #expect(context.hand.buffer.map(\.ability.id) == ["played"])
    }

    // 7: Repeat Dodge before replaying does not duplicate.
    @Test func `gale repeated dodge creates no duplicate`() throws {
        var context = try battle(
            ["the_returning_gale"],
            heroDeck: [attack(id: "other")],
        )
        try play(attack(id: "played"), owner: .hero, in: &context)
        for _ in 0 ..< 2 {
            context.prependEffect(.evadeNextHit, to: context.hero, sourceID: context.hero.id, remainingTurns: 0)
            _ = BattleTurnEngine.performAction(
                ability: attack(id: "enemy-hit"), actor: context.enemy,
                abilityTarget: context.hero, context: &context,
            )
        }
        let copies = (context.hand.cards + context.hand.buffer).count(where: { $0.owner == .hero && $0.ability.id == "played" })
            + context.heroDeck.abilities.count(where: { $0.id == "played" })
        try #expect(copies == 1)
    }

    @Test func `gale ignores no prior play held absent and restrictions`() throws {
        // No prior play -> Dodge does nothing.
        var context = try battle(["the_returning_gale"])
        context.prependEffect(.evadeNextHit, to: context.hero, sourceID: context.hero.id, remainingTurns: 0)
        _ = BattleTurnEngine.performAction(
            ability: attack(id: "enemy-hit"), actor: context.enemy,
            abilityTarget: context.hero, context: &context,
        )
        try #expect(context.hand.totalCount == 0)
        // Already held -> do nothing (no duplicate).
        context = try battle(["the_returning_gale"], heroDeck: [attack(id: "played")])
        try play(attack(id: "played"), owner: .hero, in: &context)
        _ = BattleCardCombatEngine.deal(attack(id: "played"), owner: .hero, context: &context)
        let totalBefore = context.hand.totalCount + context.heroDeck.count
        context.prependEffect(.evadeNextHit, to: context.hero, sourceID: context.hero.id, remainingTurns: 0)
        _ = BattleTurnEngine.performAction(
            ability: attack(id: "enemy-hit"), actor: context.enemy,
            abilityTarget: context.hero, context: &context,
        )
        try #expect(context.hand.totalCount + context.heroDeck.count == totalBefore)
        // Absent from deck (already consumed) is covered by repeated dodge above.
        // A stunned owner cannot draw, so Dodge creates no additional copy.
        context = try battle(["the_returning_gale"], heroDeck: [attack(id: "played")])
        try play(attack(id: "played"), owner: .hero, in: &context)
        context.appendEffect(.controlMeter(.stun, 10, 5), to: context.hero, sourceID: context.enemy.id, remainingTurns: 2)
        context.prependEffect(.evadeNextHit, to: context.hero, sourceID: context.hero.id, remainingTurns: 0)
        _ = BattleTurnEngine.performAction(
            ability: attack(id: "enemy-hit"), actor: context.enemy,
            abilityTarget: context.hero, context: &context,
        )
        let copies = (context.hand.cards + context.hand.buffer).count(where: { $0.ability.id == "played" })
            + context.heroDeck.abilities.count(where: { $0.id == "played" })
        try #expect(copies <= 2)
    }

    @Test func `gale and flight together do not duplicate`() throws {
        var context = try battle(
            ["the_returning_gale", "the_returning_flight"],
            heroDeck: [attack(id: "other")],
        )
        // First Physical card returns immediately via Flight (to hand, not deck).
        try play(attack(id: "played", keyword: .physical), owner: .hero, in: &context)
        try #expect((context.hand.cards + context.hand.buffer).contains { $0.ability.id == "played" })
        // Dodge later finds already held, does nothing (no duplicate).
        context.prependEffect(.evadeNextHit, to: context.hero, sourceID: context.hero.id, remainingTurns: 0)
        _ = BattleTurnEngine.performAction(
            ability: attack(id: "enemy-hit"), actor: context.enemy,
            abilityTarget: context.hero, context: &context,
        )
        let copies = (context.hand.cards + context.hand.buffer).count(where: { $0.ability.id == "played" })
            + context.heroDeck.abilities.count(where: { $0.id == "played" })
        try #expect(copies == 1)
    }

    @Test func `flight returns first physical once and moves without deck cycle`() throws {
        var context = try battle(
            ["the_returning_flight"],
            heroDeck: [attack(id: "other")],
        )
        let deckBefore = context.heroDeck.count
        try play(attack(id: "played", keyword: .physical), owner: .hero, in: &context)
        // Returned to hand (not cycled to deck): deck unchanged (still has "other", no "played" added).
        try #expect((context.hand.cards + context.hand.buffer).contains { $0.ability.id == "played" })
        try #expect(!context.heroDeck.abilities.contains { $0.id == "played" })
        try #expect(context.heroDeck.count == deckBefore)
        try #expect(context.uniques.owners[.hero]?.returnedFlightThisTurn == true)
        // Replaying cannot repeatedly return (allowance claimed).
        let returnedCard = try #require((context.hand.cards + context.hand.buffer).first { $0.ability.id == "played" })
        _ = try BattleCardCombatEngine.playDrawnCard(returnedCard, context: &context)
        try #expect(!(context.hand.cards + context.hand.buffer).contains { $0.ability.id == "played" })
        // Second play cycled to deck (not returned).
        try #expect(context.heroDeck.abilities.contains { $0.id == "played" })
    }

    @Test func `gale tracks non-damaging ordinary but not automatic`() throws {
        var context = try battle(
            ["the_returning_gale"],
            heroDeck: [support(id: "tracked")],
        )
        // Non-damaging ordinary support qualifies (Sniff Out / Predator's Focus style).
        try play(support(id: "tracked"), owner: .hero, in: &context)
        try #expect(context.uniques.owners[.hero]?.lastOrdinaryAbility?.id == "tracked")
        // Automatic abilities do not replace tracked ordinary card.
        _ = try context.withAutomaticPlay { context in
            let card = BattleCardCombatEngine.deal(attack(id: "auto"), owner: .hero, context: &context)
            return try BattleCardCombatEngine.playDrawnCard(card, context: &context)
        }
        try #expect(context.uniques.owners[.hero]?.lastOrdinaryAbility?.id == "tracked")
    }
}
