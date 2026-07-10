import Foundation
import TrinketContent
import TrinketCore

struct BalanceContrastContext {
    var config: BalanceSweepConfig
    var heroes: [Combatant]
    var pets: [Combatant]
    var enemies: [Enemy]
}

struct BalanceContrastWorkItem {
    var focusIndex: Int
    var tier: SimulationPowerTier
    var pairIndex: Int
}

enum BalanceContrastSupport {
    static func workItems(
        fociCount: Int,
        tiers: [SimulationPowerTier],
        battlesPerTier: Int
    ) -> [BalanceContrastWorkItem] {
        guard fociCount > 0 else { return [] }
        var items: [BalanceContrastWorkItem] = []
        items.reserveCapacity(tiers.count * battlesPerTier)
        for tier in tiers {
            for pairIndex in 0 ..< battlesPerTier {
                items.append(
                    BalanceContrastWorkItem(
                        focusIndex: pairIndex % fociCount,
                        tier: tier,
                        pairIndex: pairIndex
                    )
                )
            }
        }
        return items
    }

    static func aggregate(
        foci: [(entityID: String, baselineID: String, ownerID: String)],
        pairResults: [(focusIndex: Int, tier: SimulationPowerTier, entityWon: Bool, baselineWon: Bool)],
        threshold: Double
    ) -> [PairedContrastSummary] {
        var buckets: [String: (entity: Int, baseline: Int, pairs: Int, tier: SimulationPowerTier, meta: Int)] = [:]
        for result in pairResults {
            let focus = foci[result.focusIndex]
            let key = "\(result.tier.rawValue)|\(focus.entityID)|\(focus.ownerID)"
            var bucket = buckets[key] ?? (0, 0, 0, result.tier, result.focusIndex)
            bucket.pairs += 1
            if result.entityWon { bucket.entity += 1 }
            if result.baselineWon { bucket.baseline += 1 }
            buckets[key] = bucket
        }

        return buckets.values.map { bucket in
            let focus = foci[bucket.meta]
            let entityRate = bucket.pairs == 0 ? 0 : Double(bucket.entity) / Double(bucket.pairs)
            let baselineRate = bucket.pairs == 0 ? 0 : Double(bucket.baseline) / Double(bucket.pairs)
            let lift = entityRate - baselineRate
            let flagged = abs(lift) >= threshold && bucket.pairs >= 8
            return PairedContrastSummary(
                entityID: focus.entityID,
                baselineID: focus.baselineID,
                ownerID: focus.ownerID,
                tier: bucket.tier,
                pairs: bucket.pairs,
                winsWithEntity: bucket.entity,
                winsWithBaseline: bucket.baseline,
                lift: lift,
                flagged: flagged,
                flagReason: flagged ? (lift > 0 ? "HIGH" : "LOW") : nil
            )
        }
        .sorted { lhs, rhs in
            if lhs.flagged != rhs.flagged { return lhs.flagged && !rhs.flagged }
            return abs(lhs.lift) > abs(rhs.lift)
        }
    }

    static func stableHash64(_ string: String) -> UInt64 {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        return hash
    }

    static func assignRoles(
        owner: Combatant,
        partner: Combatant,
        ownerLoadout: AbilityLoadout,
        partnerLoadout: AbilityLoadout,
        ownerGear: SimulationMatchupBuilder.GearOverride?,
        partnerGear: SimulationMatchupBuilder.GearOverride?
    ) -> (
        hero: Combatant,
        pet: Combatant,
        heroLoadout: AbilityLoadout,
        petLoadout: AbilityLoadout,
        heroGear: SimulationMatchupBuilder.GearOverride?,
        petGear: SimulationMatchupBuilder.GearOverride?
    ) {
        if owner.role == .hero {
            return (owner, partner, ownerLoadout, partnerLoadout, ownerGear, partnerGear)
        }
        return (partner, owner, partnerLoadout, ownerLoadout, partnerGear, ownerGear)
    }

    struct MatchupParts {
        var owner: Combatant
        var partner: Combatant
        var ownerLoadout: AbilityLoadout
        var partnerLoadout: AbilityLoadout
        var ownerGear: SimulationMatchupBuilder.GearOverride?
        var partnerGear: SimulationMatchupBuilder.GearOverride?
        var enemy: Enemy
        var tier: SimulationPowerTier
        var seed: UInt64
    }

    static func buildMatchup(_ parts: MatchupParts) -> ConfiguredSimulationMatchup {
        let roles = assignRoles(
            owner: parts.owner,
            partner: parts.partner,
            ownerLoadout: parts.ownerLoadout,
            partnerLoadout: parts.partnerLoadout,
            ownerGear: parts.ownerGear,
            partnerGear: parts.partnerGear
        )
        return SimulationMatchupBuilder.build(
            hero: roles.hero,
            pet: roles.pet,
            enemy: parts.enemy,
            tier: parts.tier,
            heroLoadout: roles.heroLoadout,
            petLoadout: roles.petLoadout,
            seed: parts.seed,
            heroGear: roles.heroGear,
            petGear: roles.petGear
        )
    }
}
