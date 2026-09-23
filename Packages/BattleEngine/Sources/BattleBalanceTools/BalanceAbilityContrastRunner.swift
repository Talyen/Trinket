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
        let sampled = BalanceContrastSupport.sampleBasePair(
            owner: focus.owner,
            pairIndex: pairIndex,
            context: context,
            pairSeed: pairSeed,
        )
        let focusLoadout = sampled.ownerLoadout.selecting(focus.focus)
        let siblingLoadout = sampled.ownerLoadout.selecting(focus.sibling)
        // Gear stays aligned to the focus loadout, matching historical
        // sampling: both sides of the pair wear the same gear so only the
        // loadout choice varies.
        let gears = BalanceContrastSupport.sharedGear(
            owner: focus.owner,
            partner: sampled.partner,
            ownerLoadout: focusLoadout,
            partnerLoadout: sampled.partnerLoadout,
            tier: tier,
            pairSeed: pairSeed,
        )
        let base = ContrastMatchupBase(
            owner: focus.owner,
            partner: sampled.partner,
            enemy: sampled.enemy,
            ownerLoadout: focusLoadout,
            partnerLoadout: sampled.partnerLoadout,
            ownerGear: gears.owner,
            partnerGear: gears.partner,
            tier: tier,
            seed: pairSeed,
        )
        return (
            base.matchup(ownerLoadout: focusLoadout),
            base.matchup(ownerLoadout: siblingLoadout),
        )
    }
}
