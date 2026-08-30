import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct EffectHandlersApplyTests {
    @Test func registryCoversEveryEffectKind() throws {
        try #expect(Set(EffectHandlers.all.keys) == Set(EffectKind.allCases))
        for kind in EffectKind.allCases {
            let handler = try #require(EffectHandlers.all[kind], "Missing handler for \(kind)")
            try #expect(handler.kind == kind)
            try #expect(EffectHandlers.handler(for: kind)?.kind == kind)
        }
    }

    @Test func everyAbilityCatalogEffectHasAHandler() throws {
        for ability in AbilityCatalog.all {
            for effect in Self.effects(in: ability) {
                try #expect(
                    EffectHandlers.all[effect.kind] != nil,
                    "\(ability.id) is missing a handler for \(effect.kind)"
                )
            }
        }
    }

    private static func effects(in ability: Ability) -> [Effect] {
        var result = ability.effects
        if let branches = ability.outcomeBranches {
            for branch in branches {
                result.append(contentsOf: branch.targetedEffects.map(\.effect))
            }
        }
        return result
    }

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

    @Test func shieldHandlerAppliesAndEmitsEvents() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(
            .shield(.block, 5),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        try #expect(outcome.didApply)
        try #expect(battle.activeEffects(of: battle.hero).contains { ae in
            if case .shield(.block, 5) = ae.effect {
                return true
            }
            return false
        })
        try #expect(outcome.events.contains { $0.effectKind == .shieldApplied && $0.amount == 5 })
    }

    @Test func drawCardsHandlerDrawsIntoHandAndEmitsEvent() throws {
        var battle = EffectHandlersTestSupport.makeBattle(
            hero: CombatantFixtures.combatant(
                id: "hero",
                role: .hero,
                maxHealth: 50,
                abilities: [.slash, .heal, .smite, .darkPact]
            )
        )
        battle.heroDeck.putOnBottom(.smite)
        battle.heroDeck.putOnBottom(.heal)
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

    @Test func drawAndPlayCardsHandlerDrawsAndPlaysHeroAndCompanionCards() throws {
        var battle = EffectHandlersTestSupport.makeBattle(
            hero: CombatantFixtures.combatant(
                id: "hero",
                role: .hero,
                maxHealth: 50,
                abilities: [.slash, .heal]
            ),
            companion: CombatantFixtures.combatant(
                id: "companion",
                role: .companion,
                maxHealth: 50,
                abilities: [.smite]
            )
        )
        while battle.hand.count > 1 {
            _ = battle.hand.remove(id: battle.hand.cards[0].id)
        }
        battle.heroDeck = CombatDeck(abilities: [.slash])
        battle.companionDeck = CombatDeck(abilities: [.smite])

        let packTactics = Ability(
            id: "pack-tactics",
            name: "Pack Tactics",
            tier: .ultimate,
            targetedEffects: [TargetedEffect(.drawAndPlayCards(2))]
        )

        let outcome = EffectHandlersTestSupport.dispatch(
            .drawAndPlayCards(2),
            ability: packTactics,
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )

        try #expect(outcome.didApply)
        try #expect(outcome.events.contains { $0.effectKind == .cardsDrawn && $0.amount == 2 })
        try #expect(outcome.events.contains { $0.kind == .abilityDamage })
    }

    @Test func drawAndPlayCardsHandlerPlaysBufferedCardWhenHandIsFull() throws {
        var battle = EffectHandlersTestSupport.makeBattle(
            hero: CombatantFixtures.combatant(
                id: "hero",
                role: .hero,
                maxHealth: 50,
                abilities: [.heal]
            ),
            companion: CombatantFixtures.combatant(
                id: "companion",
                role: .companion,
                maxHealth: 50,
                abilities: []
            )
        )
        while battle.hand.count < BattleHand.maxSize {
            battle.nextCardID += 1
            battle.hand.append(BattleCard(id: battle.nextCardID, ability: .heal, owner: .hero))
        }
        let preexistingHandIDs = Set(battle.hand.cards.map(\.id))
        battle.heroDeck = CombatDeck(abilities: [.slash])
        battle.companionDeck = CombatDeck()

        let packTactics = Ability(
            id: "pack-tactics",
            name: "Pack Tactics",
            tier: .ultimate,
            targetedEffects: [TargetedEffect(.drawAndPlayCards(1))]
        )

        let outcome = EffectHandlersTestSupport.dispatch(
            .drawAndPlayCards(1),
            ability: packTactics,
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )

        try #expect(outcome.didApply)
        try #expect(outcome.events.contains { $0.effectKind == .cardsDrawn && $0.amount == 1 })
        try #expect(outcome.events.contains {
            $0.kind == .abilityDamage && $0.abilityName == Ability.slash.name
        })
        try #expect(Set(battle.hand.cards.map(\.id)) == preexistingHandIDs)
        try #expect(battle.handBuffer.isEmpty)
    }

    @Test func drawAndPlayCardsHandlerSkipsStunnedOwnerAndPlaysCompanion() throws {
        var battle = EffectHandlersTestSupport.makeBattle(
            hero: CombatantFixtures.combatant(
                id: "hero",
                role: .hero,
                maxHealth: 50,
                abilities: [.slash]
            ),
            companion: CombatantFixtures.combatant(
                id: "companion",
                role: .companion,
                maxHealth: 50,
                abilities: [.smite]
            )
        )
        while battle.hand.count > 1 {
            _ = battle.hand.remove(id: battle.hand.cards[0].id)
        }
        battle.withEngineContext { context in
            context.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0)],
                for: context.hero
            )
        }
        battle.ownersSkippingThisPlayerTurn = [.hero]
        battle.heroDeck = CombatDeck(abilities: [.slash])
        battle.companionDeck = CombatDeck(abilities: [.smite, .bash])
        let heroDeckCount = battle.heroDeck.count

        let outcome = EffectHandlersTestSupport.dispatch(
            .drawAndPlayCards(2),
            ability: Ability(
                id: "pack-tactics",
                name: "Pack Tactics",
                tier: .ultimate,
                targetedEffects: [TargetedEffect(.drawAndPlayCards(2))]
            ),
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )

        try #expect(outcome.didApply)
        try #expect(outcome.events.contains { $0.effectKind == .cardsDrawn && $0.amount == 1 })
        try #expect(outcome.events.contains {
            $0.kind == .abilityDamage && $0.abilityName == Ability.smite.name
        })
        try #expect(!(outcome.events.contains { $0.kind == .ability && $0.abilityName == Ability.bash.name }))
        try #expect(battle.heroDeck.count == heroDeckCount)
    }

    @Test func drawAndPlayCardsDoesNotReplayNestedDrawAndPlayForever() throws {
        let packTactics = Ability(
            id: "pack-tactics",
            name: "Pack Tactics",
            tier: .ultimate,
            targetedEffects: [TargetedEffect(.drawAndPlayCards(2))]
        )
        var battle = EffectHandlersTestSupport.makeBattle(
            hero: CombatantFixtures.combatant(
                id: "hero",
                role: .hero,
                maxHealth: 50,
                abilities: [packTactics]
            ),
            companion: CombatantFixtures.combatant(
                id: "companion",
                role: .companion,
                maxHealth: 50,
                abilities: [packTactics]
            )
        )
        while battle.hand.count > 1 {
            _ = battle.hand.remove(id: battle.hand.cards[0].id)
        }
        battle.heroDeck = CombatDeck(abilities: [packTactics, packTactics, packTactics])
        battle.companionDeck = CombatDeck(abilities: [packTactics, packTactics, packTactics])

        let outcome = EffectHandlersTestSupport.dispatch(
            .drawAndPlayCards(2),
            ability: packTactics,
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )

        try #expect(outcome.didApply)
        try #expect(battle.drawAndPlayDepth == 0)
    }

    @Test func drawAndPlayDepthCapDoesNotLeaveUnplayedDrawnCards() throws {
        let packTactics = Ability(
            id: "pack-tactics",
            name: "Pack Tactics",
            tier: .ultimate,
            targetedEffects: [TargetedEffect(.drawAndPlayCards(2))]
        )
        var battle = EffectHandlersTestSupport.makeBattle(
            hero: CombatantFixtures.combatant(
                id: "hero",
                role: .hero,
                maxHealth: 50,
                abilities: [packTactics]
            )
        )
        while !battle.hand.isEmpty {
            _ = battle.hand.remove(id: battle.hand.cards[0].id)
        }
        battle.heroDeck = CombatDeck(abilities: [packTactics, packTactics])
        battle.drawAndPlayDepth = BattleState.maxDrawAndPlayDepth
        let idsBefore = Set(battle.hand.cards.map(\.id)).union(battle.handBuffer.cards.map(\.id))
        let heroDeckCount = battle.heroDeck.count

        let outcome = EffectHandlersTestSupport.dispatch(
            .drawAndPlayCards(2),
            ability: packTactics,
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )

        let idsAfter = Set(battle.hand.cards.map(\.id)).union(battle.handBuffer.cards.map(\.id))
        try #expect(!outcome.didApply)
        try #expect(idsAfter == idsBefore)
        try #expect(battle.heroDeck.count == heroDeckCount)
        try #expect(battle.drawAndPlayDepth == BattleState.maxDrawAndPlayDepth)
    }

    @Test func drawCardsHandlerOverflowGoesToBuffer() throws {
        var battle = EffectHandlersTestSupport.makeBattle(
            hero: CombatantFixtures.combatant(
                id: "hero",
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
