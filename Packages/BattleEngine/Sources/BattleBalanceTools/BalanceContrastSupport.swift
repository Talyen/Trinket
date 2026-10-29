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
    let ownerTalents: Set<String>
    let partnerTalents: Set<String>
    let tier: SimulationPowerTier
    let seed: UInt64

    mutating func prepareSharedGear() {
        let sharedBias = owner.keywordProfile.union(partner.keywordProfile)
        var gearRNG = SeededRandomNumberGenerator(seed: seed &+ 17)
        ownerGear = sharedGear(for: owner, loadout: ownerLoadout, bias: sharedBias, prefix: "contrast-owner", using: &gearRNG)
        partnerGear = sharedGear(for: partner, loadout: partnerLoadout, bias: sharedBias, prefix: "contrast-partner", using: &gearRNG)
    }

    private func sharedGear(
        for combatant: Combatant, loadout: AbilityLoadout, bias: Set<Keyword>, prefix: String,
        using rng: inout some RandomNumberGenerator,
    ) -> SimulationMatchupBuilder.GearOverride? {
        SimulationMatchupBuilder.generateAlignedGear(
            for: combatant.withAbilityLoadout(loadout, fillsMissingSelections: false),
            tier: tier,
            keywordBias: bias,
            idPrefix: prefix,
            using: &rng,
        ) ?? SimulationMatchupBuilder.generateStarterGearIfNeeded(
            for: combatant, loadout: loadout, tier: tier,
            idPrefix: prefix, gearKeywordBias: bias, using: &rng,
        )
    }

    /// Builds one side of the pair. Nil overrides retain the shared base build.
    func matchup(
        ownerLoadout: AbilityLoadout? = nil,
        ownerGear: SimulationMatchupBuilder.GearOverride? = nil,
        ownerTalents: Set<String>? = nil,
    ) -> ConfiguredSimulationMatchup {
        let ownerIsHero = owner.role == .hero
        let loadout = ownerLoadout ?? self.ownerLoadout
        let gear = ownerGear ?? self.ownerGear
        let talents = ownerTalents ?? self.ownerTalents
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
            heroTalents: ownerIsHero ? talents : partnerTalents,
            companionTalents: ownerIsHero ? partnerTalents : talents,
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
        _ summaries: some Sequence<PairedContrastSummary>,
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
        _ rows: some Sequence<Row>,
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

    /// Sample the party together. Ability comparisons must satisfy the same
    /// damage guideline on both sides while keeping the other cards shared.
    static func sampleContrastLoadouts(
        owner: Combatant,
        partner: Combatant,
        abilityPair: (Ability, Ability)? = nil,
        using rng: inout some RandomNumberGenerator,
    ) -> (owner: AbilityLoadout, partner: AbilityLoadout) {
        func damageCount(_ ownerLoadout: AbilityLoadout, _ partnerLoadout: AbilityLoadout) -> Int {
            let partnerCount = partnerLoadout.abilities.count(where: \.dealsCombatDamage)
            guard let (focus, sibling) = abilityPair else {
                return partnerCount + ownerLoadout.abilities.count(where: \.dealsCombatDamage)
            }
            return partnerCount + min(
                ownerLoadout.selecting(focus).abilities.count(where: \.dealsCombatDamage),
                ownerLoadout.selecting(sibling).abilities.count(where: \.dealsCombatDamage),
            )
        }

        for _ in 0 ..< 64 {
            let ownerLoadout = SimulationMatchupBuilder.sampleLoadout(for: owner, using: &rng)
            let partnerLoadout = SimulationMatchupBuilder.sampleLoadout(for: partner, using: &rng)
            if damageCount(ownerLoadout, partnerLoadout) >= SimulationMatchupBuilder.minimumPartyDamagingAbilities {
                return (ownerLoadout, partnerLoadout)
            }
        }

        /// If random attempts miss a rare combination, use the strongest legal
        /// damage count. This also handles rosters unable to reach the guideline.
        func mostDamagingLoadout(_ combatant: Combatant) -> AbilityLoadout {
            func choice(_ tier: AbilityTier) -> Ability? {
                let choices = combatant.abilityChoices.abilities(for: tier)
                return choices.first(where: \.dealsCombatDamage) ?? choices.first
            }
            return AbilityLoadout(basic: choice(.basic), skill: choice(.skill), ultimate: choice(.ultimate))
        }
        return (mostDamagingLoadout(owner), mostDamagingLoadout(partner))
    }

    /// Shared pair-setup preamble: partner pick, round-robin enemy, party
    /// loadouts, and independently seeded talents.
    static func sampleBasePair(
        owner: Combatant,
        pairIndex: Int,
        context: BalanceContrastContext,
        tier: SimulationPowerTier,
        pairSeed: UInt64,
        abilityPair: (Ability, Ability)? = nil,
    ) -> ContrastMatchupBase {
        var rng = SeededRandomNumberGenerator(seed: pairSeed)
        let partners = owner.role == .hero ? context.companions : context.heroes
        guard let partner = partners.randomElement(using: &rng) else {
            preconditionFailure("Contrast partner pool empty after roster guard")
        }
        let enemy = context.enemies[pairIndex % context.enemies.count]
        let loadouts = sampleContrastLoadouts(owner: owner, partner: partner, abilityPair: abilityPair, using: &rng)
        var talentRNG = SeededRandomNumberGenerator(seed: pairSeed &+ 29)
        let ownerTalents = context.config.usesTierTalents
            ? SimulationMatchupBuilder.legalTalentKit(for: owner.id, level: tier.level, using: &talentRNG) : []
        let partnerTalents = context.config.usesTierTalents
            ? SimulationMatchupBuilder.legalTalentKit(for: partner.id, level: tier.level, using: &talentRNG) : []
        return ContrastMatchupBase(
            owner: owner,
            partner: partner,
            enemy: enemy,
            ownerLoadout: loadouts.owner,
            partnerLoadout: loadouts.partner,
            ownerGear: nil,
            partnerGear: nil,
            ownerTalents: ownerTalents,
            partnerTalents: partnerTalents,
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

    /// Add only talents legal with either focused choice; neither side can
    /// acquire the other choice through the shared background build.
    static func sharedTalentKit(
        owner: Combatant,
        tier: SimulationPowerTier,
        entityTalents: Set<String>,
        baselineTalents: Set<String>,
        seed: UInt64,
    ) -> Set<String> {
        var common = entityTalents.intersection(baselineTalents)
        let entityChoice = entityTalents.subtracting(common)
        let baselineChoice = baselineTalents.subtracting(common)
        let reserved = max(entityChoice.count, baselineChoice.count)
        let excluded = entityChoice.union(baselineChoice)
        let points = CombatantProgression.at(level: tier.level).totalTalentPoints
        let trees = CombatantTalentCatalog.config(for: owner.id).trees
        var rng = SeededRandomNumberGenerator(seed: seed &+ 31)
        while common.count + reserved < points {
            let entityBuild = common.union(entityChoice)
            let baselineBuild = common.union(baselineChoice)
            let candidates = trees.flatMap { tree in
                tree.nodes.filter { node in
                    !common.contains(node.id) && !excluded.contains(node.id)
                        && tree.canUnlock(node: node, unlockedNodeIDs: entityBuild, availablePoints: 1)
                        && tree.canUnlock(node: node, unlockedNodeIDs: baselineBuild, availablePoints: 1)
                }
            }
            guard let pick = candidates.randomElement(using: &rng) else { break }
            common.insert(pick.id)
        }
        return common
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
