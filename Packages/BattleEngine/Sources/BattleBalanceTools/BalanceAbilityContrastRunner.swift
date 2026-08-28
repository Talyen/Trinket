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
        let roster = config.resolvedRoster
        let fociCount = foci(
            heroes: roster.heroes,
            companions: roster.companions,
            focusIDs: config.focusIDs
        ).count
        return fociCount * config.tiers.count * config.battlesPerTier
    }

    static func run(
        context: BalanceContrastContext,
        policy: PlayPolicy
    ) -> [PairedContrastSummary] {
        guard !context.heroes.isEmpty,
              !context.companions.isEmpty,
              !context.enemies.isEmpty
        else { return [] }

        let foci = foci(
            heroes: context.heroes,
            companions: context.companions,
            focusIDs: context.config.focusIDs
        )
        guard !foci.isEmpty else { return [] }

        return BalanceContrastSupport.runSweep(
            context: context,
            foci: foci,
            tiers: context.config.tiers,
            summarize: {
                (
                    entityID: $0.focus.id,
                    baselineID: $0.sibling.id,
                    ownerID: $0.owner.id,
                    baselineKind: .sibling,
                    nonCombat: false
                )
            },
            primes: (tier: 900011, pair: 131),
            makePair: { focus, tier, pairIndex, seed in
                makePairSetup(
                    focus: focus,
                    tier: tier,
                    pairIndex: pairIndex,
                    context: context,
                    pairSeed: seed
                )
            },
            policy: policy
        )
    }

    private static func makePairSetup(
        focus: Focus,
        tier: SimulationPowerTier,
        pairIndex: Int,
        context: BalanceContrastContext,
        pairSeed: UInt64
    ) -> (withEntity: ConfiguredSimulationMatchup, withBaseline: ConfiguredSimulationMatchup) {
        var rng = SeededRandomNumberGenerator(seed: pairSeed)
        let partner = BalanceContrastSupport.pickPartner(
            for: focus.owner,
            from: context,
            using: &rng
        )
        let enemy = BalanceContrastSupport.roundRobinEnemy(
            enemies: context.enemies,
            pairIndex: pairIndex
        )
        let ownerBase = SimulationMatchupBuilder.sampleLoadout(
            for: focus.owner,
            using: &rng
        )
        let partnerLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: partner,
            using: &rng
        )
        let focusLoadout = ownerBase.selecting(focus.focus)
        let siblingLoadout = ownerBase.selecting(focus.sibling)
        let gears = BalanceContrastSupport.sharedGear(
            owner: focus.owner,
            partner: partner,
            ownerLoadout: focusLoadout,
            partnerLoadout: partnerLoadout,
            tier: tier,
            pairSeed: pairSeed
        )
        return (
            BalanceContrastSupport.buildMatchup(
                .init(
                    owner: focus.owner,
                    partner: partner,
                    ownerLoadout: focusLoadout,
                    partnerLoadout: partnerLoadout,
                    ownerGear: gears.owner,
                    partnerGear: gears.partner,
                    enemy: enemy,
                    tier: tier,
                    seed: pairSeed
                )
            ),
            BalanceContrastSupport.buildMatchup(
                .init(
                    owner: focus.owner,
                    partner: partner,
                    ownerLoadout: siblingLoadout,
                    partnerLoadout: partnerLoadout,
                    ownerGear: gears.owner,
                    partnerGear: gears.partner,
                    enemy: enemy,
                    tier: tier,
                    seed: pairSeed
                )
            )
        )
    }
}
