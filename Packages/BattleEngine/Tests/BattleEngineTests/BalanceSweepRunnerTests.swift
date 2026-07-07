import XCTest
@testable import BalanceSweepCLI
import BattleEngine
import TrinketCore
import TrinketContent

final class BalanceSweepRunnerTests: XCTestCase {
    func testSmokeBalanceSweep() {
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

        XCTAssertEqual(result.matchupRows.count, 2)
        XCTAssertTrue(result.abilityRows.isEmpty)
        XCTAssertFalse(result.matchupRows.contains { $0.runCount != 2 })
        XCTAssertEqual(result.kpis.totalMatchupRows, 2)
    }

    func testGenerateBalanceReport() throws {
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

        XCTAssertFalse(result.matchupRows.isEmpty)
        XCTAssertTrue(html.contains("Balance Sweep Report"))
        XCTAssertTrue(html.contains("KPIs"))
        XCTAssertFalse(json.isEmpty)
    }
}

final class BalanceSweepKPIsTests: XCTestCase {
    func testComputeTracksInBandPerfectWinAndDuration() {
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
        XCTAssertEqual(kpis.totalMatchupRows, 2)
        XCTAssertEqual(kpis.inBandCount, 0)
        XCTAssertEqual(kpis.perfectWinCount, 1)
        XCTAssertEqual(kpis.durationInBandCount, 1)
    }
}

final class BalanceGateEvaluatorTests: XCTestCase {
    func testFlagsFodderPerfectWinRateViolation() {
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
        XCTAssertTrue(violations.contains { $0.metric == "middle.fodder.perfectWinRate" })
    }
}

final class SimulationMatchupAssemblerTests: XCTestCase {
    func testAssembleAppliesLevelScalingAndModifiers() throws {
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let enemy = try XCTUnwrap(GameContent.enemies.first { $0.id == "goblin" })
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

        XCTAssertGreaterThan(configured.hero.maxHealth, hero.maxHealth)
        XCTAssertGreaterThan(configured.enemy.maxHealth, earlyEnemy.maxHealth)
        XCTAssertFalse(configured.heroModifiers == .zero)
        XCTAssertEqual(configured.context.tier, .middle)
    }
}

final class AnomalyDetectorTests: XCTestCase {
    func testTargetBandsByRoleAndTier() {
        let earlyFodder = AnomalyDetector.targetBand(tier: .early, role: .fodder)
        XCTAssertEqual(earlyFodder.min, 0.90)
        XCTAssertEqual(earlyFodder.max, 0.99)

        let lateBoss = AnomalyDetector.targetBand(tier: .lateGame, role: .boss)
        XCTAssertEqual(lateBoss.min, 0.50)
        XCTAssertEqual(lateBoss.max, 0.60)
    }

    func testDetectsHardCounterTimeoutTooShortAndUnderpoweredAbility() {
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

        XCTAssertTrue(anomalies.contains { $0.kind == BalanceAnomaly.Kind.hardCounter })
        XCTAssertTrue(anomalies.contains { $0.kind == BalanceAnomaly.Kind.timeout })
        XCTAssertTrue(anomalies.contains { $0.kind == BalanceAnomaly.Kind.tooShort })
        XCTAssertTrue(anomalies.contains { $0.kind == BalanceAnomaly.Kind.underpoweredAbility })
    }

    func testDetectsAboveTargetForPerfectFodderWin() {
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
        XCTAssertTrue(anomalies.contains { $0.kind == BalanceAnomaly.Kind.aboveTarget })
    }
}
