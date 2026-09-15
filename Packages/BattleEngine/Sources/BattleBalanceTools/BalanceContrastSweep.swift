import BattleEngine
import TrinketContent
import TrinketCore

/// Sweep execution for `BalanceContrastSupport`: work counting, the parallel
/// pair-run loop, and the sliced-region variant. Sampling, matchup building,
/// and summary bucketing stay in `BalanceContrastSupport`.
extension BalanceContrastSupport {
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
        guard !context.heroes.isEmpty, !context.companions.isEmpty, !context.enemies.isEmpty,
              !foci.isEmpty, !tiers.isEmpty
        else { return [] }
        let config = context.config

        let work = config.sliceWork(
            workItems(
                fociCount: foci.count,
                tiers: tiers,
                samples: config.battlesPerTier,
            ),
        )
        let jobs = config.resolvedJobs
        let pairResults = SweepWorkerPool.map(count: work.count, jobs: jobs) { idx -> ContrastPairOutcome? in
            let item = work[idx]
            let focus = foci[item.focusIndex]
            let pairSeed = seed(
                base: config.seed,
                tier: item.tier,
                pairIndex: item.pairIndex,
                entityID: summarize(focus).entityID,
                primes: primes,
            )
            guard let pair = makePair(focus, item.tier, item.pairIndex, pairSeed) else { return nil }
            let outcome = runEntityBaselinePair(
                matchups: pair,
                policy: policy,
                maxRounds: config.maxRounds,
                maxActions: config.maxActions,
                appliesFightPacing: config.appliesFightPacing,
            )
            return ContrastPairOutcome(
                focusIndex: item.focusIndex,
                tier: item.tier,
                entity: outcome.entity,
                baseline: outcome.baseline,
            )
        }

        return aggregate(
            foci: foci.map(summarize),
            pairResults: pairResults,
            config: config,
        )
    }

    /// Sliced-region variant for sweeps that partition one work stream across
    /// sub-sweeps (talent sibling vs kit). Carves `region` out of the caller's
    /// global slice so each sub-sweep keeps stable work indices and sampling
    /// is unchanged.
    static func runSlicedContrast<Focus: Sendable>(
        context: BalanceContrastContext,
        foci: [Focus],
        region: Range<Int>,
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
        guard !foci.isEmpty else { return [] }
        guard let sliced = context.config.withLocalSlice(
            regionStart: region.lowerBound,
            regionCount: region.count,
        ) else { return [] }
        let slicedContext = BalanceContrastContext(
            config: sliced,
            heroes: context.heroes,
            companions: context.companions,
            enemies: context.enemies,
        )
        return runSweep(
            context: slicedContext,
            foci: foci,
            tiers: slicedContext.config.tiers,
            summarize: summarize,
            primes: primes,
            makePair: makePair,
            policy: policy,
        )
    }
}
