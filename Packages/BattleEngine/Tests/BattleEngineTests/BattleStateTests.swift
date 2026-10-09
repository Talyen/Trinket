import BattleEngine
import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore

struct BattleStateTests {
    private var defaultEnemy: Combatant {
        GameContent.enemies[0].combatant
    }

    private var wolfCompanion: Combatant {
        GameContent.companions.first { $0.id == "wolf" } ?? GameContent.companions[0]
    }

    @Test func `party not defeated when one member on deaths door`() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 5),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 1),
            enemy: BattleTestFixtures.attackingEnemy(abilities: [.slash], maxHealth: 100),
        )

        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.companion) { $0.currentHealth = 0 }
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

    @Test func `party defeat when both deaths door consumed and expired`() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 3),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 3),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
        )
        let heroID = battle.hero
        let companionID = battle.companion

        battle.withEngineContext { context in
            _ = context.applyTestDamage(3, to: heroID, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            _ = context.applyTestDamage(3, to: companionID, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        }
        try #expect(!(battle.isPartyDefeated))

        for _ in 0 ..< BattleTiming.deathsDoorDurationTurns {
            _ = battle.endTurn()
        }

        battle.withEngineContext { context in
            _ = context.applyTestDamage(3, to: heroID, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            _ = context.applyTestDamage(3, to: companionID, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        }

        try #expect(!(battle.isPartyDefeated))

        _ = battle.endTurn()

        battle.withEngineContext { context in
            _ = context.applyTestDamage(3, to: heroID, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            _ = context.applyTestDamage(3, to: companionID, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        }

        try #expect(battle.isPartyDefeated)
    }

    @Test func `battle gold tracks initial balance and resource gains`() throws {
        let goldHero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20, abilities: [.steal])
        var battle = BattleStateTestFactory.makeBattle(
            hero: goldHero,
            companion: CombatantFixtures.passiveCompanion(),
            enemy: defaultEnemy,
            initialGold: 10,
        )
        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        try #expect(battle.gold == 12)

        var initialGoldBattle = BattleStateTestFactory.makeBattle(
            hero: goldHero,
            companion: CombatantFixtures.passiveCompanion(),
            enemy: defaultEnemy,
            initialGold: 5,
        )
        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &initialGoldBattle)
        try #expect(initialGoldBattle.goldFlow.net == initialGoldBattle.gold - 5)
    }

    @Test func `haggler adds gold only to living retriever theft`() throws {
        let retriever = try BattleTestFixtures.catalogBuild(
            combatantID: "golden_retriever", talents: "golden_retriever_gold_t2_1",
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: retriever.combatant,
            enemy: defaultEnemy,
            companionModifiers: retriever.modifiers,
        )
        for (health, expectedGold) in [(1, 11), (0, 10), (1, 11)] {
            battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = health }
            let before = battle.gold
            _ = battle.grantGoldEvent(10, to: battle.companion, abilityName: "Steal", isTheft: true)
            #expect(battle.gold - before == expectedGold)
        }
        let beforeEmptySteal = battle.gold
        _ = battle.grantGoldEvent(0, to: battle.companion, abilityName: "Empty Steal", isTheft: true)
        #expect(battle.gold == beforeEmptySteal)
    }

    @Test func `card combat defeat when party obliterated`() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 1),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 1),
            enemy: CombatantFixtures.combatant(id: "strong", role: .enemy, maxHealth: 100, abilities: [.slash]),
        )

        while !battle.isBattleOver {
            _ = battle.endTurn()
        }

        try #expect(battle.isPartyDefeated)
        try #expect(battle.phase == .ended)
    }

    @Test func `seeded effects do not collide with new effect I ds`() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: GameContent.heroes[0],
            companion: wolfCompanion,
            enemy: defaultEnemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(2), remainingTurns: 0),
            ],
        )
        let source = battle.hero
        let target = battle.enemy
        let outcome = EffectHandlersTestSupport.dispatch(
            .shield(.block, 5),
            source: source,
            target: target,
            battle: &battle,
        )
        try #expect(outcome.didApply)
        let ids = battle.activeEffects(of: battle.enemy).map(\.id)
        try #expect(Set(ids).count == ids.count)
        try #expect(ids.contains(2))
    }

    @Test func `battle ends when hero kills enemy without further plays`() throws {
        let finisher = Ability(id: "finisher", name: "Finisher", tier: .basic, directDamage: 1, description: "Finisher")
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20, abilities: [finisher]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20, abilities: [.bash]),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 1),
        )

        let events = try #require(try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle))

        try #expect(battle.isEnemyDefeated)
        try #expect(battle.isBattleOver)
        try #expect(!(events.contains { $0.actorName == "Companion" && $0.kind == .ability }))

        let after = battle.endTurn()
        try #expect(after.isEmpty)
    }

    @Test func `faustian bargain self damage does not wipe party when companion survives`() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "warlock", role: .hero, maxHealth: 3, abilities: [.faustianBargain]),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 50),
        )

        _ = try #require(try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle))

        try #expect(battle.health(of: battle.hero) == 1)
        try #expect(battle.health(of: battle.companion) == 20)
        try #expect(!(battle.isPartyDefeated))
        try #expect(!(battle.isEnemyDefeated))
    }

    @Test(arguments: [false, true])
    func `peak enemy depletion survives healing without observation`(tracksEvents: Bool) {
        var state = BattleState(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            tracksLog: false, tracksEvents: tracksEvents, dealOpeningHand: false,
        )
        let initial = state
        state.roster.mutateRuntime(for: state.enemy) { runtime in
            _ = runtime.takeRawDamage(58)
            _ = runtime.heal(58)
        }
        #expect(state.health(of: state.enemy) == 100)
        #expect(state.defeatProgress.experienceAward(from: 100) == 29)
        state.roster.mutateRuntime(for: state.enemy) { runtime in
            _ = runtime.takeRawDamage(40)
            _ = runtime.heal(40)
        }
        #expect(state.defeatProgress.experienceAward(from: 100) == 29)
        #expect(initial.defeatProgress.experienceAward(from: 100) == 0)
    }

    @Test func `battle state seeds party starting health`() {
        let state = BattleState(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 30),
            heroStartingHealth: 17,
            companionStartingHealth: 9,
            dealOpeningHand: false,
        )

        #expect(state.roster.hero.currentHealth == 17)
        #expect(state.roster.companion.currentHealth == 9)
        #expect(state.roster.enemy.currentHealth == 30)
    }

    @Test func `battle state defaults party to full health`() {
        let state = BattleState(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 30),
            dealOpeningHand: false,
        )

        #expect(state.roster.hero.currentHealth == 50)
        #expect(state.roster.companion.currentHealth == 40)
    }
}
