import Foundation
import Testing
@testable import BalanceSweepCLI
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct BalanceSweepRunnerTests {
    @Test func smokeBalanceSweep() throws {
        let hero = GameContent.heroes.first { $0.id == "wizard" }!
        let pet = GameContent.pets.first { $0.id == "wolf" }!
        let enemies = Array(GameContent.enemies.prefix(2))
        let triples = enemies.map { BalanceSweepTriple(hero: hero, pet: pet, enemy: $0) }

        let request = BalanceSweepRequest(
            tiers: [.early],
            runsPerMatchup: 2,
            loadoutSamplesPerMatchup: 1,
            includeAbilityAnalysis: false,
            triples: triples
        )

        let result = BalanceSweepRunner.run(request)

        try #expect(result.matchupRows.count == 2)
        try #expect(result.abilityRows.isEmpty)
        try #expect(!(result.matchupRows.contains { $0.runCount != 2 }))
        try #expect(result.kpis.totalMatchupRows == 2)
    }

    @Test func generateBalanceReport() throws {
        let request = BalanceSweepRequest(
            tiers: [.early],
            runsPerMatchup: 2,
            loadoutSamplesPerMatchup: 1,
            includeAbilityAnalysis: false,
            triples: [
                BalanceSweepTriple(
                    hero: GameContent.heroes.first { $0.id == "wizard" }!,
                    pet: GameContent.pets.first { $0.id == "wolf" }!,
                    enemy: GameContent.enemies[0]
                )
            ]
        )

        let result = BalanceSweepRunner.run(request)
        let html = BalanceReportRenderer.renderHTML(result)
        let json = try BalanceReportRenderer.renderJSON(result)

        try #expect(!(result.matchupRows.isEmpty))
        try #expect(html.contains("Balance Sweep Report"))
        try #expect(html.contains("KPIs"))
        try #expect(!(json.isEmpty))
    }
}

@Suite
struct BalanceSweepKPIsTests {
    @Test func computeTracksInBandPerfectWinAndDuration() throws {
        let rows = [
            MatchupSweepRow(
                tier: .middle,
                heroID: "knight",
                petID: "wolf",
                enemyID: "goblin",
                isBoss: false,
                isElite: false,
                loadoutSampleIndex: 0,
                winCount: 14,
                tickLimitCount: 0,
                runCount: 20,
                averageTickCount: 42,
                averageActionCount: 30
            ),
            MatchupSweepRow(
                tier: .middle,
                heroID: "knight",
                petID: "wolf",
                enemyID: "slime",
                isBoss: false,
                isElite: false,
                loadoutSampleIndex: 0,
                winCount: 20,
                tickLimitCount: 0,
                runCount: 20,
                averageTickCount: 5,
                averageActionCount: 4
            )
        ]

        let kpis = BalanceSweepKPIs.compute(from: rows)
        try #expect(kpis.totalMatchupRows == 2)
        try #expect(kpis.inBandCount == 0)
        try #expect(kpis.perfectWinCount == 1)
        try #expect(kpis.durationInBandCount == 1)
    }
}

@Suite
struct BalanceGateEvaluatorTests {
    @Test func flagsFodderPerfectWinRateViolation() throws {
        let request = BalanceSweepRequest(tiers: [.middle])
        let rows = (0 ..< 10).map { index in
            MatchupSweepRow(
                tier: .middle,
                heroID: "knight",
                petID: "wolf",
                enemyID: "enemy-\(index)",
                isBoss: false,
                isElite: false,
                loadoutSampleIndex: 0,
                winCount: 20,
                tickLimitCount: 0,
                runCount: 20,
                averageTickCount: 30,
                averageActionCount: 20
            )
        }
        let kpis = BalanceSweepKPIs.compute(from: rows)
        let result = BalanceSweepResult(
            request: request,
            matchupRows: rows,
            abilityRows: [],
            anomalies: [],
            kpis: kpis,
            generatedAt: Date()
        )

        let violations = BalanceGateEvaluator.evaluate(result)
        try #expect(violations.contains { $0.metric == "middle.fodder.perfectWinRate" })
    }
}

@Suite
struct SimulationMatchupAssemblerTests {
    @Test func assembleAppliesLevelScalingAndModifiers() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })
        let enemy = try #require(GameContent.enemies.first { $0.id == "goblin" })
        let progression = CombatantProgression(level: 20, currentXP: 0, requiredXP: 100)
        let heroLoadout = AbilityLoadoutSampler.defaultLoadout(for: hero, progression: progression)
        let petLoadout = AbilityLoadoutSampler.defaultLoadout(for: pet, progression: progression)

        var rng = SeededRandomNumberGenerator(seed: 7)
        let gearGenerator = ThemedGearGenerator()
        let heroGear = gearGenerator.generate(
            for: hero,
            rarity: .basic,
            fixedAffixCount: 1,
            idPrefix: "test",
            using: &rng
        )

        let earlyEnemy = CombatantLevelScaler.scale(enemy: enemy, level: 1)

        let configured = SimulationMatchupAssembler.assemble(
            hero: hero,
            pet: pet,
            enemy: enemy,
            tier: .middle,
            heroLoadout: heroLoadout,
            petLoadout: petLoadout,
            heroGear: heroGear,
            petGear: nil
        )

        try #expect(configured.hero.maxHealth > hero.maxHealth)
        try #expect(configured.enemy.maxHealth > earlyEnemy.maxHealth)
        try #expect(!(configured.heroModifiers == .zero))
        try #expect(configured.context.tier == .middle)
    }
}

@Suite
struct AnomalyDetectorTests {
    @Test func targetBandsByRoleAndTier() throws {
        let earlyFodder = AnomalyDetector.targetBand(tier: .early, role: .fodder)
        try #expect(earlyFodder.min == 0.90)
        try #expect(earlyFodder.max == 0.99)

        let lateBoss = AnomalyDetector.targetBand(tier: .lateGame, role: .boss)
        try #expect(lateBoss.min == 0.50)
        try #expect(lateBoss.max == 0.60)
    }

    @Test func detectsHardCounterTimeoutTooShortAndUnderpoweredAbility() throws {
        let matchupRows = [
            MatchupSweepRow(
                tier: .early,
                heroID: "wizard",
                petID: "wolf",
                enemyID: "strong",
                isBoss: false,
                isElite: false,
                loadoutSampleIndex: 0,
                winCount: 1,
                tickLimitCount: 0,
                runCount: 10,
                averageTickCount: 12,
                averageActionCount: 8
            ),
            MatchupSweepRow(
                tier: .early,
                heroID: "alchemist",
                petID: "golden_retriever",
                enemyID: "goblin",
                isBoss: false,
                isElite: false,
                loadoutSampleIndex: 0,
                winCount: 0,
                tickLimitCount: 10,
                runCount: 10,
                averageTickCount: 100,
                averageActionCount: 40
            ),
            MatchupSweepRow(
                tier: .middle,
                heroID: "knight",
                petID: "wolf",
                enemyID: "slime",
                isBoss: false,
                isElite: false,
                loadoutSampleIndex: 0,
                winCount: 20,
                tickLimitCount: 0,
                runCount: 20,
                averageTickCount: 4,
                averageActionCount: 3
            )
        ]
        let abilityRows = [
            AbilityComparisonRow(
                tier: .middle,
                combatantID: "wizard",
                combatantName: "Wizard",
                abilityTier: .skill,
                abilityID: "fireball",
                abilityName: "Fireball",
                siblingAbilityID: "frostbolt",
                siblingAbilityName: "Frostbolt",
                winCount: 3,
                lossCount: 12
            )
        ]

        let anomalies = AnomalyDetector.detect(matchupRows: matchupRows, abilityRows: abilityRows)

        try #expect(anomalies.contains { $0.kind == BalanceAnomaly.Kind.hardCounter })
        try #expect(anomalies.contains { $0.kind == BalanceAnomaly.Kind.timeout })
        try #expect(anomalies.contains { $0.kind == BalanceAnomaly.Kind.tooShort })
        try #expect(anomalies.contains { $0.kind == BalanceAnomaly.Kind.underpoweredAbility })
    }

    @Test func detectsAboveTargetForPerfectFodderWin() throws {
        let matchupRows = [
            MatchupSweepRow(
                tier: .middle,
                heroID: "knight",
                petID: "wolf",
                enemyID: "goblin",
                isBoss: false,
                isElite: false,
                loadoutSampleIndex: 0,
                winCount: 20,
                tickLimitCount: 0,
                runCount: 20,
                averageTickCount: 25,
                averageActionCount: 18
            )
        ]

        let anomalies = AnomalyDetector.detect(matchupRows: matchupRows, abilityRows: [])
        try #expect(anomalies.contains { $0.kind == BalanceAnomaly.Kind.aboveTarget })
    }
}
