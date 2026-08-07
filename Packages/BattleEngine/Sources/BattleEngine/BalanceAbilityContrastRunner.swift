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

    static func run(
        context: BalanceContrastContext,
        policy: GreedyHeuristicPolicy
    ) -> [PairedContrastSummary] {
        guard !context.heroes.isEmpty,
              !context.companions.isEmpty,
              !context.enemies.isEmpty
        else { return [] }

        let foci = makeFoci(heroes: context.heroes, companions: context.companions)
        guard !foci.isEmpty else { return [] }

        return BalanceContrastSupport.runSweep(
            context: context,
            foci: foci,
            tiers: context.config.tiers,
            summarize: { (entityID: $0.focus.id, baselineID: $0.sibling.id, ownerID: $0.owner.id) },
            primes: (tier: 900011, pair: 131),
            makePair: { focus, tier, pairIndex, seed in
                guard focus.focus.tier.unlockLevel <= tier.level else { return nil }
                return makePairSetup(
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

    private static func makeFoci(heroes: [Combatant], companions: [Combatant]) -> [Focus] {
        (heroes + companions).flatMap { owner -> [Focus] in
            AbilityTier.allCases.flatMap { tier -> [Focus] in
                let choices = owner.abilityChoices.abilities(for: tier)
                guard choices.count >= 2 else { return [] }
                return choices.compactMap { focus in
                    guard let sibling = choices.first(where: { $0.id != focus.id }) else { return nil }
                    return Focus(owner: owner, focus: focus, sibling: sibling)
                }
            }
        }
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
        let enemy = BalanceSampling.stratifiedEnemy(
            enemies: context.enemies,
            battleIndex: pairIndex,
            using: &rng
        )
        let progression = SimulationMatchupBuilder.progression(level: tier.level)
        let ownerBase = SimulationMatchupBuilder.sampleLoadout(
            for: focus.owner,
            level: tier.level,
            using: &rng
        )
        let partnerLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: partner,
            level: tier.level,
            using: &rng
        )
        let focusLoadout = ownerBase.selecting(focus.focus).unlocked(for: progression)
        let siblingLoadout = ownerBase.selecting(focus.sibling).unlocked(for: progression)
        let gears = sharedGear(
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
