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
                tree.rows.flatMap { row -> [SiblingFocus] in
                    let nodes = tree.nodes(forRow: row).sorted { $0.id < $1.id }
                    let selected = wanted.isEmpty ? Array(nodes.prefix(1)) : nodes.filter { wanted.contains($0.id) }
                    let prefix = SimulationMatchupBuilder.minimalPrefix(for: tree, throughRow: row)
                    return selected.map { focus in
                        SiblingFocus(
                            owner: owner,
                            focusID: focus.id,
                            siblingID: nodes.first(where: { $0.id != focus.id })?.id,
                            prefix: prefix,
                            treeKeyword: tree.keyword,
                        )
                    }
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

    enum Focus: Sendable {
        case sibling(SiblingFocus)
        case kit(KitFocus)
    }

    static func run(
        context: BalanceContrastContext,
        policy: PlayPolicy,
    ) -> (sibling: [PairedContrastSummary], kit: [PairedContrastSummary]) {
        guard !context.heroes.isEmpty,
              !context.companions.isEmpty,
              !context.enemies.isEmpty
        else { return ([], []) }

        let foci = siblingFoci(
            heroes: context.heroes,
            companions: context.companions,
            focusIDs: context.config.focusIDs,
        ).map(Focus.sibling) + kitFoci(
            heroes: context.heroes,
            companions: context.companions,
            focusIDs: context.config.focusIDs,
        ).map(Focus.kit)

        let summaries = BalanceContrastSupport.runSweep(
            context: context,
            policy: policy,
            foci: foci,
            summarize: summarize,
            primes: primes,
            makePair: { focus, tier, pairIndex, seed in
                makePair(focus: focus, tier: tier, pairIndex: pairIndex, seed: seed, context: context)
            },
        )

        return (
            summaries.filter { $0.baselineKind != .fullKit },
            summaries.filter { $0.baselineKind == .fullKit },
        )
    }

    private static func summarize(_ focus: Focus) -> BalanceContrastSupport.FocusSummary {
        switch focus {
        case let .sibling(f):
            (
                entityID: f.focusID,
                baselineID: f.siblingID ?? "none",
                ownerID: f.owner.id,
                baselineKind: f.siblingID == nil ? .none : .sibling,
                nonCombat: f.treeKeyword == .gold,
            )
        case let .kit(f):
            (
                entityID: "full-kit",
                baselineID: "none",
                ownerID: f.owner.id,
                baselineKind: .fullKit,
                nonCombat: false,
            )
        }
    }

    private static func primes(for focus: Focus) -> (tier: UInt64, pair: UInt64) {
        switch focus {
        case .sibling: (tier: 700031, pair: 173)
        case .kit: (tier: 700041, pair: 179)
        }
    }

    private static func makePair(
        focus: Focus,
        tier: SimulationPowerTier,
        pairIndex: Int,
        seed: UInt64,
        context: BalanceContrastContext,
    ) -> BalanceContrastSupport.Pair? {
        switch focus {
        case let .sibling(f):
            guard isSiblingLegal(focus: f, tier: tier) else { return nil }
            return makeTalentPair(
                owner: f.owner,
                entityTalents: f.prefix.union([f.focusID]),
                baselineTalents: f.prefix.union([f.siblingID].compactMap(\.self)),
                tier: tier,
                pairIndex: pairIndex,
                context: context,
                pairSeed: seed,
            )
        case let .kit(f):
            guard isKitLegal(focus: f, tier: tier) else { return nil }
            return makeTalentPair(
                owner: f.owner,
                entityTalents: f.kit,
                baselineTalents: [],
                tier: tier,
                pairIndex: pairIndex,
                context: context,
                pairSeed: seed,
            )
        }
    }

    private static func makeTalentPair(
        owner: Combatant,
        entityTalents: Set<String>,
        baselineTalents: Set<String>,
        tier: SimulationPowerTier,
        pairIndex: Int,
        context: BalanceContrastContext,
        pairSeed: UInt64,
    ) -> BalanceContrastSupport.Pair {
        let base = BalanceContrastSupport.base(
            owner: owner,
            tier: tier,
            pairIndex: pairIndex,
            context: context,
            pairSeed: pairSeed,
        )
        return (
            base.matchup(ownerTalents: entityTalents),
            base.matchup(ownerTalents: baselineTalents),
        )
    }
}
