import Testing
import Foundation
import BattleEngine
import TrinketCore
import TrinketContent

/// Integration tests that stats flow correctly through card combat.
/// Pure formula coverage lives in `TrinketCoreTests/PrimaryStatsRulesTests`.
/// Runtime health and heal math live in `CombatantRuntimeTests`.
/// Control-meter threshold wiring lives in `ControlMeterIntegrationTests`.
@Suite
struct StatIntegrationTests {
    private struct DirectDamageCase {
        let ability: Ability
        let stats: PrimaryStats
        let expectedAmount: Int
        let keyword: Keyword
    }

    // MARK: - Keyword damage

    @Test func statBonusAppliedToDirectDamageKeywords() throws {
        let cases: [DirectDamageCase] = [
            DirectDamageCase(ability: .slash, stats: PrimaryStats(strength: 10), expectedAmount: 3, keyword: .physical),
            DirectDamageCase(ability: .bash, stats: PrimaryStats(strength: 10), expectedAmount: 3, keyword: .stun),
            DirectDamageCase(ability: .slash, stats: PrimaryStats(strength: 0), expectedAmount: 1, keyword: .physical),
            DirectDamageCase(ability: .fangs, stats: PrimaryStats(agility: 10), expectedAmount: 3, keyword: .bleed),
            DirectDamageCase(ability: .fireball, stats: PrimaryStats(intellect: 10), expectedAmount: 4, keyword: .burn),
            DirectDamageCase(ability: .frostbolt, stats: PrimaryStats(intellect: 10), expectedAmount: 4, keyword: .freeze),
            DirectDamageCase(ability: .lightningBolt, stats: PrimaryStats(wisdom: 10), expectedAmount: 5, keyword: .nature),
            DirectDamageCase(ability: .smite, stats: PrimaryStats(wisdom: 10), expectedAmount: 5, keyword: .holy),
        ]

        for testCase in cases {
            let hero = BattleTestFixtures.statHero(abilities: [testCase.ability], stats: testCase.stats)
            var battle = BattleTestFixtures.statBattle(hero: hero)

            let events = try #require(
                try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle),
                "Expected ability event for \(testCase.ability.name)"
            )
            let event = try #require(
                BattleTestFixtures.firstAbilityEvent(in: events),
                "Expected ability event for \(testCase.ability.name)"
            )

            try #expect(event.amount == testCase.expectedAmount, "Wrong damage for \(testCase.ability.name)")
            try #expect(event.keyword == testCase.keyword, "Wrong keyword for \(testCase.ability.name)")
        }
    }

    // MARK: - Toughness

    @Test func toughnessMitigationReducesIncomingDamage() throws {
        let hero = BattleTestFixtures.statHero(
            abilities: [],
            stats: PrimaryStats(toughness: 50),
            maxHealth: 100
        )
        let enemy = BattleTestFixtures.attackingEnemy(
            abilities: [.slash],
            id: "enemy"
        )
        let enemyWithStats = Combatant(
            id: enemy.id,
            name: enemy.name,
            role: enemy.role,
            maxHealth: enemy.maxHealth,
            abilities: enemy.abilities,
            primaryStats: PrimaryStats(strength: 0)
        )
        var battle = BattleTestFixtures.statBattle(hero: hero, enemy: enemyWithStats)

        let initial = battle.health(of: battle.hero)
        let events = BattleTestFixtures.endTurn(on: &battle)
        let event = BattleTestFixtures.firstAbilityEvent(in: events)

        let expectedTaken = Int(ceil(Double(1) * (1 - 0.5)))
        try #expect(event?.amount == expectedTaken)
        try #expect(battle.health(of: battle.hero) == initial - expectedTaken)
    }

    @Test func toughnessReducesFireballAndBurnDamage() throws {
        let hero = BattleTestFixtures.statHero(
            abilities: [],
            stats: PrimaryStats(toughness: 50),
            maxHealth: 100
        )
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: [.fireball],
            primaryStats: PrimaryStats(strength: 0, intellect: 0)
        )
        var battle = BattleTestFixtures.statBattle(hero: hero, enemy: enemy)

        let initial = battle.health(of: battle.hero)
        // Enemy fireball (2 burn hit → 1 after 50% toughness) then end-of-round burn tick
        // (potency 2 → 1, then 50% toughness → 1). Total lost: 2.
        _ = BattleTestFixtures.endTurn(on: &battle)

        try #expect(initial - battle.health(of: battle.hero) == 2)
    }

    // MARK: - Wisdom

    @Test func wisdomIncreasesHealingAmount() throws {
        let hero = BattleTestFixtures.statHero(
            abilities: [.heal],
            stats: PrimaryStats(wisdom: 10),
            maxHealth: 100
        )
        let enemy = BattleTestFixtures.attackingEnemy(
            abilities: [.slash],
            id: "enemy"
        )
        let enemyWithStats = Combatant(
            id: enemy.id,
            name: enemy.name,
            role: enemy.role,
            maxHealth: enemy.maxHealth,
            abilities: enemy.abilities,
            primaryStats: PrimaryStats(strength: 0)
        )
        var battle = BattleTestFixtures.statBattle(hero: hero, enemy: enemyWithStats)

        // Take a few enemy hits so heal has room.
        BattleTestFixtures.endTurns(5, on: &battle)
        let beforeHeal = battle.health(of: battle.hero)
        try #expect(beforeHeal < 100)

        _ = try BattleTestFixtures.playCardNamed("Heal", owner: .hero, on: &battle)

        try #expect(battle.health(of: battle.hero) > beforeHeal)
        try #expect(battle.health(of: battle.hero) - beforeHeal > 3)
    }

    // MARK: - Agility control meter

    @Test func agilityRaisesControlMeterThresholdInBattle() throws {
        let hero = BattleTestFixtures.statHero(
            abilities: [],
            stats: PrimaryStats(agility: 20, toughness: 1),
            maxHealth: 100
        )
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: [.bash],
            primaryStats: PrimaryStats(strength: 0)
        )
        var battle = BattleTestFixtures.statBattle(hero: hero, enemy: enemy)

        var buildupValues: (amount: Int, threshold: Int)?
        for _ in 0 ..< 10 {
            _ = BattleTestFixtures.endTurn(on: &battle)
            if let values = battle.activeEffects(of: battle.hero)
                .first(where: { $0.effect.isControlMeter })?
                .effect.controlMeterValues
            {
                buildupValues = values
                break
            }
        }

        let values = try #require(buildupValues)
        try #expect(values.threshold == hero.primaryStats.controlMeterThreshold(baseMaxHealth: 101))
    }
}
