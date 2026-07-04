import Foundation
import TrinketCore
import TrinketContent

public enum BalanceSweepRunner {
    public static func run(_ request: BalanceSweepRequest = .default) -> BalanceSweepResult {
        let triples = request.triples ?? BalanceSweepCatalog.allTriples()
        var matchupRows: [MatchupSweepRow] = []
        var abilityRows: [AbilityComparisonRow] = []

        let gearGenerator = ThemedGearGenerator()
        var matchupIndex = 0

        for tier in request.tiers {
            let sampleCount = tier.usesRandomLoadouts ? request.loadoutSamplesPerMatchup : 1
            let progression = CombatantProgression(level: tier.level, currentXP: 0, requiredXP: 100)

            for triple in triples {
                for sampleIndex in 0 ..< sampleCount {
                    var sampleRNG = SeededRandomNumberGenerator(
                        seed: request.baseSeed &+ UInt64(matchupIndex) &+ UInt64(sampleIndex)
                    )

                    let heroLoadout: AbilityLoadout
                    let petLoadout: AbilityLoadout
                    if tier.usesRandomLoadouts {
                        heroLoadout = AbilityLoadoutSampler.randomLoadout(
                            for: triple.hero,
                            progression: progression,
                            using: &sampleRNG
                        )
                        petLoadout = AbilityLoadoutSampler.randomLoadout(
                            for: triple.pet,
                            progression: progression,
                            using: &sampleRNG
                        )
                    } else {
                        heroLoadout = AbilityLoadoutSampler.defaultLoadout(
                            for: triple.hero,
                            progression: progression
                        )
                        petLoadout = AbilityLoadoutSampler.defaultLoadout(
                            for: triple.pet,
                            progression: progression
                        )
                    }

                    var heroGear: ThemedGearBuild?
                    var petGear: ThemedGearBuild?
                    if tier.includesGear,
                       let rarity = tier.rarity,
                       let affixCount = tier.fixedAffixCount {
                        let gearSeed = request.baseSeed &+ UInt64(matchupIndex) &+ 9_001
                        var heroGearRNG = SeededRandomNumberGenerator(seed: gearSeed)
                        var petGearRNG = SeededRandomNumberGenerator(seed: gearSeed &+ 1)
                        heroGear = gearGenerator.generate(
                            for: triple.hero,
                            rarity: rarity,
                            fixedAffixCount: affixCount,
                            idPrefix: "sweep-\(tier.rawValue)-\(sampleIndex)",
                            using: &heroGearRNG
                        )
                        petGear = gearGenerator.generate(
                            for: triple.pet,
                            rarity: rarity,
                            fixedAffixCount: affixCount,
                            idPrefix: "sweep-\(tier.rawValue)-\(sampleIndex)",
                            using: &petGearRNG
                        )
                    }

                    let configured = SimulationMatchupAssembler.assemble(
                        hero: triple.hero,
                        pet: triple.pet,
                        enemy: triple.enemy,
                        tier: tier,
                        heroLoadout: heroLoadout,
                        petLoadout: petLoadout,
                        heroGear: heroGear,
                        petGear: petGear,
                        loadoutSampleIndex: sampleIndex,
                        seed: request.baseSeed &+ UInt64(matchupIndex)
                    )

                    var winCount = 0
                    var tickTotal = 0
                    var actionTotal = 0

                    for runIndex in 0 ..< request.runsPerMatchup {
                        let seed = request.baseSeed &+ UInt64(matchupIndex) &+ UInt64(runIndex) &+ 100_000
                        let options = sweepOptions(maxTicks: request.maxTicks, seed: seed)
                        let result = BattleSimulator.run(configured, options: options)
                        if result.didWin {
                            winCount += 1
                        }
                        tickTotal += result.tickCount
                        actionTotal += result.actionCount
                    }

                    matchupRows.append(
                        MatchupSweepRow(
                            tier: tier,
                            heroID: triple.heroID,
                            petID: triple.petID,
                            enemyID: triple.enemyID,
                            isBoss: triple.isBoss,
                            loadoutSampleIndex: sampleIndex,
                            winCount: winCount,
                            runCount: request.runsPerMatchup,
                            averageTickCount: Double(tickTotal) / Double(request.runsPerMatchup),
                            averageActionCount: Double(actionTotal) / Double(request.runsPerMatchup)
                        )
                    )

                    matchupIndex += 1
                }
            }
        }

        if request.includeAbilityAnalysis {
            abilityRows = AbilityComparisonAnalyzer.analyze(request: request)
        }

        let anomalies = AnomalyDetector.detect(
            matchupRows: matchupRows,
            abilityRows: abilityRows
        )

        return BalanceSweepResult(
            request: request,
            matchupRows: matchupRows,
            abilityRows: abilityRows,
            anomalies: anomalies,
            generatedAt: Date()
        )
    }

    static func sweepOptions(maxTicks: Int, seed: UInt64) -> BattleSimulationOptions {
        BattleSimulationOptions(
            maxTicks: maxTicks,
            seed: seed,
            recordsEvents: false,
            recordsLog: false
        )
    }
}
