import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct ControlMeterIntegrationTests {
    @Test(arguments: [Keyword.stun, Keyword.freeze])
    func `action skip prevents damage`(keyword: Keyword) throws {
        var battle = BattleTestFixtures.partyWithPendingActionSkip(keyword: keyword)
        let hero = battle.hero
        let events = BattleTestFixtures.endTurn(on: &battle)

        try #expect(battle.health(of: hero) == hero.maxHealth, "keyword=\(keyword)")
        try #expect(
            events.contains(effectKind: .controlActionSkipped, keyword: keyword),
            "keyword=\(keyword)",
        )
    }

    @Test func `action skip consumes on enemy turn`() throws {
        var battle = BattleTestFixtures.partyWithPendingActionSkip(keyword: .stun)
        let enemy = battle.enemy

        try #expect(!(battle.activeEffects(of: enemy)).isEmpty)

        let events = BattleTestFixtures.endTurn(on: &battle)
        BattleTestFixtures.assertActionSkipConsumed(events: events, actorID: enemy.id, keyword: .stun)
        try #expect(!(events.contains { $0.kind == .ability && $0.actorID == enemy.id }))
        try #expect(battle.roster.hasControlStatus(for: enemy, keyword: .stun))
        try #expect(!(battle.roster.hasPendingActionSkip(for: enemy, keyword: .stun)))
    }

    @Test func `stun status lingers through following player turn without second skip`() throws {
        var battle = BattleTestFixtures.partyWithPendingActionSkip(keyword: .stun)
        let enemy = battle.enemy
        let hero = battle.hero

        let firstEnd = BattleTestFixtures.endTurn(on: &battle)
        BattleTestFixtures.assertActionSkipConsumed(events: firstEnd, actorID: enemy.id, keyword: .stun)
        try #expect(battle.roster.hasControlStatus(for: enemy, keyword: .stun))
        try #expect(CombatantBorderAccent.keyword(from: battle.activeEffects(of: enemy)) == .stun)
        try #expect(battle.health(of: hero) == hero.maxHealth)

        try #expect(!(battle.roster.hasPendingActionSkip(for: enemy)))

        let secondEnd = BattleTestFixtures.endTurn(on: &battle)
        try #expect(!(secondEnd.contains(effectKind: .controlActionSkipped, keyword: .stun)))
        try #expect(secondEnd.contains { $0.kind == .ability && $0.actorID == enemy.id })
        try #expect(!(battle.roster.hasControlStatus(for: enemy, keyword: .stun)))
        try #expect(battle.health(of: hero) < hero.maxHealth)
    }

    @Test func `stun damage builds meter triggers and skips next action`() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTurns: CombatantFixtures.quickWinTurnInterval,
            abilities: [Ability(id: "test-stun", name: "Test Stun", tier: .basic, directDamage: 1, damageKeyword: .stun)],
        )
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash], maxHealth: 5)
        var battle = BattleTestFixtures.standardParty(hero: hero, companion: companion, enemy: enemy)

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
        events.append(contentsOf: BattleTestFixtures.endTurn(on: &battle))

        try #expect(events.contains(effectKind: .controlTriggered, keyword: .stun))
        try #expect(events.contains(effectKind: .controlActionSkipped, keyword: .stun))
        try #expect(battle.health(of: battle.hero) == hero.maxHealth)
    }

    @Test func `shield bash applies stun skip and block`() throws {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.shieldBash],
        )
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash], maxHealth: 5)
        var battle = BattleTestFixtures.standardParty(hero: hero, companion: companion, enemy: enemy)

        _ = try BattleTestFixtures.playCardNamed("Shield Bash", owner: .hero, on: &battle)
        try #expect(battle.hasHeroEffect { effect in
            if case let .shield(.block, buffer) = effect, buffer > 0 {
                return true
            }
            return false
        })

        let events = BattleTestFixtures.endTurn(on: &battle)
        try #expect(events.contains(effectKind: .controlActionSkipped, keyword: .stun))
        try #expect(battle.health(of: battle.hero) == hero.maxHealth)
    }

    @Test func `party owner skip blocks card play then clears on end turn`() throws {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.slash])
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = CombatantFixtures.passiveEnemy(maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
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

        let events = BattleTestFixtures.endTurn(on: &battle)
        try #expect(events.contains(effectKind: .controlActionSkipped, keyword: .stun))
        try #expect(battle.ownersSkippingThisPlayerTurn.isEmpty)
        try #expect(!(battle.roster.hasControlStatus(for: battle.hero, keyword: .stun)))
        try #expect(!(battle.roster.hasPendingActionSkip(for: battle.hero, keyword: .stun)))
        try #expect(battle.ownersSkippingThisPlayerTurn.isEmpty)
    }

    @Test func `shatter and dazed apply during control status linger`() throws {
        let jab = Ability(id: "jab", name: "Jab", tier: .basic, directDamage: 1, damageKeyword: .physical)
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [jab])
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = CombatantFixtures.passiveEnemy(maxHealth: 100)

        var frozenBattle = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(
                    id: 1,
                    effect: .controlMeter(.freeze, 1, 1),
                    remainingTurns: BattleTiming.controlStatusLingerTurns,
                ),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageWhileTargetFrozenBonus: 2,
                ),
            )),
        )
        try #expect(!(frozenBattle.roster.hasPendingActionSkip(for: frozenBattle.enemy, keyword: .freeze)))
        try #expect(frozenBattle.roster.hasControlStatus(for: frozenBattle.enemy, keyword: .freeze))
        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &frozenBattle)
        try #expect(100 - frozenBattle.health(of: frozenBattle.enemy) == 3)

        var stunnedBattle = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(
                    id: 1,
                    effect: .controlMeter(.stun, 1, 1),
                    remainingTurns: BattleTiming.controlStatusLingerTurns,
                ),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageWhileTargetStunnedBonus: 1,
                ),
            )),
        )
        try #expect(!(stunnedBattle.roster.hasPendingActionSkip(for: stunnedBattle.enemy, keyword: .stun)))
        try #expect(stunnedBattle.roster.hasControlStatus(for: stunnedBattle.enemy, keyword: .stun))
        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &stunnedBattle)
        try #expect(100 - stunnedBattle.health(of: stunnedBattle.enemy) == 2)
    }

    @Test func `blocked stun damage does not charge control meter`() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 20)
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 3)],
        )
        _ = battle.resolveDamage(DamageRequest(
            amount: 5,
            target: hero,
            keyword: .stun,
            sourceActorID: enemy.id,
            options: .flatReaction,
        ))
        try #expect(battle.health(of: hero) == 20)
        try #expect(!battle.roster.hasControlStatus(for: hero, keyword: .stun))
        let meter = battle.roster.activeEffects(for: hero).first {
            if case .controlMeter = $0.effect {
                return true
            }
            return false
        }
        try #expect(meter == nil)
    }

    @Test(arguments: [Keyword.freeze, Keyword.stun])
    func `opening hand does not backfill pending control owner`(keyword: Keyword) throws {
        let battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(
                id: "hero",
                role: .hero,
                abilities: [.slash, .heal, .smite],
            ),
            companion: CombatantFixtures.combatant(
                id: "companion",
                role: .companion,
                abilities: [.bash, .fangs, .bloodthorn],
            ),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy),
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(keyword, 10, 10), remainingTurns: 0),
            ],
        )

        try #expect(battle.hand.count == 2)
        try #expect(battle.hand.cards.allSatisfy { $0.owner == .companion })
        try #expect(battle.heroDeck.count == battle.hero.abilityLoadout.abilities.count)
    }

    @Test(arguments: [Keyword.freeze, Keyword.stun])
    func `pending control blocks deck draws but linger does not`(keyword: Keyword) throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(
                id: "hero",
                role: .hero,
                abilities: [.slash, .heal, .smite],
            ),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy),
        )
        battle.hand = BattleHand()
        battle.heroDeck = CombatDeck(abilities: [.slash, .heal, .smite])
        battle.withEngineContext { context in
            context.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .controlMeter(keyword, 10, 10), remainingTurns: 0)],
                for: context.hero,
            )
        }

        let deckBefore = battle.heroDeck
        try #expect(BattleCardCombatEngine.drawCards(count: 2, for: .hero, context: &battle) == 0)
        try #expect(
            BattleCardCombatEngine.drawFirstCard(matching: .physical, for: .hero, context: &battle) == nil,
        )
        try #expect(battle.heroDeck == deckBefore)
        try #expect(battle.hand.cards.allSatisfy { $0.owner != .hero })

        battle.withEngineContext { context in
            context.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .controlMeter(keyword, 10, 10), remainingTurns: 1)],
                for: context.hero,
            )
        }
        try #expect(BattleCardCombatEngine.drawCards(count: 1, for: .hero, context: &battle) == 1)
    }

    @Test(arguments: [Keyword.freeze, Keyword.stun])
    func `control trigger purges owner cards and promotes surviving buffer`(keyword: Keyword) throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(
                id: "hero",
                role: .hero,
                abilities: [.slash, .heal, .smite],
            ),
            companion: CombatantFixtures.combatant(
                id: "companion",
                role: .companion,
                abilities: [.bash, .fangs],
            ),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy),
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

    @Test func `promote next from buffer returns dead owner card to bottom of deck`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.slash]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, abilities: [.bash]),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy),
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
            ],
        )
        battle.roster.mutateRuntime(for: battle.companion) { $0.takeRawDamage(1000) }

        let promoted = battle.promoteNextTurnBufferCard(rebuildLog: false)

        #expect(promoted?.id == 3)
        #expect(battle.hand.cards.map(\.id) == [1, 3])
        #expect(battle.hand.buffer.isEmpty)
        #expect(battle.companionDeck.abilities.map(\.id) == [Ability.bash.id])
    }
}
