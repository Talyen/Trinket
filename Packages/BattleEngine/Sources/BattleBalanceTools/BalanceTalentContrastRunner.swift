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
        var treeKeyword: Keyword
    }

    struct KitFocus {
        var owner: Combatant
        var kit: Set<String>
    }

    static func siblingFoci(heroes: [Combatant], companions: [Combatant], focusIDs: [String]) -> [SiblingFocus] {
        let wanted = Set(focusIDs)
        return (heroes + companions).flatMap { owner -> [SiblingFocus] in
            CombatantTalentCatalog.config(for: owner.id).trees.flatMap { tree -> [SiblingFocus] in
                (1 ... 3).compactMap { row -> SiblingFocus? in
                    let nodes = tree.nodes(forRow: row).sorted { $0.id < $1.id }
                    guard nodes.count >= 2 else { return nil }
                    guard wanted.isEmpty
                        || wanted.contains(nodes[0].id)
                        || wanted.contains(nodes[1].id)
                    else {
                        return nil
                    }
                    return SiblingFocus(
                        owner: owner,
                        focusID: nodes[0].id,
                        siblingID: nodes[1].id,
                        prefix: SimulationMatchupBuilder.minimalPrefix(for: tree, throughRow: row),
                        treeKeyword: tree.keyword
                    )
                }
            }
        }
    }

    static func kitFoci(heroes: [Combatant], companions: [Combatant], focusIDs: [String]) -> [KitFocus] {
        let wanted = Set(focusIDs)
        return (heroes + companions).compactMap { owner -> KitFocus? in
            if !wanted.isEmpty, !wanted.contains(owner.id), !wanted.contains("full-kit") {
                return nil
            }
            let kit = CombatantTalentCatalog.validNodeIDs(for: owner.id)
            guard !kit.isEmpty else { return nil }
            return KitFocus(owner: owner, kit: kit)
        }
    }

    static func isSiblingLegal(focus: SiblingFocus, tier: SimulationPowerTier) -> Bool {
        let points = CombatantProgression.at(level: tier.level).totalTalentPoints
        let needed = focus.prefix.count + 1
        return points >= needed
    }

    static func isKitLegal(focus: KitFocus, tier: SimulationPowerTier) -> Bool {
        CombatantProgression.at(level: tier.level).totalTalentPoints >= focus.kit.count
    }

    static func workCount(config: BalanceSweepConfig) -> Int {
        siblingWorkCount(config: config) + kitWorkCount(config: config)
    }

    static func siblingWorkCount(config: BalanceSweepConfig) -> Int {
        let roster = config.resolvedRoster
        return fociCount(
            siblingFoci(
                heroes: roster.heroes,
                companions: roster.companions,
                focusIDs: config.focusIDs
            ).count,
            tiers: config.tiers.count,
            samples: config.battlesPerTier
        )
    }

    static func kitWorkCount(config: BalanceSweepConfig) -> Int {
        let roster = config.resolvedRoster
        return fociCount(
            kitFoci(
                heroes: roster.heroes,
                companions: roster.companions,
                focusIDs: config.focusIDs
            ).count,
            tiers: config.tiers.count,
            samples: config.battlesPerTier
        )
    }

    private static func fociCount(_ foci: Int, tiers: Int, samples: Int) -> Int {
        foci * tiers * samples
    }

    static func run(
        context: BalanceContrastContext,
        policy: some SimulationPlayPolicy
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
        policy: some SimulationPlayPolicy
    ) -> [PairedContrastSummary] {
        let foci = siblingFoci(
            heroes: context.heroes,
            companions: context.companions,
            focusIDs: context.config.focusIDs
        )
        guard !foci.isEmpty else { return [] }
        guard let sliced = context.config.withLocalSlice(
            regionStart: 0,
            regionCount: siblingWorkCount(config: context.config)
        ) else { return [] }
        var slicedContext = context
        slicedContext.config = sliced
        return BalanceContrastSupport.runSweep(
            context: slicedContext,
            foci: foci,
            tiers: context.config.tiers,
            summarize: {
                (
                    entityID: $0.focusID,
                    baselineID: $0.siblingID,
                    ownerID: $0.owner.id,
                    baselineKind: .sibling,
                    nonCombat: $0.treeKeyword == .gold
                )
            },
            primes: (tier: 700031, pair: 173),
            makePair: { focus, tier, pairIndex, seed in
                guard isSiblingLegal(focus: focus, tier: tier) else { return nil }
                return makeTalentPair(
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
        policy: some SimulationPlayPolicy
    ) -> [PairedContrastSummary] {
        let foci = kitFoci(
            heroes: context.heroes,
            companions: context.companions,
            focusIDs: context.config.focusIDs
        )
        guard !foci.isEmpty else { return [] }
        guard let sliced = context.config.withLocalSlice(
            regionStart: siblingWorkCount(config: context.config),
            regionCount: kitWorkCount(config: context.config)
        ) else { return [] }
        var slicedContext = context
        slicedContext.config = sliced
        return BalanceContrastSupport.runSweep(
            context: slicedContext,
            foci: foci,
            tiers: context.config.tiers,
            summarize: {
                (
                    entityID: "full-kit",
                    baselineID: "none",
                    ownerID: $0.owner.id,
                    baselineKind: .fullKit,
                    nonCombat: false
                )
            },
            primes: (tier: 700041, pair: 179),
            makePair: { focus, tier, pairIndex, seed in
                guard isKitLegal(focus: focus, tier: tier) else { return nil }
                return makeTalentPair(
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
        let enemy = BalanceContrastSupport.roundRobinEnemy(
            enemies: context.enemies,
            pairIndex: pairIndex
        )
        let ownerLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: owner,
            using: &rng
        )
        let partnerLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: partner,
            using: &rng
        )
        let gears = BalanceContrastSupport.sharedGear(
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
}
