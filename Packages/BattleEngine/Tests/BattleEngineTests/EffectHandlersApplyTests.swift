import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct EffectHandlersApplyTests {
    // MARK: - DoT handlers

    @Test func burnHandlerAppliesBurnEffect() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let enemy = battle.enemy
        let outcome = EffectHandlersTestSupport.dispatch(
            .burn(3),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: enemy,
            battle: &battle
        )
        try #expect(outcome.didApply)
        try #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect.isDecayingDoT && $0.keyword == .burn })
    }

    @Test func burnHandlerSkipsInitialDamageWhenPaired() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let enemy = battle.enemy
        let hero = battle.hero
        let action = ActionApplyContext(pairedDirectDamage: [(.burn, 3)])
        let outcome: EffectApplyOutcome = try battle.withEngineContext { context in
            try #require(EffectHandlers.all[.burn]?.apply(
                .burn(3),
                ability: CombatantFixtures.ability(),
                source: hero,
                target: enemy,
                action: action,
                in: &context
            ))
        }
        try #expect(outcome.didApply)
        // No `events` containing a status DoT damage entry.
        try #expect(!(outcome.events.contains { $0.kind == .status && $0.keyword == .burn }))
    }

    // MARK: - Defensive buffs

    @Test(arguments: [
        Effect.shield(.block, 5),
        .standardLeechBuff,
    ])
    func defensiveBuffHandlersApplyAndEmitEvents(effect: Effect) throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(
            effect,
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        try #expect(outcome.didApply)

        switch effect {
        case .shield(.block, 5):
            try #expect(battle.activeEffects(of: battle.hero).contains { ae in
                if case .shield(.block, 5) = ae.effect {
                    return true
                }
                return false
            })
            try #expect(outcome.events.contains { $0.effectKind == .shieldApplied && $0.amount == 5 })
        case .standardLeechBuff:
            try #expect(battle.activeEffects(of: battle.hero).contains {
                $0.effect.keyword == .leech && !$0.effect.isInstant
            })
            try #expect(outcome.events.contains { $0.effectKind == .leechApplied })
        default:
            Issue.record("Unexpected defensive buff \(effect)")
        }
    }

    @Test func leechHandlerReplacesExistingLeechInsteadOfStacking() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        _ = EffectHandlersTestSupport.dispatch(
            .standardLeechBuff,
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(
            .standardLeechBuff,
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        try #expect(outcome.didApply)
        let leechStacks = battle.activeEffects(of: battle.hero).filter { $0.effect.keyword == .leech }
        try #expect(leechStacks.count == 1)
    }

    @Test func drawCardsHandlerDrawsIntoHandAndEmitsEvent() throws {
        var battle = EffectHandlersTestSupport.makeBattle(
            hero: Combatant(
                id: "hero",
                name: "Hero",
                role: .hero,
                maxHealth: 50,
                abilities: [.slash, .heal, .smite, .darkPact]
            )
        )
        // Loadouts hold at most one card per tier (basic/skill/ultimate), so
        // this hero's real deck is only 2 cards and the opening hand draw
        // may exhaust it. Pad the deck so this handler-level test can exercise
        // a full 2-card draw independent of that capacity limit.
        battle.heroDeck.putOnBottom(.smite)
        battle.heroDeck.putOnBottom(.heal)
        // Leave room in hand so both draws land visibly (not in the buffer).
        while battle.hand.count > 1 {
            _ = battle.hand.remove(id: battle.hand.cards[0].id)
        }
        let handBefore = battle.hand.count
        let outcome = EffectHandlersTestSupport.dispatch(
            .drawCards(2),
            ability: .darkPact,
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        try #expect(outcome.didApply)
        try #expect(battle.hand.count == handBefore + 2)
        try #expect(battle.handBuffer.isEmpty)
        try #expect(outcome.events.contains { $0.effectKind == .cardsDrawn && $0.amount == 2 })
    }

    @Test func drawCardsHandlerOverflowGoesToBuffer() throws {
        var battle = EffectHandlersTestSupport.makeBattle(
            hero: Combatant(
                id: "hero",
                name: "Hero",
                role: .hero,
                maxHealth: 50,
                abilities: [.slash, .heal, .smite]
            )
        )
        battle.heroDeck.putOnBottom(.smite)
        battle.heroDeck.putOnBottom(.heal)
        while battle.hand.count < BattleHand.maxSize {
            battle.nextCardID += 1
            battle.hand.append(BattleCard(id: battle.nextCardID, ability: .slash, owner: .hero))
        }
        try #expect(battle.handBuffer.isEmpty)

        let outcome = EffectHandlersTestSupport.dispatch(
            .drawCards(2),
            ability: .darkPact,
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        try #expect(outcome.didApply)
        try #expect(battle.hand.count == BattleHand.maxSize)
        try #expect(battle.handBuffer.count == 2)
        try #expect(outcome.events.contains { $0.effectKind == .cardsDrawn && $0.amount == 2 })
    }

    @Test func cleanseWithoutDebuffsDoesNotApply() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(
            .cleanse(.poison),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        try #expect(!(outcome.didApply))
        try #expect(outcome.events.isEmpty)
    }

    // MARK: - Restoration

    @Test func resourceGainHandlerAddsGold() throws {
        var battle = EffectHandlersTestSupport.makeBattle(initialGold: 10)
        let resourceEffect: Effect = .resourceGain(.gold, 3)
        let outcome = EffectHandlersTestSupport.dispatch(
            resourceEffect,
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        try #expect(outcome.didApply)
        try #expect(battle.gold == 13)
        try #expect(outcome.events.contains { $0.effectKind == .resourceGain && $0.amount == 3 })
    }
}
