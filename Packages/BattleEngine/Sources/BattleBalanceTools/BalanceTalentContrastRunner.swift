import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

enum BalanceTalentContrastRunner {
    struct SiblingFocus {
        var owner: Combatant
        var focusID: String
        var siblingID: String?
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
                tree.rows.compactMap { row -> SiblingFocus? in
                    let nodes = tree.nodes(forRow: row).sorted { $0.id < $1.id }
                    guard let focus = nodes.first(where: { wanted.isEmpty || wanted.contains($0.id) }) else { return nil }
                    return SiblingFocus(
                        owner: owner,
                        focusID: focus.id,
                        siblingID: nodes.first(where: { $0.id != focus.id })?.id,
                        prefix: SimulationMatchupBuilder.minimalPrefix(for: tree, throughRow: row),
                        treeKeyword: tree.keyword,
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
        BalanceContrastSupport.rosterFociWorkCount(config: config) {
            siblingFoci(heroes: $0, companions: $1, focusIDs: $2).count
        }
    }

    static func kitWorkCount(config: BalanceSweepConfig) -> Int {
        BalanceContrastSupport.rosterFociWorkCount(config: config) {
            kitFoci(heroes: $0, companions: $1, focusIDs: $2).count
        }
    }

    static func run(
        context: BalanceContrastContext,
        policy: PlayPolicy,
    ) -> (sibling: [PairedContrastSummary], kit: [PairedContrastSummary]) {
        guard !context.heroes.isEmpty,
              !context.companions.isEmpty,
              !context.enemies.isEmpty
        else { return ([], []) }

        return (
            runSiblingSweep(context: context, policy: policy),
            runKitSweep(context: context, policy: policy),
        )
    }

    private static func runSiblingSweep(
        context: BalanceContrastContext,
        policy: PlayPolicy,
    ) -> [PairedContrastSummary] {
        let foci = siblingFoci(
            heroes: context.heroes,
            companions: context.companions,
            focusIDs: context.config.focusIDs,
        )
        return BalanceContrastSupport.runSlicedContrast(
            context: context,
            foci: foci,
            region: 0 ..< BalanceContrastSupport.workCount(
                fociCount: foci.count,
                config: context.config,
            ),
            summarize: {
                (
                    entityID: $0.focusID,
                    baselineID: $0.siblingID ?? "none",
                    ownerID: $0.owner.id,
                    baselineKind: $0.siblingID == nil ? .none : .sibling,
                    nonCombat: $0.treeKeyword == .gold,
                )
            },
            primes: (tier: 700031, pair: 173),
            makePair: { focus, tier, pairIndex, seed in
                guard isSiblingLegal(focus: focus, tier: tier) else { return nil }
                return makeTalentPair(
                    owner: focus.owner,
                    entityTalents: focus.prefix.union([focus.focusID]),
                    baselineTalents: focus.prefix.union([focus.siblingID].compactMap(\.self)),
                    tier: tier,
                    pairIndex: pairIndex,
                    context: context,
                    pairSeed: seed,
                )
            },
            policy: policy,
        )
    }

    private static func runKitSweep(
        context: BalanceContrastContext,
        policy: PlayPolicy,
    ) -> [PairedContrastSummary] {
        let siblingFociCount = siblingFoci(
            heroes: context.heroes,
            companions: context.companions,
            focusIDs: context.config.focusIDs,
        ).count
        let siblingRegionCount = BalanceContrastSupport.workCount(
            fociCount: siblingFociCount,
            config: context.config,
        )
        let foci = kitFoci(
            heroes: context.heroes,
            companions: context.companions,
            focusIDs: context.config.focusIDs,
        )
        let kitRegionCount = BalanceContrastSupport.workCount(
            fociCount: foci.count,
            config: context.config,
        )
        return BalanceContrastSupport.runSlicedContrast(
            context: context,
            foci: foci,
            region: siblingRegionCount ..< siblingRegionCount + kitRegionCount,
            summarize: {
                (
                    entityID: "full-kit",
                    baselineID: "none",
                    ownerID: $0.owner.id,
                    baselineKind: .fullKit,
                    nonCombat: false,
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
                    pairSeed: seed,
                )
            },
            policy: policy,
        )
    }

    private static func makeTalentPair(
        owner: Combatant,
        entityTalents: Set<String>,
        baselineTalents: Set<String>,
        tier: SimulationPowerTier,
        pairIndex: Int,
        context: BalanceContrastContext,
        pairSeed: UInt64,
    ) -> (withEntity: ConfiguredSimulationMatchup, withBaseline: ConfiguredSimulationMatchup) {
        let base = BalanceContrastSupport.sampleBasePair(
            owner: owner,
            pairIndex: pairIndex,
            context: context,
            pairSeed: pairSeed,
        )
        let partner = base.partner
        let enemy = base.enemy
        let ownerLoadout = base.ownerLoadout
        let partnerLoadout = base.partnerLoadout
        let gears = BalanceContrastSupport.sharedGear(
            owner: owner,
            partner: partner,
            ownerLoadout: ownerLoadout,
            partnerLoadout: partnerLoadout,
            tier: tier,
            pairSeed: pairSeed,
        )
        return BalanceContrastSupport.buildOwnerPair(
            base: .init(
                owner: owner,
                partner: partner,
                ownerLoadout: ownerLoadout,
                partnerLoadout: partnerLoadout,
                ownerGear: gears.owner,
                partnerGear: gears.partner,
                enemy: enemy,
                tier: tier,
                seed: pairSeed,
            ),
        ) { parts, isEntity in
            parts.ownerTalents = isEntity ? entityTalents : baselineTalents
        }
    }
}
