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

struct BalanceContrastWorkItem {
    var focusIndex: Int
    var tier: SimulationPowerTier
    var pairIndex: Int
}

struct ContrastPairOutcome: Equatable {
    var focusIndex: Int
    var tier: SimulationPowerTier
    var entity: BattleSimResult
    var baseline: BattleSimResult
}

enum BalanceContrastSupport {
    typealias Pair = (withEntity: ConfiguredSimulationMatchup, withBaseline: ConfiguredSimulationMatchup)

    static func workItems(
        fociCount: Int,
        tiers: [SimulationPowerTier],
        samples: Int,
    ) -> [BalanceContrastWorkItem] {
        guard fociCount > 0, samples > 0 else { return [] }
        var items: [BalanceContrastWorkItem] = []
        items.reserveCapacity(fociCount * tiers.count * samples)
        for focusIndex in 0 ..< fociCount {
            for tier in tiers {
                for pairIndex in 0 ..< samples {
                    items.append(
                        BalanceContrastWorkItem(
                            focusIndex: focusIndex,
                            tier: tier,
                            pairIndex: pairIndex,
                        ),
                    )
                }
            }
        }
        return items
    }

    static func aggregate(
        foci: [(entityID: String, baselineID: String, ownerID: String, baselineKind: ContrastBaselineKind, nonCombat: Bool)],
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

    static func assignRoles(_ parts: MatchupParts) -> (
        hero: Combatant,
        companion: Combatant,
        heroLoadout: AbilityLoadout,
        companionLoadout: AbilityLoadout,
        heroGear: SimulationMatchupBuilder.GearOverride?,
        companionGear: SimulationMatchupBuilder.GearOverride?,
        heroTalents: Set<String>,
        companionTalents: Set<String>,
    ) {
        if parts.owner.role == .hero {
            return (
                parts.owner,
                parts.partner,
                parts.ownerLoadout,
                parts.partnerLoadout,
                parts.ownerGear,
                parts.partnerGear,
                parts.ownerTalents,
                parts.partnerTalents,
            )
        }
        return (
            parts.partner,
            parts.owner,
            parts.partnerLoadout,
            parts.ownerLoadout,
            parts.partnerGear,
            parts.ownerGear,
            parts.partnerTalents,
            parts.ownerTalents,
        )
    }

    struct MatchupParts {
        var owner: Combatant
        var partner: Combatant
        var ownerLoadout: AbilityLoadout
        var partnerLoadout: AbilityLoadout
        var ownerGear: SimulationMatchupBuilder.GearOverride?
        var partnerGear: SimulationMatchupBuilder.GearOverride?
        var ownerTalents: Set<String> = []
        var partnerTalents: Set<String> = []
        var enemy: Enemy
        var tier: SimulationPowerTier
        var seed: UInt64
    }

    static func buildMatchup(_ parts: MatchupParts) -> ConfiguredSimulationMatchup {
        let roles = assignRoles(parts)
        return SimulationMatchupBuilder.build(
            hero: roles.hero,
            companion: roles.companion,
            enemy: parts.enemy,
            tier: parts.tier,
            heroLoadout: roles.heroLoadout,
            companionLoadout: roles.companionLoadout,
            seed: parts.seed,
            heroGear: roles.heroGear,
            companionGear: roles.companionGear,
            heroTalents: roles.heroTalents,
            companionTalents: roles.companionTalents,
        )
    }

    static func buildOwnerPair(
        base: MatchupParts,
        mutate: (inout MatchupParts, Bool) -> Void,
    ) -> (withEntity: ConfiguredSimulationMatchup, withBaseline: ConfiguredSimulationMatchup) {
        var withEntity = base
        mutate(&withEntity, true)
        var withBaseline = base
        mutate(&withBaseline, false)
        return (buildMatchup(withEntity), buildMatchup(withBaseline))
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
}
