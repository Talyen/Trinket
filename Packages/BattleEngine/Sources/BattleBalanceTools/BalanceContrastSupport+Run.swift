import BattleEngine
import TrinketContent
import TrinketCore

extension BalanceContrastSupport {
    static func workCount(fociCount: Int, config: BalanceSweepConfig) -> Int {
        fociCount * config.tiers.count * config.battlesPerTier
    }

    static func runContrast<Focus: Sendable>(
        context: BalanceContrastContext,
        foci: [Focus],
        summarize: @escaping @Sendable (Focus) -> (
            entityID: String,
            baselineID: String,
            ownerID: String,
            baselineKind: ContrastBaselineKind,
            nonCombat: Bool,
        ),
        primes: (tier: UInt64, pair: UInt64),
        makePair: @escaping @Sendable (Focus, SimulationPowerTier, Int, UInt64) -> Pair?,
        policy: PlayPolicy,
    ) -> [PairedContrastSummary] {
        guard !context.heroes.isEmpty, !context.companions.isEmpty, !context.enemies.isEmpty else { return [] }
        return runSweep(
            context: context,
            foci: foci,
            tiers: context.config.tiers,
            summarize: summarize,
            primes: primes,
            makePair: makePair,
            policy: policy,
        )
    }

    static func runSweep<Focus: Sendable>(
        context: BalanceContrastContext,
        foci: [Focus],
        tiers: [SimulationPowerTier],
        summarize: @escaping @Sendable (Focus) -> (
            entityID: String,
            baselineID: String,
            ownerID: String,
            baselineKind: ContrastBaselineKind,
            nonCombat: Bool,
        ),
        primes: (tier: UInt64, pair: UInt64),
        makePair: @escaping @Sendable (Focus, SimulationPowerTier, Int, UInt64) -> Pair?,
        policy: PlayPolicy,
    ) -> [PairedContrastSummary] {
        guard !foci.isEmpty, !tiers.isEmpty else { return [] }
        let config = context.config

        let work = config.sliceWork(
            workItems(
                fociCount: foci.count,
                tiers: tiers,
                samples: config.battlesPerTier,
            ),
        )
        let jobs = config.resolvedJobs
        // Concurrency-Safety: disjoint indices written by pool workers, no overlap
        nonisolated(unsafe) var tmp = [ContrastPairOutcome?](repeating: nil, count: work.count)
        SweepWorkerPool.forEach(count: work.count, jobs: jobs) { idx in
            let item = work[idx]
            let focus = foci[item.focusIndex]
            let pairSeed = seed(
                base: config.seed,
                tier: item.tier,
                pairIndex: item.pairIndex,
                entityID: summarize(focus).entityID,
                primes: primes,
            )
            guard let pair = makePair(focus, item.tier, item.pairIndex, pairSeed) else { return }
            let outcome = runEntityBaselinePair(
                matchups: pair,
                policy: policy,
                maxRounds: config.maxRounds,
                maxActions: config.maxActions,
                appliesFightPacing: config.appliesFightPacing,
            )
            tmp[idx] = ContrastPairOutcome(
                focusIndex: item.focusIndex,
                tier: item.tier,
                entity: outcome.entity,
                baseline: outcome.baseline,
            )
        }
        let pairResults = tmp

        return aggregate(
            foci: foci.map(summarize),
            pairResults: pairResults.compactMap(\.self),
            config: config,
        )
    }
}
