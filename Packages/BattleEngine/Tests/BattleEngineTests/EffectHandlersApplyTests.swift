import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct EffectHandlersApplyTests {
    @Test func `full Mana cards omit false gains while preserving overflow rewards`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxMana: 8),
            heroMana: 8,
            heroModifiers: .withTriggers { $0.livingConduit = true },
            appliesFightPacing: false,
        )
        let outcome = EffectHandlersTestSupport.dispatch(.resourceGain(.mana, 2), battle: &battle)
        #expect(!outcome.didApply)
        #expect(battle.mana(of: battle.hero) == 8)
        #expect(!outcome.events.contains { $0.effectKind == .resourceGain && $0.keyword == .mana })
        #expect(battle.activeEffects(of: battle.hero).contains { $0.effect == .thorns(2) })
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

    @Test(arguments: [false, true])
    func `draw cards fills available hand space and buffers overflow`(fullHand: Bool) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.heroDeck = CombatDeck(abilities: [.smite, .heal])
        for _ in 0 ..< (fullHand ? BattleHand.maxSize : 1) {
            BattleCardCombatEngine.deal(.slash, owner: .hero, context: &battle)
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
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        for _ in 0 ..< (scenario == .fullHand ? BattleHand.maxSize : 1) {
            BattleCardCombatEngine.deal(.heal, owner: .hero, context: &battle)
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
            .drawAndPlayCards(count), ability: automaticDrawAbility(count), battle: &battle,
        )
        #expect(outcome.didApply)
        #expect(outcome.events.contains { $0.effectKind == .cardsDrawn && $0.amount == count })
        let attack = scenario == .stunnedHero ? Ability.smite : .slash
        #expect(outcome.events.contains { $0.kind == .abilityDamage && $0.abilityName == attack.name })
        if scenario == .alternating {
            #expect(outcome.events.filter { $0.kind == .ability }.map(\.actorID) == [battle.hero.id, battle.companion.id])
        } else if scenario == .fullHand {
            #expect(Set(battle.hand.cards.map(\.id)) == handIDs)
            #expect(battle.hand.buffer.isEmpty)
        } else if scenario == .stunnedHero {
            #expect(outcome.events.contains { $0.kind == .ability && $0.abilityName == Ability.bash.name })
            #expect(battle.heroDeck.count == heroDeckCount)
        }
    }

    private func automaticDrawAbility(_ count: Int) -> Ability {
        Ability(id: "automatic-draw", name: "Automatic Draw", tier: .ultimate, targetedEffects: [TargetedEffect(.drawAndPlayCards(count))])
    }

    @Test(arguments: [false, true])
    func `draw and play cards does not replay nested draw and play forever`(recordsPlayback: Bool) throws {
        let automaticDraw = automaticDrawAbility(2)
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.heroDeck = CombatDeck(abilities: [automaticDraw, automaticDraw, automaticDraw])
        battle.companionDeck = CombatDeck(abilities: [automaticDraw, automaticDraw, automaticDraw])
        let card = BattleCardCombatEngine.deal(automaticDraw, owner: .hero, context: &battle)
        let result = try battle.playCard(cardID: card.id, recordActions: recordsPlayback)

        #expect(result.events.count { $0.kind == .ability && $0.abilityID == automaticDraw.id } == 7)
        #expect(!recordsPlayback || result.playedCards.count == 7)
        #expect(battle.hand.isEmpty)
        #expect(battle.heroDeck.isEmpty && battle.companionDeck.isEmpty)
        #expect(battle.heroDeck.discarded.count == 4 && battle.companionDeck.discarded.count == 3)
        #expect(battle.commandOutput == nil)
        try #expect(battle.resolution.depth(.draw) == 0)
    }

    @Test func `draw and play depth cap does not leave unplayed drawn cards`() throws {
        let automaticDraw = automaticDrawAbility(2)
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.heroDeck = CombatDeck(abilities: [automaticDraw, automaticDraw])
        for _ in 0 ..< (BattleState.maxDrawAndPlayDepth) {
            battle.resolution.enter(.draw)
        }
        let idsBefore = Set(battle.hand.cards.map(\.id)).union(battle.hand.buffer.map(\.id))
        let heroDeckCount = battle.heroDeck.count

        let outcome = EffectHandlersTestSupport.dispatch(
            .drawAndPlayCards(2),
            ability: automaticDraw,
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

extension EffectHandlersApplyTests {
    @Test(arguments: [Effect.burn(2), .poison(2), .bleed(2)])
    func `a lethal damage over time application still reports its committed hit`(effect: Effect) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(enemyMaxHealth: 1, dealOpeningHand: false, appliesFightPacing: false)
        let ability = Ability(
            id: "lethal-dot", name: "Lethal Status", tier: .skill,
            targetedEffects: [TargetedEffect(effect, target: .enemy)],
        )
        let events = battle.performTestAction(ability)
        #expect(battle.isEnemyDefeated)
        #expect(events.last { $0.kind == .ability }?.appliedEffects == [effect])
    }

    @Test(arguments: [Effect.burn(2), .poison(2)])
    func `fully absorbed decaying damage does not report an applied effect`(effect: Effect) {
        var battle = BattleStateTestFactory.makeMinimalBattle(appliesFightPacing: false)
        DefensePoolEngine.set(10, on: battle.enemy, in: &battle)
        let ability = Ability(
            id: "absorbed-dot", name: "Absorbed Status", tier: .skill,
            targetedEffects: [TargetedEffect(effect, target: .enemy)],
        )
        let events = battle.performTestAction(ability)
        #expect(events.last { $0.kind == .ability }?.appliedEffects.isEmpty == true)
        #expect(!battle.activeEffects(of: battle.enemy).contains { $0.effect.isDecayingDoT })
    }

    @Test(arguments: [false, true])
    func `revival restores only a defeated member of the live roster`(registered: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle(companionHealth: 0)
        let target = registered ? battle.companion : CombatantFixtures.passiveCompanion(id: "absent")
        let outcome = EffectHandlersTestSupport.dispatch(.revive(5), target: target, battle: &battle)
        #expect(outcome.didApply == registered)
        #expect(battle.health(of: battle.companion) == (registered ? 5 : 0))
        #expect(outcome.events.map(\.amount) == (registered ? [5] : []))
    }

    @Test(arguments: [
        (Effect.burn(Int.max), Effect.multiplyDoT(.burn, 2)),
        (.thorns(Int.max), .thorns(1)),
        (.nextBurnBonus(Int.max), .nextBurnBonus(1)),
    ])
    func `capped status grants emit no false growth`(existing: Effect, grant: Effect) {
        var battle = BattleStateTestFactory.makeMinimalBattle(appliesFightPacing: false)
        battle.insertEffect(existing, to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
        let before = battle.activeEffects(of: battle.hero)
        let outcome = EffectHandlersTestSupport.dispatch(grant, battle: &battle)
        #expect(!outcome.didApply)
        #expect(outcome.events.isEmpty)
        #expect(battle.activeEffects(of: battle.hero) == before)
    }
}
