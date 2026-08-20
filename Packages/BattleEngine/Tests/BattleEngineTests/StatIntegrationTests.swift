import BattleEngine
import Foundation
import Testing
import TrinketContent
import TrinketCore

/// Integration tests that stats flow correctly through card combat.
/// Pure formula coverage lives in `TrinketCoreTests/PrimaryStatsRulesTests`.
/// Runtime health and heal math live in `CombatantRuntimeTests`.
/// Control-meter threshold wiring lives in `ControlMeterIntegrationTests`.
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
            DirectDamageCase(ability: .slash, stats: PrimaryStats(strength: 80), expectedAmount: 3, keyword: .physical),
            DirectDamageCase(ability: .bash, stats: PrimaryStats(strength: 80), expectedAmount: 3, keyword: .stun),
            DirectDamageCase(ability: .slash, stats: PrimaryStats(strength: 0), expectedAmount: 2, keyword: .physical),
            DirectDamageCase(ability: .fireball, stats: PrimaryStats(intellect: 80), expectedAmount: 5, keyword: .burn),
            DirectDamageCase(ability: .frostbolt, stats: PrimaryStats(intellect: 80), expectedAmount: 5, keyword: .freeze),
            DirectDamageCase(ability: .poisonDagger, stats: PrimaryStats(wisdom: 80), expectedAmount: 3, keyword: .poison),
            DirectDamageCase(ability: .smite, stats: PrimaryStats(wisdom: 80), expectedAmount: 6, keyword: .holy),
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

            try #expect(event.amount == testCase.expectedAmount, "Wrong damage for \(testCase.ability.name): got \(event.amount)")
            try #expect(event.keyword == testCase.keyword, "Wrong keyword for \(testCase.ability.name)")
        }
    }

    // MARK: - Wisdom

    @Test func wisdomIncreasesHealingAmount() throws {
        let hero = BattleTestFixtures.statHero(
            abilities: [.heal],
            stats: PrimaryStats(wisdom: 10),
            maxHealth: 100
        )
        let companion = BattleTestFixtures.passiveCombatant(
            id: "companion",
            name: "Companion",
            role: .companion,
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
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemyWithStats
        )

        // Draw into Heal, then pin HP so catch-up-reduced enemy hits cannot leave too little missing Health.
        BattleTestFixtures.endTurns(5, on: &battle)
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: companion) { $0.currentHealth = 100 }
            context.roster.mutateRuntime(for: hero) { $0.currentHealth = 50 }
        }
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
                .first(where: \.effect.isControlMeter)?
                .effect.controlMeterValues {
                buildupValues = values
                break
            }
        }

        let values = try #require(buildupValues)
        try #expect(values.threshold == hero.primaryStats.controlMeterThreshold(baseMaxHealth: 100))
    }
}
