import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

enum BalanceAbilityContrastRunner {
    struct Focus {
        var owner: Combatant
        var focus: Ability
        var sibling: Ability
    }

    static func foci(heroes: [Combatant], companions: [Combatant], focusIDs: [String]) -> [Focus] {
        let wanted = Set(focusIDs)
        return (heroes + companions).flatMap { owner -> [Focus] in
            AbilityTier.allCases.flatMap { tier -> [Focus] in
                let choices = owner.abilityChoices.abilities(for: tier).sorted { $0.id < $1.id }
                guard choices.count >= 2 else { return [] }
                var pairs: [Focus] = []
                for i in 0 ..< choices.count {
                    for j in (i + 1) ..< choices.count {
                        guard wanted.isEmpty
                            || wanted.contains(choices[i].id)
                            || wanted.contains(choices[j].id)
                        else {
                            continue
                        }
                        pairs.append(Focus(owner: owner, focus: choices[i], sibling: choices[j]))
                    }
                }
                return pairs
            }
        }
    }

    static func workCount(config: BalanceSweepConfig) -> Int {
        BalanceContrastSupport.rosterFociWorkCount(config: config) {
            foci(heroes: $0, companions: $1, focusIDs: $2).count
        }
    }

    static func run(
        context: BalanceContrastContext,
        policy: PlayPolicy,
    ) -> [PairedContrastSummary] {
        BalanceContrastSupport.runSweep(
            context: context,
            policy: policy,
            foci: foci(
                heroes: context.heroes,
                companions: context.companions,
                focusIDs: context.config.focusIDs,
            ),
            summarize: {
                (
                    entityID: $0.focus.id,
                    baselineID: $0.sibling.id,
                    ownerID: $0.owner.id,
                    baselineKind: .sibling,
                    nonCombat: false,
                )
            },
            primes: { _ in (tier: 900011, pair: 131) },
            makePair: { focus, tier, pairIndex, seed in
                makePairSetup(
                    focus: focus,
                    tier: tier,
                    pairIndex: pairIndex,
                    context: context,
                    pairSeed: seed,
                )
            },
        )
    }

    private static func makePairSetup(
        focus: Focus,
        tier: SimulationPowerTier,
        pairIndex: Int,
        context: BalanceContrastContext,
        pairSeed: UInt64,
    ) -> BalanceContrastSupport.Pair {
        var base = BalanceContrastSupport.sampleBasePair(
            owner: focus.owner,
            pairIndex: pairIndex,
            context: context,
            tier: tier,
            pairSeed: pairSeed,
        )
        let siblingLoadout = base.ownerLoadout.selecting(focus.sibling)
        // Both variants wear gear aligned to the focus loadout; keep historical sampling.
        base.ownerLoadout = base.ownerLoadout.selecting(focus.focus)
        base.prepareSharedGear()
        return (
            base.matchup(),
            base.matchup(ownerLoadout: siblingLoadout),
        )
    }
}
