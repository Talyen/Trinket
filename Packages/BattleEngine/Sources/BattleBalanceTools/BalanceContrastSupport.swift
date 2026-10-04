import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

struct BalanceContrastContext {
    var config: BalanceSweepConfig
    var heroes: [Combatant]
    var companions: [Combatant]
    var enemies: [Enemy]
}

struct ContrastPairOutcome: Equatable {
    var focusIndex: Int
    var tier: SimulationPowerTier
    var entity: BattleSimResult
    var baseline: BattleSimResult
}

/// One sampled contrast matchup: a fixed owner/partner/enemy/loadout/gear
/// foundation that variants override along a single axis (ability loadout,
/// affix gear, or talent kit).
struct ContrastMatchupBase {
    let owner: Combatant
    let partner: Combatant
    let enemy: Enemy
    var ownerLoadout: AbilityLoadout
    let partnerLoadout: AbilityLoadout
    var ownerGear: SimulationMatchupBuilder.GearOverride?
    var partnerGear: SimulationMatchupBuilder.GearOverride?
    let tier: SimulationPowerTier
    let seed: UInt64

    mutating func prepareSharedGear() {
        let sharedBias = owner.keywordProfile.union(partner.keywordProfile)
        var gearRNG = SeededRandomNumberGenerator(seed: seed &+ 17)
        ownerGear = SimulationMatchupBuilder.generateAlignedGear(
            for: owner.withAbilityLoadoutPreservingEmptyTiers(ownerLoadout),
            tier: tier,
            keywordBias: sharedBias,
            idPrefix: "contrast-owner",
            using: &gearRNG,
        )
        partnerGear = SimulationMatchupBuilder.generateAlignedGear(
            for: partner.withAbilityLoadoutPreservingEmptyTiers(partnerLoadout),
            tier: tier,
            keywordBias: sharedBias,
            idPrefix: "contrast-partner",
            using: &gearRNG,
        )
    }

    /// Builds one side of the pair, assigning owner to its roster role. A nil
    /// `ownerGear`/`ownerLoadout` uses the base value; `ownerTalents` replaces
    /// the base's default empty kit.
    func matchup(
        ownerLoadout: AbilityLoadout? = nil,
        ownerGear: SimulationMatchupBuilder.GearOverride? = nil,
        ownerTalents: Set<String> = [],
    ) -> ConfiguredSimulationMatchup {
        let ownerIsHero = owner.role == .hero
        let loadout = ownerLoadout ?? self.ownerLoadout
        let gear = ownerGear ?? self.ownerGear
        return SimulationMatchupBuilder.build(
            hero: ownerIsHero ? owner : partner,
            companion: ownerIsHero ? partner : owner,
            enemy: enemy,
            tier: tier,
            heroLoadout: ownerIsHero ? loadout : partnerLoadout,
            companionLoadout: ownerIsHero ? partnerLoadout : loadout,
            seed: seed,
            heroGear: ownerIsHero ? gear : partnerGear,
            companionGear: ownerIsHero ? partnerGear : gear,
            heroTalents: ownerIsHero ? ownerTalents : [],
            companionTalents: ownerIsHero ? [] : ownerTalents,
        )
    }
}

enum BalanceContrastSupport {
    typealias Pair = (withEntity: ConfiguredSimulationMatchup, withBaseline: ConfiguredSimulationMatchup)
    typealias FocusSummary = (
        entityID: String,
        baselineID: String,
        ownerID: String,
        baselineKind: ContrastBaselineKind,
        nonCombat: Bool,
    )

    static func aggregate(
        foci: [FocusSummary],
        pairResults: [ContrastPairOutcome],
        config: BalanceSweepConfig,
    ) -> [PairedContrastSummary] {
        bucketed(pairResults, config: config, make: { result in
            let focus = foci[result.focusIndex]
            return BalanceContrastFlags.ContrastAcc(
                entityID: focus.entityID, baselineID: focus.baselineID, ownerID: focus.ownerID,
                tier: result.tier, baselineKind: focus.baselineKind, nonCombat: focus.nonCombat,
            )
        }, accumulate: { acc, result in
            acc.accumulate(entity: result.entity, baseline: result.baseline)
        })
    }

    static func mergeSummaries(
        _ summaries: [PairedContrastSummary],
        config: BalanceSweepConfig,
    ) -> [PairedContrastSummary] {
        bucketed(summaries, config: config, make: { row in
            BalanceContrastFlags.ContrastAcc(
                entityID: row.entityID, baselineID: row.baselineID, ownerID: row.ownerID,
                tier: row.tier, baselineKind: row.baselineKind, nonCombat: row.nonCombat,
            )
        }, accumulate: { $0.merge($1) })
    }

    /// Raw outcomes and worker summaries share one fold without allocating
    /// intermediate rows or retaining a closure for every comparison.
    private static func bucketed<Row>(
        _ rows: [Row],
        config: BalanceSweepConfig,
        make: (Row) -> BalanceContrastFlags.ContrastAcc,
        accumulate: (inout BalanceContrastFlags.ContrastAcc, Row) -> Void,
    ) -> [PairedContrastSummary] {
        var buckets: [BalanceContrastFlags.Identity: BalanceContrastFlags.ContrastAcc] = [:]
        for row in rows {
            let initial = make(row)
            let key = initial.identity
            accumulate(&buckets[key, default: initial], row)
        }
        return buckets.values.map { BalanceContrastFlags.makeSummary($0, config: config) }
            .sorted(by: BalanceContrastFlags.summarySort)
    }

    static func rosterFociWorkCount(
        config: BalanceSweepConfig,
        fociCount: (_ heroes: [Combatant], _ companions: [Combatant], _ focusIDs: [String]) -> Int,
    ) -> Int {
        let roster = config.resolvedRoster
        return workCount(
            fociCount: fociCount(roster.heroes, roster.companions, config.focusIDs),
            config: config,
        )
    }

    /// Shared pair-setup preamble: partner pick, round-robin enemy, and both
    /// loadouts, sampled from `pairSeed` in this exact order. Keep the order:
    /// reseeds change every contrast sample downstream.
    static func sampleBasePair(
        owner: Combatant,
        pairIndex: Int,
        context: BalanceContrastContext,
        tier: SimulationPowerTier,
        pairSeed: UInt64,
    ) -> ContrastMatchupBase {
        var rng = SeededRandomNumberGenerator(seed: pairSeed)
        let partner = pickPartner(for: owner, from: context, using: &rng)
        let enemy = roundRobinEnemy(enemies: context.enemies, pairIndex: pairIndex)
        let ownerLoadout = SimulationMatchupBuilder.sampleLoadout(for: owner, using: &rng)
        let partnerLoadout = SimulationMatchupBuilder.sampleLoadout(for: partner, using: &rng)
        return ContrastMatchupBase(
            owner: owner,
            partner: partner,
            enemy: enemy,
            ownerLoadout: ownerLoadout,
            partnerLoadout: partnerLoadout,
            ownerGear: nil,
            partnerGear: nil,
            tier: tier,
            seed: pairSeed,
        )
    }

    static func stableHash64(_ string: String) -> UInt64 {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        return hash
    }

    static func pickPartner(
        for owner: Combatant,
        from context: BalanceContrastContext,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> Combatant {
        let partnerPool = owner.role == .hero ? context.companions : context.heroes
        guard let partner = partnerPool.randomElement(using: &randomNumberGenerator) else {
            preconditionFailure("Contrast partner pool empty after roster guard")
        }
        return partner
    }

    /// Sampled base with shared-bias gear both sides wear. Ability and talent
    /// pairs differ only in what they override afterward; affix pairs keep
    /// their custom gear factory and only share `sampleBasePair`.
    static func base(
        owner: Combatant,
        tier: SimulationPowerTier,
        pairIndex: Int,
        context: BalanceContrastContext,
        pairSeed: UInt64,
    ) -> ContrastMatchupBase {
        var base = sampleBasePair(
            owner: owner,
            pairIndex: pairIndex,
            context: context,
            tier: tier,
            pairSeed: pairSeed,
        )
        base.prepareSharedGear()
        return base
    }

    static func seed(
        base: UInt64,
        tier: SimulationPowerTier,
        pairIndex: Int,
        entityID: String,
        primes: (tier: UInt64, pair: UInt64),
    ) -> UInt64 {
        base
            &+ UInt64(tier.level) &* primes.tier
            &+ UInt64(pairIndex) &* primes.pair
            &+ stableHash64(entityID)
    }

    static func roundRobinEnemy(enemies: [Enemy], pairIndex: Int) -> Enemy {
        precondition(!enemies.isEmpty, "roundRobinEnemy requires a non-empty enemy list")
        return enemies[pairIndex % enemies.count]
    }

    static func workCount(fociCount: Int, config: BalanceSweepConfig) -> Int {
        fociCount * config.tiers.count * config.battlesPerTier
    }
}

/// Sweep execution for `BalanceContrastSupport`: the parallel pair-run loop.
/// Sampling, matchup building, and summary bucketing stay in
/// `BalanceContrastSupport`.
extension BalanceContrastSupport {
    static func runSweep<Focus: Sendable>(
        context: BalanceContrastContext,
        policy: PlayPolicy,
        foci: [Focus],
        summarize: @escaping @Sendable (Focus) -> FocusSummary,
        primes: @escaping @Sendable (Focus) -> (tier: UInt64, pair: UInt64),
        makePair: @escaping @Sendable (Focus, SimulationPowerTier, Int, UInt64) -> Pair?,
    ) -> [PairedContrastSummary] {
        let tiers = context.config.tiers
        guard !context.heroes.isEmpty, !context.companions.isEmpty, !context.enemies.isEmpty,
              !foci.isEmpty, !tiers.isEmpty
        else { return [] }
        let config = context.config
        let summaries = foci.map(summarize)
        @Sendable func simulate(_ matchup: ConfiguredSimulationMatchup) -> BattleSimResult {
            BattleSimulator.run(
                matchup: matchup, policy: policy,
                maxRounds: config.maxRounds, maxActions: config.maxActions,
                appliesFightPacing: config.appliesFightPacing,
            )
        }

        let work = config.workIndices(count: workCount(fociCount: foci.count, config: config))
        let jobs = config.resolvedJobs
        let pairResults = SweepWorkerPool.map(count: work.count, jobs: jobs) { idx -> ContrastPairOutcome? in
            // Preserve focus → tier → sample order without building the full grid.
            let globalIndex = work.lowerBound + idx
            let pairIndex = globalIndex % config.battlesPerTier
            let focusTierIndex = globalIndex / config.battlesPerTier
            let tier = tiers[focusTierIndex % tiers.count]
            let focusIndex = focusTierIndex / tiers.count
            let focus = foci[focusIndex]
            let pairSeed = seed(
                base: config.seed,
                tier: tier,
                pairIndex: pairIndex,
                entityID: summaries[focusIndex].entityID,
                primes: primes(focus),
            )
            guard let pair = makePair(focus, tier, pairIndex, pairSeed) else { return nil }
            return ContrastPairOutcome(
                focusIndex: focusIndex,
                tier: tier,
                entity: simulate(pair.withEntity),
                baseline: simulate(pair.withBaseline),
            )
        }

        return aggregate(
            foci: summaries,
            pairResults: pairResults,
            config: config,
        )
    }
}
