import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

enum BalanceTalentContrastRunner {
    struct SiblingFocus {
        var owner: Combatant
        var focusID: String
        var siblingID: String
        var prefix: Set<String>
    }

    struct KitFocus {
        var owner: Combatant
        var kit: Set<String>
    }

    static func run(
        context: BalanceContrastContext,
        policy: GreedyHeuristicPolicy
    ) -> (sibling: [PairedContrastSummary], kit: [PairedContrastSummary]) {
        guard !context.heroes.isEmpty,
              !context.companions.isEmpty,
              !context.enemies.isEmpty
        else { return ([], []) }

        return (
            runSiblingSweep(context: context, policy: policy),
            runKitSweep(context: context, policy: policy)
        )
    }

    private static func runSiblingSweep(
        context: BalanceContrastContext,
        policy: GreedyHeuristicPolicy
    ) -> [PairedContrastSummary] {
        let foci = makeSiblingFoci(heroes: context.heroes, companions: context.companions)
        guard !foci.isEmpty else { return [] }

        return BalanceContrastSupport.runSweep(
            context: context,
            foci: foci,
            tiers: context.config.tiers,
            summarize: { (entityID: $0.focusID, baselineID: $0.siblingID, ownerID: $0.owner.id) },
            primes: (tier: 700031, pair: 173),
            makePair: { focus, tier, pairIndex, seed in
                makeTalentPair(
                    owner: focus.owner,
                    entityTalents: focus.prefix.union([focus.focusID]),
                    baselineTalents: focus.prefix.union([focus.siblingID]),
                    tier: tier,
                    pairIndex: pairIndex,
                    context: context,
                    pairSeed: seed
                )
            },
            policy: policy
        )
    }

    private static func runKitSweep(
        context: BalanceContrastContext,
        policy: GreedyHeuristicPolicy
    ) -> [PairedContrastSummary] {
        let foci = makeKitFoci(heroes: context.heroes, companions: context.companions)
        guard !foci.isEmpty else { return [] }

        return BalanceContrastSupport.runSweep(
            context: context,
            foci: foci,
            tiers: context.config.tiers,
            summarize: { (entityID: "full-kit", baselineID: "none", ownerID: $0.owner.id) },
            primes: (tier: 700041, pair: 179),
            makePair: { focus, tier, pairIndex, seed in
                makeTalentPair(
                    owner: focus.owner,
                    entityTalents: focus.kit,
                    baselineTalents: [],
                    tier: tier,
                    pairIndex: pairIndex,
                    context: context,
                    pairSeed: seed
                )
            },
            policy: policy
        )
    }

    private static func makeSiblingFoci(heroes: [Combatant], companions: [Combatant]) -> [SiblingFocus] {
        (heroes + companions).flatMap { owner -> [SiblingFocus] in
            CombatantTalentCatalog.config(for: owner.id).trees.flatMap { tree -> [SiblingFocus] in
                (1 ... 3).compactMap { row -> SiblingFocus? in
                    let nodes = tree.nodes(forRow: row).sorted { $0.id < $1.id }
                    guard nodes.count >= 2 else { return nil }
                    return SiblingFocus(
                        owner: owner,
                        focusID: nodes[0].id,
                        siblingID: nodes[1].id,
                        prefix: SimulationMatchupBuilder.minimalPrefix(for: tree, throughRow: row)
                    )
                }
            }
        }
    }

    private static func makeKitFoci(heroes: [Combatant], companions: [Combatant]) -> [KitFocus] {
        (heroes + companions).compactMap { owner -> KitFocus? in
            let kit = CombatantTalentCatalog.validNodeIDs(for: owner.id)
            guard !kit.isEmpty else { return nil }
            return KitFocus(owner: owner, kit: kit)
        }
    }

    private static func makeTalentPair(
        owner: Combatant,
        entityTalents: Set<String>,
        baselineTalents: Set<String>,
        tier: SimulationPowerTier,
        pairIndex: Int,
        context: BalanceContrastContext,
        pairSeed: UInt64
    ) -> (withEntity: ConfiguredSimulationMatchup, withBaseline: ConfiguredSimulationMatchup) {
        var rng = SeededRandomNumberGenerator(seed: pairSeed)
        let partner = BalanceContrastSupport.pickPartner(
            for: owner,
            from: context,
            using: &rng
        )
        let enemy = BalanceSampling.stratifiedEnemy(
            enemies: context.enemies,
            battleIndex: pairIndex,
            using: &rng
        )
        let ownerLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: owner,
            using: &rng
        )
        let partnerLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: partner,
            using: &rng
        )
        let gears = sharedGear(
            owner: owner,
            partner: partner,
            ownerLoadout: ownerLoadout,
            partnerLoadout: partnerLoadout,
            tier: tier,
            pairSeed: pairSeed
        )
        return BalanceContrastSupport.buildOwnerTalentPair(
            base: .init(
                owner: owner,
                partner: partner,
                ownerLoadout: ownerLoadout,
                partnerLoadout: partnerLoadout,
                ownerGear: gears.owner,
                partnerGear: gears.partner,
                enemy: enemy,
                tier: tier,
                seed: pairSeed
            ),
            entityOwnerTalents: entityTalents,
            baselineOwnerTalents: baselineTalents
        )
    }

    private static func sharedGear(
        owner: Combatant,
        partner: Combatant,
        ownerLoadout: AbilityLoadout,
        partnerLoadout: AbilityLoadout,
        tier: SimulationPowerTier,
        pairSeed: UInt64
    ) -> (owner: SimulationMatchupBuilder.GearOverride?, partner: SimulationMatchupBuilder.GearOverride?) {
        let sharedBias = owner.keywordProfile.union(partner.keywordProfile)
        var gearRNG = SeededRandomNumberGenerator(seed: pairSeed &+ 17)
        return (
            SimulationMatchupBuilder.generateAlignedGear(
                for: owner.withAbilityLoadoutPreservingEmptyTiers(ownerLoadout),
                tier: tier,
                keywordBias: sharedBias,
                idPrefix: "contrast-owner",
                using: &gearRNG
            ),
            SimulationMatchupBuilder.generateAlignedGear(
                for: partner.withAbilityLoadoutPreservingEmptyTiers(partnerLoadout),
                tier: tier,
                keywordBias: sharedBias,
                idPrefix: "contrast-partner",
                using: &gearRNG
            )
        )
    }
}
