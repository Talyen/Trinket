import BattleEngine
import Foundation
import Synchronization
import TrinketContent
import TrinketCore

enum BalanceSweepRunner {
    private struct MatchupWorkItem {
        let matchupIndex: Int
        let sampleIndex: Int
        let tier: SimulationPowerTier
        let triple: BalanceSweepTriple
    }

    static func run(_ request: BalanceSweepRequest = .default) -> BalanceSweepResult {
        let workItems = buildWorkItems(request: request)
        let matchupRows = runMatchups(workItems, request: request)

        let abilityRows = request.includeAbilityAnalysis
            ? AbilityComparisonAnalyzer.analyze(request: request)
            : []

        let anomalies = AnomalyDetector.detect(
            matchupRows: matchupRows,
            abilityRows: abilityRows
        )
        let kpis = BalanceSweepKPIs.compute(from: matchupRows)
        let gateViolations = BalanceGateEvaluator.evaluate(
            BalanceSweepResult(
                request: request,
                matchupRows: matchupRows,
                abilityRows: abilityRows,
                anomalies: anomalies,
                kpis: kpis,
                generatedAt: Date()
            )
        )

        return BalanceSweepResult(
            request: request,
            matchupRows: matchupRows,
            abilityRows: abilityRows,
            anomalies: anomalies,
            kpis: kpis,
            gateViolations: gateViolations,
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

    private static func buildWorkItems(request: BalanceSweepRequest) -> [MatchupWorkItem] {
        var workItems: [MatchupWorkItem] = []
        var matchupIndex = 0

        for tier in request.tiers {
            let triples = request.triples ?? BalanceSweepCatalog.triples(
                for: tier,
                stageWeighted: request.stageWeighted
            )
            let sampleCount = tier.usesRandomLoadouts ? request.loadoutSamplesPerMatchup : 1
            for triple in triples {
                for sampleIndex in 0 ..< sampleCount {
                    workItems.append(
                        MatchupWorkItem(
                            matchupIndex: matchupIndex,
                            sampleIndex: sampleIndex,
                            tier: tier,
                            triple: triple
                        )
                    )
                    matchupIndex += 1
                }
            }
        }

        return workItems
    }

    private static func runMatchups(
        _ workItems: [MatchupWorkItem],
        request: BalanceSweepRequest
    ) -> [MatchupSweepRow] {
        guard !workItems.isEmpty else { return [] }

        let collector = MatchupRowCollector(capacity: workItems.count)

        // Concurrency-Safety: concurrentPerform is intentional for CLI parallelism; rows are stored via Mutex-backed collector.
        DispatchQueue.concurrentPerform(iterations: workItems.count) { index in
            let row = evaluate(workItems[index], request: request)
            collector.store(row, at: index)
        }

        return collector.rows
    }
}

private final class MatchupRowCollector: Sendable {
    private let storage: Mutex<[MatchupSweepRow?]>

    init(capacity: Int) {
        storage = Mutex(Array(repeating: nil, count: capacity))
    }

    func store(_ row: MatchupSweepRow, at index: Int) {
        storage.withLock { array in
            array[index] = row
        }
    }

    var rows: [MatchupSweepRow] {
        storage.withLock { array in
            array.compactMap { $0 }
        }
    }
}

extension BalanceSweepRunner {
    private static func evaluate(
        _ workItem: MatchupWorkItem,
        request: BalanceSweepRequest
    ) -> MatchupSweepRow {
        let tier = workItem.tier
        let triple = workItem.triple
        let progression = CombatantProgression(level: tier.level, currentXP: 0, requiredXP: 100)
        let gearGenerator = ThemedGearGenerator()

        var sampleRNG = SeededRandomNumberGenerator(
            seed: request.baseSeed &+ UInt64(workItem.matchupIndex) &+ UInt64(workItem.sampleIndex)
        )

        let heroLoadout: AbilityLoadout
        let petLoadout: AbilityLoadout
        if tier.usesRandomLoadouts {
            (heroLoadout, petLoadout) = AbilityLoadoutSampler.randomLoadoutPair(
                hero: triple.hero,
                pet: triple.pet,
                progression: progression,
                mode: request.loadoutSamplingMode,
                using: &sampleRNG
            )
        } else {
            (heroLoadout, petLoadout) = AbilityLoadoutSampler.defaultLoadoutPair(
                hero: triple.hero,
                pet: triple.pet,
                progression: progression,
                mode: request.loadoutSamplingMode
            )
        }

        var heroGear: ThemedGearBuild?
        var petGear: ThemedGearBuild?
        if tier.includesGear,
           let rarity = tier.rarity,
           let affixCount = tier.fixedAffixCount {
            let gearSeed = request.baseSeed &+ UInt64(workItem.matchupIndex) &+ 9001
            var heroGearRNG = SeededRandomNumberGenerator(seed: gearSeed)
            var petGearRNG = SeededRandomNumberGenerator(seed: gearSeed &+ 1)
            heroGear = gearGenerator.generate(
                for: triple.hero,
                rarity: rarity,
                fixedAffixCount: affixCount,
                idPrefix: "sweep-\(tier.rawValue)-\(workItem.sampleIndex)",
                using: &heroGearRNG
            )
            petGear = gearGenerator.generate(
                for: triple.pet,
                rarity: rarity,
                fixedAffixCount: affixCount,
                idPrefix: "sweep-\(tier.rawValue)-\(workItem.sampleIndex)",
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
            loadoutSampleIndex: workItem.sampleIndex,
            seed: request.baseSeed &+ UInt64(workItem.matchupIndex)
        )

        let simulation = MatchupSimulationRunner.run(
            configured,
            runsPerMatchup: request.runsPerMatchup,
            maxTicks: request.maxTicks,
            baseSeed: request.baseSeed,
            matchupIndex: workItem.matchupIndex
        )

        return MatchupSweepRow(
            tier: tier,
            heroID: triple.heroID,
            petID: triple.petID,
            enemyID: triple.enemyID,
            isBoss: triple.isBoss,
            isElite: triple.isElite,
            loadoutSampleIndex: workItem.sampleIndex,
            winCount: simulation.winCount,
            tickLimitCount: simulation.tickLimitCount,
            runCount: simulation.runCount,
            averageTickCount: simulation.averageTickCount,
            averageActionCount: simulation.averageActionCount
        )
    }
}
