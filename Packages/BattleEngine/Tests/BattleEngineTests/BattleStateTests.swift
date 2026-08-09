import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct BattleStateTests {
    private var defaultEnemy: Combatant {
        // Catalog invariants guarantee a non-empty enemy list.
        GameContent.enemies[0].combatant
    }

    private var wolfCompanion: Combatant {
        GameContent.companions.first { $0.id == "wolf" } ?? GameContent.companions[0]
    }

    @Test func combatantAccessorsFollowRosterDefinitions() throws {
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero)
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy)
        let replacementEnemy = BattleTestFixtures.passiveCombatant(
            id: "replacement-enemy",
            name: "Replacement Enemy",
            role: .enemy
        )
        var battle = BattleStateTestFactory.makeBattle(hero: hero, companion: companion, enemy: enemy)

        battle.roster.enemy = CombatantRuntime(combatant: replacementEnemy)

        try #expect(battle.enemy == replacementEnemy)
    }

    @Test func partyNotDefeatedWhenOneMemberOnDeathsDoor() throws {
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero, maxHealth: 5)
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion, maxHealth: 1)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash], maxHealth: 100)
        var battle = BattleStateTestFactory.makeBattle(hero: hero, companion: companion, enemy: enemy)

        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: companion) { $0.currentHealth = 0 }
        }
        try #expect(!(battle.isCompanionAlive))

        let heroID = battle.hero
        battle.withEngineContext { context in
            _ = context.applyTestDamage(5, to: heroID, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        }
        try #expect(battle.health(of: battle.hero) == 1)
        try #expect(battle.activeEffects(of: battle.hero).contains { $0.effect.kind == .deathsDoor })
        try #expect(!(battle.isPartyDefeated))
    }

    @Test func partyDefeatWhenBothDeathsDoorConsumedAndExpired() throws {
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero, maxHealth: 3)
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion, maxHealth: 3)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleStateTestFactory.makeBattle(hero: hero, companion: companion, enemy: enemy)
        let heroID = battle.hero
        let companionID = battle.companion

        battle.withEngineContext { context in
            _ = context.applyTestDamage(3, to: heroID, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            _ = context.applyTestDamage(3, to: companionID, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        }
        try #expect(!(battle.isPartyDefeated))

        // Death's Door lasts N rounds; each endTurn advances one round.
        for _ in 0 ..< BattleTiming.deathsDoorDurationTurns {
            _ = battle.endTurn()
        }
        // Expiry grace lasts through the round Death's Door fell off; advance once more to clear it.
        _ = battle.endTurn()

        battle.withEngineContext { context in
            _ = context.applyTestDamage(3, to: heroID, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            _ = context.applyTestDamage(3, to: companionID, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        }

        try #expect(battle.isPartyDefeated)
    }

    @Test func battleGoldTracksInitialBalanceAndResourceGains() throws {
        let goldHero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.steal])
        var battle = BattleStateTestFactory.makeBattle(
            hero: goldHero,
            companion: BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion),
            enemy: defaultEnemy,
            initialGold: 10
        )
        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        try #expect(battle.gold == 13)

        var initialGoldBattle = BattleStateTestFactory.makeBattle(
            hero: goldHero,
            companion: BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion),
            enemy: defaultEnemy,
            initialGold: 5
        )
        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &initialGoldBattle)
        try #expect(initialGoldBattle.earnedGold == initialGoldBattle.gold - 5)
    }

    @Test func cardCombatDefeatWhenPartyObliterated() throws {
        let fragile = Combatant(id: "fragile", name: "Fragile", role: .hero, maxHealth: 1, abilities: [])
        let observer = Combatant(id: "observer", name: "Observer", role: .companion, maxHealth: 1, abilities: [])
        let enemy = Combatant(id: "strong", name: "Strong", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: fragile, companion: observer, enemy: enemy)

        while !battle.isBattleOver {
            _ = battle.endTurn()
        }

        try #expect(battle.isPartyDefeated)
        try #expect(battle.phase == .ended)
    }

    @Test func seededEffectsDoNotCollideWithNewEffectIDs() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: GameContent.heroes[0],
            companion: wolfCompanion,
            enemy: defaultEnemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(2), remainingTurns: 0),
            ]
        )
        let source = battle.hero
        let target = battle.enemy
        let outcome = EffectHandlersTestSupport.dispatch(
            .shield(.block, 5),
            ability: CombatantFixtures.ability(),
            source: source,
            target: target,
            battle: &battle
        )
        try #expect(outcome.didApply)
        let ids = battle.activeEffects(of: battle.enemy).map(\.id)
        try #expect(Set(ids).count == ids.count)
        try #expect(!(ids.contains(1) && ids.count(where: { $0 == 1 }) > 1))
        try #expect(ids.contains(2))
    }

    @Test func battleEndsWhenHeroKillsEnemyWithoutFurtherPlays() throws {
        let finisher = Ability(id: "finisher", name: "Finisher", tier: .basic, directDamage: 1, description: "Finisher")
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [finisher])
        let companion = Combatant(id: "companion", name: "Companion", role: .companion, maxHealth: 20, abilities: [.bash])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 1, abilities: [])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, companion: companion, enemy: enemy)

        let events = try #require(try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle))

        try #expect(battle.isEnemyDefeated)
        try #expect(battle.isBattleOver)
        try #expect(!(events.contains { $0.actorName == "Companion" && $0.kind == .ability }))

        let after = battle.endTurn()
        try #expect(after.isEmpty)
    }

    @Test func faustianBargainSelfDamageDoesNotWipePartyWhenCompanionSurvives() throws {
        let hero = Combatant(
            id: "warlock",
            name: "Warlock",
            role: .hero,
            maxHealth: 3,
            abilities: [.faustianBargain]
        )
        let companion = Combatant(
            id: "companion",
            name: "Companion",
            role: .companion,
            maxHealth: 20,
            abilities: []
        )
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 50,
            abilities: []
        )
        var battle = BattleStateTestFactory.makeBattle(hero: hero, companion: companion, enemy: enemy)

        _ = try #require(try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle))

        // Lose-health costs still trigger Death's Door, so the hero survives at 1 HP.
        try #expect(battle.health(of: battle.hero) == 1)
        try #expect(battle.health(of: battle.companion) == 20)
        try #expect(!(battle.isPartyDefeated))
        try #expect(!(battle.isEnemyDefeated))
    }
}
