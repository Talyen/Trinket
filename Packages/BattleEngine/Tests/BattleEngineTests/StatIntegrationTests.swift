import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

/// Integration tests that stats flow correctly through full battle ticks.
/// Pure formula coverage lives in `TrinketCoreTests/PrimaryStatsRulesTests`.
/// Runtime health, interval, and heal math live in `CombatantRuntimeTests`.
final class StatIntegrationTests: XCTestCase {
    private struct DirectDamageCase {
        let ability: Ability
        let stats: PrimaryStats
        let expectedAmount: Int
        let keyword: Keyword
    }

    // MARK: - Keyword damage

    func testStatBonusAppliedToDirectDamageKeywords() {
        let cases: [DirectDamageCase] = [
            DirectDamageCase(ability: .slash, stats: PrimaryStats(strength: 10), expectedAmount: 3, keyword: .physical),
            DirectDamageCase(ability: .bash, stats: PrimaryStats(strength: 10), expectedAmount: 3, keyword: .stun),
            DirectDamageCase(ability: .slash, stats: PrimaryStats(strength: 0), expectedAmount: 1, keyword: .physical),
            DirectDamageCase(ability: .fangs, stats: PrimaryStats(agility: 10), expectedAmount: 3, keyword: .bleed),
            DirectDamageCase(ability: .fireball, stats: PrimaryStats(intellect: 10), expectedAmount: 5, keyword: .burn),
            DirectDamageCase(ability: .frostbolt, stats: PrimaryStats(intellect: 10), expectedAmount: 5, keyword: .freeze),
            DirectDamageCase(ability: .lightningBolt, stats: PrimaryStats(wisdom: 10), expectedAmount: 5, keyword: .nature),
            DirectDamageCase(ability: .smite, stats: PrimaryStats(wisdom: 10), expectedAmount: 5, keyword: .holy),
        ]

        for testCase in cases {
            let hero = BattleTestFixtures.statHero(abilities: [testCase.ability], stats: testCase.stats)
            var battle = BattleTestFixtures.statBattle(hero: hero)

            let step = BattleTestFixtures.advanceUntilActorActs(hero.id, on: &battle)
            let event = step.flatMap(BattleTestFixtures.firstAbilityEvent(in:))

            XCTAssertNotNil(event, "Expected ability event for \(testCase.ability.name)")
            XCTAssertEqual(event?.amount, testCase.expectedAmount, "Wrong damage for \(testCase.ability.name)")
            XCTAssertEqual(event?.keyword, testCase.keyword, "Wrong keyword for \(testCase.ability.name)")
        }
    }

    // MARK: - Toughness

    func testToughnessMitigationReducesIncomingDamage() {
        let hero = BattleTestFixtures.statHero(
            abilities: [],
            stats: PrimaryStats(toughness: 50),
            maxHealth: 100,
            actionIntervalTicks: 100
        )
        let enemy = BattleTestFixtures.attackingEnemy(
            abilities: [.slash],
            actionIntervalTicks: 1,
            id: "enemy"
        )
        let enemyWithStats = Combatant(
            id: enemy.id,
            name: enemy.name,
            role: enemy.role,
            maxHealth: enemy.maxHealth,
            actionIntervalTicks: enemy.actionIntervalTicks,
            abilities: enemy.abilities,
            primaryStats: PrimaryStats(strength: 0)
        )
        var battle = BattleTestFixtures.statBattle(hero: hero, enemy: enemyWithStats)

        let initial = battle.health(of: battle.hero)
        let step = battle.advanceOneStep()
        let event = BattleTestFixtures.firstAbilityEvent(in: step)

        let expectedTaken = Int(ceil(Double(1) * (1 - 0.5)))
        XCTAssertEqual(event?.amount, expectedTaken)
        XCTAssertEqual(battle.health(of: battle.hero), initial - expectedTaken)
    }

    func testToughnessReducesFireballAndBurnDamage() {
        let hero = BattleTestFixtures.statHero(
            abilities: [],
            stats: PrimaryStats(toughness: 50),
            maxHealth: 100,
            actionIntervalTicks: 100
        )
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [.fireball],
            primaryStats: PrimaryStats(strength: 0, intellect: 0)
        )
        var battle = BattleTestFixtures.statBattle(hero: hero, enemy: enemy)

        let initial = battle.health(of: battle.hero)
        _ = battle.advanceOneStep() // tick 1: fireball direct hit
        _ = battle.advanceOneStep() // tick 2: burn tick

        XCTAssertEqual(initial - battle.health(of: battle.hero), 3)
    }

    // MARK: - Wisdom

    func testWisdomIncreasesHealingAmount() {
        let hero = BattleTestFixtures.statHero(
            abilities: [.heal],
            stats: PrimaryStats(wisdom: 10),
            maxHealth: 100,
            actionIntervalTicks: 6
        )
        let enemy = BattleTestFixtures.attackingEnemy(
            abilities: [.slash],
            actionIntervalTicks: 1,
            id: "enemy"
        )
        let enemyWithStats = Combatant(
            id: enemy.id,
            name: enemy.name,
            role: enemy.role,
            maxHealth: enemy.maxHealth,
            actionIntervalTicks: enemy.actionIntervalTicks,
            abilities: enemy.abilities,
            primaryStats: PrimaryStats(strength: 0)
        )
        var battle = BattleTestFixtures.statBattle(hero: hero, enemy: enemyWithStats)

        BattleTestFixtures.advanceTicks(5, on: &battle)
        let beforeHeal = battle.health(of: battle.hero)
        XCTAssertLessThanOrEqual(beforeHeal, 96)

        _ = battle.advanceOneStep() // tick 6: hero heals for 3 + 2 wisdom

        XCTAssertEqual(battle.health(of: battle.hero), 100)
        XCTAssertGreaterThan(100 - beforeHeal, 3)
    }

    // MARK: - Agility prevention

    func testAgilityRaisesPreventionThreshold() {
        let hero = BattleTestFixtures.statHero(
            abilities: [],
            stats: PrimaryStats(agility: 20, toughness: 1),
            maxHealth: 100,
            actionIntervalTicks: 100
        )
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [.bash],
            primaryStats: PrimaryStats(strength: 0)
        )
        var battle = BattleTestFixtures.statBattle(hero: hero, enemy: enemy)

        var buildupValues: (Keyword, Int, Int)?
        for _ in 0 ..< 10 {
            BattleTestFixtures.advanceTicks(1, on: &battle)
            if let values = battle.activeEffects(of: battle.hero)
                .first(where: { $0.effect.isPreventionBuildup })?
                .effect.preventionBuildupValues
            {
                buildupValues = values
                break
            }
        }

        XCTAssertNotNil(buildupValues)
        XCTAssertEqual(buildupValues?.2, hero.primaryStats.preventionThreshold(baseMaxHealth: 101))
    }

    // MARK: - Defaults

    func testCombatantDefaultsToZeroStats() {
        let hero = Combatant(id: "h", name: "H", role: .hero, maxHealth: 10, abilities: [.slash])
        XCTAssertEqual(hero.primaryStats, PrimaryStats())
    }
}
