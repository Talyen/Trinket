import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct EffectHandlersApplyTests {
    private func drawBattle(heroAbilities: [Ability], companionAbilities: [Ability]? = nil) -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50, abilities: heroAbilities),
            companion: companionAbilities.map {
                CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 50, abilities: $0)
            },
        )
    }

    @Test(arguments: [false, true])
    func `companion auto play draws its own card even after hero defeat`(heroDefeated: Bool) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.heroDeck = CombatDeck(abilities: [.block])
        battle.companionDeck = CombatDeck(abilities: [.smite])
        if heroDefeated {
            battle.roster.hero.currentHealth = 0
        }
        let outcome = EffectHandlersTestSupport.dispatch(
            .drawAndPlayCards(1), source: battle.companion, target: battle.companion, battle: &battle,
        )
        #expect(outcome.didApply)
        #expect(outcome.events.contains { $0.kind == .ability && $0.actorID == battle.companion.id && $0.abilityID == Ability.smite.id })
        #expect(!outcome.events.contains { $0.kind == .ability && $0.actorID == battle.hero.id })
    }

    @Test func `Pack Tactics can draw an ally's currently unaffordable card`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.roster.companion.currentHealth = 1
        battle.heroDeck = CombatDeck(abilities: [.block])
        battle.companionDeck = CombatDeck(abilities: [.darkPact])

        let outcome = EffectHandlersTestSupport.dispatch(
            .drawCards(1), ability: .packTactics, battle: &battle,
        )

        #expect(outcome.didApply)
        #expect(battle.hand.cards.contains { $0.owner == .companion && $0.ability.id == Ability.darkPact.id })
        #expect(battle.heroDeck.abilities.count == 1)
        #expect(battle.companionDeck.abilities.isEmpty)
    }

    @Test(arguments: [(Effect.burn(3), BattleParticipant.enemy), (.shield(.block, 5), .hero)])
    func `basic status handlers apply their effect`(effect: Effect, recipient: BattleParticipant) {
        var battle = BattleStateTestFactory.makeBattle()
        let target = battle.roster[recipient].combatant
        let outcome = EffectHandlersTestSupport.dispatch(effect, target: target, battle: &battle)
        #expect(outcome.didApply)
        #expect(battle.activeEffects(of: target)
            .contains { recipient == .enemy ? $0.effect.isDecayingDoT && $0.keyword == .burn : $0.effect == effect })
        if recipient == .hero {
            #expect(outcome.events.contains { $0.effectKind == .shieldApplied && $0.amount == 5 })
        }
    }

    @Test(arguments: [false, true])
    func `draw cards fills available hand space and buffers overflow`(fullHand: Bool) {
        var battle = drawBattle(heroAbilities: fullHand ? [.slash, .heal, .smite] : [.slash, .heal, .smite, .darkPact])
        battle.heroDeck.putOnBottom(.smite)
        battle.heroDeck.putOnBottom(.heal)
        if fullHand {
            while battle.hand.count < BattleHand.maxSize {
                battle.nextCardID += 1
                battle.hand.append(BattleCard(id: battle.nextCardID, ability: .slash, owner: .hero))
            }
        } else {
            while battle.hand.count > 1 {
                _ = battle.hand.remove(id: battle.hand.cards[0].id)
            }
        }
        #expect(battle.hand.buffer.isEmpty)
        let handBefore = battle.hand.count
        let outcome = EffectHandlersTestSupport.dispatch(.drawCards(2), ability: .darkPact, battle: &battle)
        #expect(outcome.didApply)
        #expect(battle.hand.count == (fullHand ? BattleHand.maxSize : handBefore + 2))
        #expect(battle.hand.bufferCount == (fullHand ? 2 : 0))
        #expect(outcome.events.contains { $0.effectKind == .cardsDrawn && $0.amount == 2 })
    }

    private enum AutomaticDrawScenario: CaseIterable {
        case alternating, fullHand, stunnedHero
    }

    @Test(arguments: AutomaticDrawScenario.allCases)
    private func `automatic draws preserve hand contents and skip controlled owners`(scenario: AutomaticDrawScenario) {
        let (heroAbilities, companionAbilities): ([Ability], [Ability]) = switch scenario {
        case .alternating: ([.slash, .heal], [.bash, .smite])
        case .fullHand: ([.heal], [])
        case .stunnedHero: ([.slash], [.smite])
        }
        var battle = drawBattle(heroAbilities: heroAbilities, companionAbilities: companionAbilities)
        if scenario == .fullHand {
            while battle.hand.count < BattleHand.maxSize {
                battle.nextCardID += 1
                battle.hand.append(BattleCard(id: battle.nextCardID, ability: .heal, owner: .hero))
            }
        } else {
            while battle.hand.count > 1 {
                _ = battle.hand.remove(id: battle.hand.cards[0].id)
            }
        }
        if scenario == .stunnedHero {
            battle.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0)], for: battle.hero,
            )
            battle.ownersSkippingThisPlayerTurn = [.hero]
        }
        let handIDs = Set(battle.hand.cards.map(\.id))
        battle.heroDeck = CombatDeck(abilities: [.slash])
        battle.companionDeck = CombatDeck(abilities: scenario == .fullHand ? [] : scenario == .stunnedHero ? [.smite, .bash] : [.smite])
        let heroDeckCount = battle.heroDeck.count
        let count = scenario == .fullHand ? 1 : 2
        let outcome = EffectHandlersTestSupport.dispatch(
            .drawAndPlayCards(count), ability: scenario == .alternating ? .packTactics : automaticDrawAbility(count), battle: &battle,
        )
        #expect(outcome.didApply)
        #expect(outcome.events.contains { $0.effectKind == .cardsDrawn && $0.amount == count })
        let attack = scenario == .stunnedHero ? Ability.smite : .slash
        #expect(outcome.events.contains { $0.kind == .abilityDamage && $0.abilityName == attack.name })
        if scenario == .fullHand {
            #expect(Set(battle.hand.cards.map(\.id)) == handIDs)
            #expect(battle.hand.buffer.isEmpty)
        } else if scenario == .stunnedHero {
            #expect(outcome.events.contains { $0.kind == .ability && $0.abilityName == Ability.bash.name })
            #expect(battle.heroDeck.count == heroDeckCount)
        }
    }

    private func automaticDrawAbility(_ count: Int) -> Ability {
        Ability(id: "pack-tactics", name: "Pack Tactics", tier: .ultimate, targetedEffects: [TargetedEffect(.drawAndPlayCards(count))])
    }

    @Test(arguments: [false, true])
    func `draw and play cards does not replay nested draw and play forever`(recordsPlayback: Bool) throws {
        let packTactics = automaticDrawAbility(2)
        var battle = drawBattle(heroAbilities: [packTactics], companionAbilities: [packTactics])
        while battle.hand.count > 1 {
            _ = battle.hand.remove(id: battle.hand.cards[0].id)
        }
        battle.heroDeck = CombatDeck(abilities: [packTactics, packTactics, packTactics])
        battle.companionDeck = CombatDeck(abilities: [packTactics, packTactics, packTactics])

        let card = try #require(battle.hand.cards.first)
        let result = try battle.playCard(cardID: card.id, recordActions: recordsPlayback)

        #expect(!result.events.isEmpty)
        #expect(!recordsPlayback || result.playedCards.count > 2)
        #expect(battle.commandOutput == nil)
        try #expect(battle.resolution.depth(.draw) == 0)
    }

    @Test func `draw and play depth cap does not leave unplayed drawn cards`() throws {
        let packTactics = automaticDrawAbility(2)
        var battle = drawBattle(heroAbilities: [packTactics])
        while !battle.hand.isEmpty {
            _ = battle.hand.remove(id: battle.hand.cards[0].id)
        }
        battle.heroDeck = CombatDeck(abilities: [packTactics, packTactics])
        for _ in 0 ..< (BattleState.maxDrawAndPlayDepth) {
            battle.resolution.enter(.draw)
        }
        let idsBefore = Set(battle.hand.cards.map(\.id)).union(battle.hand.buffer.map(\.id))
        let heroDeckCount = battle.heroDeck.count

        let outcome = EffectHandlersTestSupport.dispatch(
            .drawAndPlayCards(2),
            ability: packTactics,
            battle: &battle,
        )

        let idsAfter = Set(battle.hand.cards.map(\.id)).union(battle.hand.buffer.map(\.id))
        try #expect(!outcome.didApply)
        try #expect(idsAfter == idsBefore)
        try #expect(battle.heroDeck.count == heroDeckCount)
        try #expect(battle.resolution.depth(.draw) == BattleState.maxDrawAndPlayDepth)
    }
}

extension EffectHandlersApplyTests {
    @Test(arguments: [(true, 7), (false, 3)])
    func `victory coin grants gold without spending`(winsCoinFlip: Bool, amount: Int) throws {
        let seed = try #require((UInt64(0) ..< 16).first { seed in
            var rng = SeededRandomNumberGenerator(seed: seed)
            return BattleChance.succeeds(probability: 0.5, using: &rng) == winsCoinFlip
        })
        var battle = BattleStateTestFactory.makeBattle(
            initialGold: 10,
            heroModifiers: .withTriggers { $0.victoryGoldCoin = true },
        )
        battle.rng = SeededRandomNumberGenerator(seed: seed)
        let events = battle.recordingEvents { battle in await CombatTriggerEngine.afterVictory(in: &battle) }
        #expect(battle.gold == 10 + amount)
        #expect(battle.goldFlow == BattleGoldFlow(gained: amount))
        #expect(events.contains { $0.effectKind == .resourceGain && $0.amount == amount })
    }
}
