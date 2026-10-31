import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct TatteredPagesTests {
    @Test(arguments: [0, 20], [false, true])
    func `Burn packets roll independently including Block`(block: Int, succeeds: Bool) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "tattered_pages"))
        var profile = CombatModifierProfile.zero
        affix.astral.triggers.apply(to: &profile)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: profile, appliesFightPacing: false,
        )
        battle.heroDeck = CombatDeck(abilities: [.slash, .bash, .block])
        for _ in 0 ..< 2 {
            DefensePoolEngine.set(block, on: battle.enemy, in: &battle)
            battle.rng = try BattleTestFixtures.rngSelectingChance(0.10, succeeds: succeeds)
            _ = battle.resolveTestDamage(5, keyword: .burn, options: .resolvedPeriodic)
        }
        #expect(battle.hand.cards.count == (succeeds ? 2 : 0))
    }

    @Test func `direct Burn hits each draw without a turn gate`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: .withTriggers {
                $0.burnDamageDrawChancePercent = 1
                $0.criticalChanceBonus = -1
            }, appliesFightPacing: false,
        )
        battle.heroDeck = CombatDeck(abilities: [.slash, .bash])
        for _ in 0 ..< 2 {
            _ = battle.resolveTestDamage(5, keyword: .burn, options: .attack(scaling: .resolved, accuracy: .unavoidable))
        }
        #expect(battle.hand.totalCount == 2)
    }

    @Test func `natural Burn tick and each detonation pulse can draw`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: .withTriggers { $0.burnDamageDrawChancePercent = 1 }, appliesFightPacing: false,
        )
        battle.heroDeck = CombatDeck(abilities: [.slash, .bash, .block, .slash, .block])
        let burn = ActiveEffect(id: 1, effect: .burn(8), remainingTurns: 0, sourceActorID: battle.hero.id)
        CombatExecutor.run { await EffectHandlers.advanceTurn(burn, on: battle.enemy, in: &battle) }
        #expect(battle.hand.cards.count == 1)
        CombatExecutor.run {
            await DecayingDoTDetonation.resolve(burn, factor: 1, target: battle.enemy, sourceActorID: battle.hero.id, in: &battle)
        }
        #expect(battle.hand.totalCount == 4)
        #expect(battle.hand.bufferCount == 1)
    }

    @Test func `a mirrored Burn packet rolls once without recursive draw damage`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: .withTriggers {
                $0.burnDamageDrawChancePercent = 1
                $0.bleedProcsBurnChancePercent = 1
            }, appliesFightPacing: false,
        )
        battle.heroDeck = CombatDeck(abilities: [.slash, .bash])
        _ = battle.resolveTestDamage(5, keyword: .bleed, options: .resolvedPeriodic)
        #expect(battle.hand.cards.count == 1)
    }

    @Test func `the new affix has no turn start cost or draw`() throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "tattered_pages"))
        var profile = CombatModifierProfile.zero
        affix.basic.triggers.apply(to: &profile)
        var battle = BattleStateTestFactory.makeMinimalBattle(heroModifiers: profile, appliesFightPacing: false)
        battle.heroDeck = CombatDeck(abilities: [.slash])
        let health = battle.health(of: battle.hero)
        let events = battle.recordingEvents { battle in await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
        #expect(battle.health(of: battle.hero) == health)
        #expect(!events.contains { $0.effectKind == .cardsDrawn })
    }

    @Test func `elemental reaction Burn does not trigger a damage rider`() throws {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            heroModifiers: .withTriggers { $0.burnDamageDrawChancePercent = 0.10 }, appliesFightPacing: false,
        )
        battle.heroDeck = CombatDeck(abilities: [.slash])
        battle.rng = try BattleTestFixtures.rngSelectingChance(0.10, succeeds: true)
        let originalRNG = battle.rng
        _ = battle.resolveTestDamage(5, keyword: .burn, options: .elementalReaction)
        #expect(battle.hand.cards.isEmpty)
        #expect(battle.rng == originalRNG)
    }

    @Test func `zero and non Burn damage do not roll`() throws {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            heroModifiers: .withTriggers { $0.burnDamageDrawChancePercent = 0.10 }, appliesFightPacing: false,
        )
        battle.heroDeck = CombatDeck(abilities: [.slash])
        battle.rng = try BattleTestFixtures.rngSelectingChance(0.10, succeeds: true)
        let originalRNG = battle.rng
        _ = battle.resolveTestDamage(0, keyword: .burn, options: .resolvedPeriodic)
        _ = battle.resolveTestDamage(5, keyword: .poison, options: .resolvedPeriodic)
        #expect(battle.hand.cards.isEmpty)
        #expect(battle.rng == originalRNG)
    }
}
