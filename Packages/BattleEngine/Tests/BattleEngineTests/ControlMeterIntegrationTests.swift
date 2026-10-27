import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

struct ControlMeterIntegrationTests {
    @Test func `border accent keeps deaths door priority and first eligible control`() {
        let lingering = ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 1)
        let pending = ActiveEffect(id: 2, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0)
        let door = ActiveEffect(id: 3, effect: .deathsDoor, remainingTurns: 0)
        #expect(CombatantBorderAccent.keyword(from: [lingering, pending]) == .stun)
        #expect(CombatantBorderAccent.keyword(from: [lingering, pending], controlAccentRequiresPendingSkip: true) == .freeze)
        #expect(CombatantBorderAccent.keyword(from: [lingering, pending, door]) == .deathsDoor)
    }

    private func makeControlBattle(
        heroAbilities: [Ability] = [.slash], companionAbilities: [Ability] = [],
        enemyMaxHealth: Int = 100, actionIntervalTurns: Int? = nil,
        activeHeroEffects: [ActiveEffect] = [], activeEnemyEffects: [ActiveEffect] = [],
        heroModifiers: CombatModifierProfile = .zero, dealOpeningHand: Bool = true,
    ) -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(
                id: "hero", role: .hero, actionIntervalTurns: actionIntervalTurns, abilities: heroAbilities,
            ),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, abilities: companionAbilities),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: enemyMaxHealth, abilities: [.slash]),
            activeEnemyEffects: activeEnemyEffects, activeHeroEffects: activeHeroEffects,
            heroModifiers: heroModifiers, dealOpeningHand: dealOpeningHand,
        )
    }

    @Test(arguments: [Keyword.stun, .freeze])
    func `pending control prevents the enemy action and is consumed`(keyword: Keyword) {
        var battle = BattleTestFixtures.partyWithPendingActionSkip(keyword: keyword)
        let hero = battle.hero
        let enemy = battle.enemy
        if keyword == .stun {
            #expect(!battle.activeEffects(of: enemy).isEmpty)
        }
        let events = battle.endTurn().events
        #expect(battle.health(of: hero) == hero.maxHealth)
        #expect(events.contains { $0.effectKind == .controlActionSkipped && $0.keyword == keyword && $0.targetID == enemy.id })
        if keyword == .stun {
            #expect(!events.contains { $0.kind == .ability && $0.actorID == enemy.id })
            #expect(battle.roster.hasControlStatus(for: enemy, keyword: .stun))
            #expect(!battle.roster.hasPendingActionSkip(for: enemy, keyword: .stun))
        }
    }

    @Test func `stun status lingers through following player turn without second skip`() throws {
        var battle = BattleTestFixtures.partyWithPendingActionSkip(keyword: .stun)
        let enemy = battle.enemy
        let hero = battle.hero

        let firstEnd = battle.endTurn().events
        #expect(firstEnd.contains {
            $0.effectKind == .controlActionSkipped && $0.keyword == .stun && $0.targetID == enemy.id
        })
        try #expect(battle.roster.hasControlStatus(for: enemy, keyword: .stun))
        try #expect(CombatantBorderAccent.keyword(from: battle.activeEffects(of: enemy)) == .stun)
        try #expect(battle.health(of: hero) == hero.maxHealth)

        try #expect(!(battle.roster.hasPendingActionSkip(for: enemy)))

        let secondEnd = battle.endTurn().events
        try #expect(!(secondEnd.contains(effectKind: .controlActionSkipped, keyword: .stun)))
        try #expect(secondEnd.contains { $0.kind == .ability && $0.actorID == enemy.id })
        try #expect(!(battle.roster.hasControlStatus(for: enemy, keyword: .stun)))
        try #expect(battle.health(of: hero) < hero.maxHealth)
    }

    @Test func `stun damage builds meter triggers and skips next action`() throws {
        let ability = Ability(id: "test-stun", name: "Test Stun", tier: .basic, directDamage: 1, damageKeyword: .stun)
        var battle = makeControlBattle(
            heroAbilities: [ability],
            enemyMaxHealth: 5,
            actionIntervalTurns: CombatantFixtures.quickWinTurnInterval,
        )

        var events: [ActionEvent] = []
        for _ in 0 ..< 8 {
            if let play = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle) {
                events.append(contentsOf: play)
            } else {
                break
            }
            if events.contains(effectKind: .controlTriggered, keyword: .stun) {
                break
            }
        }
        events.append(contentsOf: battle.endTurn().events)

        try #expect(events.contains(effectKind: .controlTriggered, keyword: .stun))
        #expect(events.contains {
            $0.effectKind == .controlActionSkipped && $0.keyword == .stun && $0.targetID == battle.enemy.id
        })
        try #expect(battle.health(of: battle.hero) == battle.hero.maxHealth)
    }

    @Test func `shield bash applies stun skip and grants block`() throws {
        var battle = makeControlBattle(heroAbilities: [.shieldBash], enemyMaxHealth: 5)

        _ = try BattleTestFixtures.playCardNamed("Shield Bash", owner: .hero, on: &battle)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 1)

        let events = battle.endTurn().events
        #expect(events.contains {
            $0.effectKind == .controlActionSkipped && $0.keyword == .stun && $0.targetID == battle.enemy.id
        })
        try #expect(battle.health(of: battle.hero) == battle.hero.maxHealth)
    }

    @Test func `party owner skip blocks card play then clears on end turn`() throws {
        var battle = makeControlBattle(
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 1, 1), remainingTurns: 0),
            ],
        )

        battle.nextCardID += 1
        battle.hand = BattleHand(cards: [
            BattleCard(id: battle.nextCardID, ability: .slash, owner: .hero),
        ])
        battle.ownersSkippingThisPlayerTurn = [.hero]
        let heroCard = try #require(battle.hand.cards.first { $0.owner == .hero })
        try #expect(!battle.isCardPlayable(heroCard))

        do {
            _ = try battle.playCard(cardID: heroCard.id)
            Issue.record("Expected ownerSkipping error")
        } catch BattlePlayError.ownerSkipping {}

        let events = battle.endTurn().events
        #expect(events.contains {
            $0.effectKind == .controlActionSkipped && $0.keyword == .stun && $0.targetID == battle.hero.id
        })
        try #expect(battle.ownersSkippingThisPlayerTurn.isEmpty)
        try #expect(!(battle.roster.hasControlStatus(for: battle.hero, keyword: .stun)))
        try #expect(!(battle.roster.hasPendingActionSkip(for: battle.hero, keyword: .stun)))
    }

    @Test(arguments: [(Keyword.freeze, 2), (.stun, 1)])
    func `shatter and dazed apply during control status linger`(keyword: Keyword, bonus: Int) throws {
        let jab = Ability(id: "jab", name: "Jab", tier: .basic, directDamage: 1)
        var triggers = CombatTraitTriggers()
        if keyword == .freeze {
            triggers.damageWhileTargetFrozenBonus = bonus
        } else {
            triggers.damageWhileTargetStunnedBonus = bonus
        }
        var battle = makeControlBattle(
            heroAbilities: [jab],
            activeEnemyEffects: [ActiveEffect(
                id: 1, effect: .controlMeter(keyword, 1, 1), remainingTurns: BattleTiming.controlStatusLingerTurns,
            )],
            heroModifiers: .init(triggers: triggers),
        )
        #expect(!battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: keyword))
        #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: keyword))
        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        #expect(100 - battle.health(of: battle.enemy) == 1 + bonus)
    }

    @Test func `blocked stun damage does not charge control meter`() throws {
        var battle = makeControlBattle(
            enemyMaxHealth: 20,
            activeHeroEffects: [ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 3)],
        )
        let hero = battle.hero
        _ = battle.resolveTestDamage(5, from: .enemy, to: .hero, keyword: .stun, options: .reaction())
        try #expect(battle.health(of: hero) == 20)
        try #expect(!battle.roster.hasControlStatus(for: hero, keyword: .stun))
        let meter = battle.roster.activeEffects(for: hero).first {
            $0.effect.kind == .controlMeter
        }
        try #expect(meter == nil)
    }

    @Test(arguments: [Keyword.freeze, Keyword.stun])
    func `opening hand does not backfill pending control owner`(keyword: Keyword) throws {
        let battle = makeControlBattle(
            heroAbilities: [.slash, .heal, .smite],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(keyword, 10, 10), remainingTurns: 0),
            ],
        )

        try #expect(battle.hand.count == 1)
        try #expect(battle.hand.cards.allSatisfy { $0.owner == .companion })
        try #expect(battle.heroDeck.count == CombatDeck.defaultAbilities(from: battle.hero.abilityLoadout).count)
    }

    @Test(arguments: [Keyword.freeze, Keyword.stun])
    func `pending control blocks deck draws but linger does not`(keyword: Keyword) throws {
        var battle = makeControlBattle(heroAbilities: [.slash, .heal, .smite])
        battle.hand = BattleHand()
        battle.heroDeck = CombatDeck(abilities: [.slash, .heal, .smite])
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(keyword, 10, 10), remainingTurns: 0)],
            for: battle.hero,
        )

        let deckBefore = battle.heroDeck
        try #expect(BattleCardCombatEngine.drawCards(count: 2, for: .hero, context: &battle) == 0)
        try #expect(
            BattleCardCombatEngine.drawFirstCard(matching: .physical, for: .hero, context: &battle) == nil,
        )
        try #expect(battle.heroDeck == deckBefore)
        try #expect(battle.hand.cards.allSatisfy { $0.owner != .hero })

        battle.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(keyword, 10, 10), remainingTurns: 1)],
            for: battle.hero,
        )
        try #expect(BattleCardCombatEngine.drawCards(count: 1, for: .hero, context: &battle) == 1)
    }

    @Test(arguments: [Keyword.freeze, Keyword.stun])
    func `control trigger purges owner cards and promotes surviving buffer`(keyword: Keyword) throws {
        var battle = makeControlBattle(
            heroAbilities: [.slash, .heal, .smite],
            companionAbilities: [.bash, .fangs],
            dealOpeningHand: false,
        )
        battle.heroDeck = CombatDeck(abilities: [.darkPact])
        battle.hand = BattleHand(
            cards: [
                BattleCard(id: 1, ability: .slash, owner: .hero),
                BattleCard(id: 2, ability: .bash, owner: .companion),
                BattleCard(id: 3, ability: .heal, owner: .hero),
            ],
            buffer: [
                BattleCard(id: 4, ability: .smite, owner: .hero),
                BattleCard(id: 5, ability: .fangs, owner: .companion),
            ],
        )

        let outcome = EffectHandlersTestSupport.dispatch(
            .controlMeter(keyword, 20, 10),
            ability: .slash,
            source: battle.enemy,
            target: battle.hero,
            battle: &battle,
        )

        try #expect(outcome.didApply)
        try #expect(battle.hand.cards.map(\.ability.id) == [Ability.bash.id, Ability.fangs.id])
        try #expect(battle.hand.buffer.isEmpty)
        try #expect(
            battle.heroDeck.abilities.map(\.id)
                == [Ability.darkPact.id, Ability.slash.id, Ability.heal.id, Ability.smite.id],
        )
        try #expect(outcome.events.contains { $0.effectKind == .controlTriggered && $0.keyword == keyword })
    }

    @Test func `buffer promotion returns dead owner cards to bottom of deck`() {
        var battle = makeControlBattle(
            heroAbilities: [.slash],
            companionAbilities: [.bash],
            dealOpeningHand: false,
        )
        battle.companionDeck = CombatDeck(abilities: [])
        battle.hand = BattleHand(
            cards: [
                BattleCard(id: 1, ability: .slash, owner: .hero),
            ],
            buffer: [
                BattleCard(id: 2, ability: .bash, owner: .companion),
                BattleCard(id: 3, ability: .slash, owner: .hero),
                BattleCard(id: 4, ability: .heal, owner: .hero),
                BattleCard(id: 5, ability: .bash, owner: .companion),
            ],
        )
        battle.roster.mutateRuntime(for: battle.companion) { $0.takeRawDamage(1000) }

        BattleCardCombatEngine.promoteFromBuffer(context: &battle)
        #expect(battle.hand.cards.map(\.id) == [1, 3, 4])
        #expect(battle.hand.buffer.map(\.id) == [5])
        #expect(battle.companionDeck.abilities.map(\.id) == [Ability.bash.id])

        _ = battle.hand.remove(id: 1)
        BattleCardCombatEngine.promoteFromBuffer(context: &battle)
        #expect(battle.hand.cards.map(\.id) == [3, 4])
        #expect(battle.hand.buffer.isEmpty)
        #expect(battle.companionDeck.abilities.map(\.id) == [Ability.bash.id, Ability.bash.id])
    }
}
