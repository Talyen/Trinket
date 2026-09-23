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
    var owner: Combatant
    var partner: Combatant
    var enemy: Enemy
    var ownerLoadout: AbilityLoadout
    var partnerLoadout: AbilityLoadout
    var ownerGear: SimulationMatchupBuilder.GearOverride?
    var partnerGear: SimulationMatchupBuilder.GearOverride?
    var tier: SimulationPowerTier
    var seed: UInt64

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
        bucketed(
            rows: pairResults.map { result in
                let focus = foci[result.focusIndex]
                return BucketRow(
                    tier: result.tier,
                    entityID: focus.entityID,
                    baselineID: focus.baselineID,
                    ownerID: focus.ownerID,
                    baselineKind: focus.baselineKind,
                    nonCombat: focus.nonCombat,
                    apply: { $0.accumulate(entity: result.entity, baseline: result.baseline) },
                )
            },
            config: config,
        )
    }

    static func mergeSummaries(
        _ summaries: [PairedContrastSummary],
        config: BalanceSweepConfig,
    ) -> [PairedContrastSummary] {
        bucketed(
            rows: summaries.map { row in
                BucketRow(
                    tier: row.tier,
                    entityID: row.entityID,
                    baselineID: row.baselineID,
                    ownerID: row.ownerID,
                    baselineKind: row.baselineKind,
                    nonCombat: row.nonCombat,
                    apply: { $0.merge(row) },
                )
            },
            config: config,
        )
    }

    private struct BucketRow {
        var tier: SimulationPowerTier
        var entityID: String
        var baselineID: String
        var ownerID: String
        var baselineKind: ContrastBaselineKind
        var nonCombat: Bool
        var apply: (inout BalanceContrastFlags.ContrastAcc) -> Void
    }

    private static func bucketed(rows: [BucketRow], config: BalanceSweepConfig) -> [PairedContrastSummary] {
        var buckets: [String: BalanceContrastFlags.ContrastAcc] = [:]
        for row in rows {
            let key = BalanceContrastFlags.summaryKey(
                tier: row.tier,
                entityID: row.entityID,
                baselineID: row.baselineID,
                ownerID: row.ownerID,
                baselineKind: row.baselineKind,
            )
            var acc = buckets[key] ?? BalanceContrastFlags.ContrastAcc(
                entityID: row.entityID,
                baselineID: row.baselineID,
                ownerID: row.ownerID,
                tier: row.tier,
                baselineKind: row.baselineKind,
                nonCombat: row.nonCombat,
            )
            row.apply(&acc)
            buckets[key] = acc
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
        pairSeed: UInt64,
    ) -> (
        partner: Combatant,
        enemy: Enemy,
        ownerLoadout: AbilityLoadout,
        partnerLoadout: AbilityLoadout,
    ) {
        var rng = SeededRandomNumberGenerator(seed: pairSeed)
        let partner = pickPartner(for: owner, from: context, using: &rng)
        let enemy = roundRobinEnemy(enemies: context.enemies, pairIndex: pairIndex)
        let ownerLoadout = SimulationMatchupBuilder.sampleLoadout(for: owner, using: &rng)
        let partnerLoadout = SimulationMatchupBuilder.sampleLoadout(for: partner, using: &rng)
        return (partner, enemy, ownerLoadout, partnerLoadout)
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
        let sampled = sampleBasePair(
            owner: owner,
            pairIndex: pairIndex,
            context: context,
            pairSeed: pairSeed,
        )
        let gears = sharedGear(
            owner: owner,
            partner: sampled.partner,
            ownerLoadout: sampled.ownerLoadout,
            partnerLoadout: sampled.partnerLoadout,
            tier: tier,
            pairSeed: pairSeed,
        )
        return ContrastMatchupBase(
            owner: owner,
            partner: sampled.partner,
            enemy: sampled.enemy,
            ownerLoadout: sampled.ownerLoadout,
            partnerLoadout: sampled.partnerLoadout,
            ownerGear: gears.owner,
            partnerGear: gears.partner,
            tier: tier,
            seed: pairSeed,
        )
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

    static func runEntityBaselinePair(
        matchups: (withEntity: ConfiguredSimulationMatchup, withBaseline: ConfiguredSimulationMatchup),
        policy: PlayPolicy,
        maxRounds: Int,
        maxActions: Int,
        appliesFightPacing: Bool,
    ) -> (entity: BattleSimResult, baseline: BattleSimResult) {
        (
            BattleSimulator.run(
                matchup: matchups.withEntity,
                policy: policy,
                maxRounds: maxRounds,
                maxActions: maxActions,
                appliesFightPacing: appliesFightPacing,
            ),
            BattleSimulator.run(
                matchup: matchups.withBaseline,
                policy: policy,
                maxRounds: maxRounds,
                maxActions: maxActions,
                appliesFightPacing: appliesFightPacing,
            ),
        )
    }

    static func roundRobinEnemy(enemies: [Enemy], pairIndex: Int) -> Enemy {
        precondition(!enemies.isEmpty, "roundRobinEnemy requires a non-empty enemy list")
        return enemies[pairIndex % enemies.count]
    }

    static func sharedGear(
        owner: Combatant,
        partner: Combatant,
        ownerLoadout: AbilityLoadout,
        partnerLoadout: AbilityLoadout,
        tier: SimulationPowerTier,
        pairSeed: UInt64,
    ) -> (owner: SimulationMatchupBuilder.GearOverride?, partner: SimulationMatchupBuilder.GearOverride?) {
        let sharedBias = owner.keywordProfile.union(partner.keywordProfile)
        var gearRNG = SeededRandomNumberGenerator(seed: pairSeed &+ 17)
        return (
            SimulationMatchupBuilder.generateAlignedGear(
                for: owner.withAbilityLoadoutPreservingEmptyTiers(ownerLoadout),
                tier: tier,
                keywordBias: sharedBias,
                idPrefix: "contrast-owner",
                using: &gearRNG,
            ),
            SimulationMatchupBuilder.generateAlignedGear(
                for: partner.withAbilityLoadoutPreservingEmptyTiers(partnerLoadout),
                tier: tier,
                keywordBias: sharedBias,
                idPrefix: "contrast-partner",
                using: &gearRNG,
            ),
        )
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

        let work = config.sliceWork(
            foci.indices.flatMap { focusIndex in
                tiers.flatMap { tier in
                    (0 ..< config.battlesPerTier).map { pairIndex in
                        (focusIndex: focusIndex, tier: tier, pairIndex: pairIndex)
                    }
                }
            },
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
                primes: primes(focus),
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
}
