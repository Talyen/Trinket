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
        policy: some PlayerPolicy
    ) -> [PairedContrastSummary] {
        let foci = makeFoci(heroes: context.heroes, companions: context.companions)
        guard !foci.isEmpty else { return [] }

        let work = BalanceContrastSupport.workItems(
            fociCount: foci.count,
            tiers: context.config.tiers,
            battlesPerTier: context.config.battlesPerTier
        )

        let pairResults = ParallelMap.map(work, jobs: context.config.resolvedJobs) { item -> (Int, SimulationPowerTier, Bool, Bool)? in
            let focus = foci[item.focusIndex]
            guard focus.focus.tier.unlockLevel <= item.tier.level else { return nil }
            let pair = runPair(
                focus: focus,
                tier: item.tier,
                pairIndex: item.pairIndex,
                context: context,
                policy: policy
            )
            return (item.focusIndex, item.tier, pair.entityWon, pair.baselineWon)
        }

        return BalanceContrastSupport.aggregate(
            foci: foci.map { ($0.focus.id, $0.sibling.id, $0.owner.id) },
            pairResults: pairResults.compactMap(\.self),
            threshold: context.config.peerDeltaFlagThreshold
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

    private static func runPair(
        focus: Focus,
        tier: SimulationPowerTier,
        pairIndex: Int,
        context: BalanceContrastContext,
        policy: some PlayerPolicy
    ) -> (entityWon: Bool, baselineWon: Bool) {
        let pairSeed = context.config.seed
            &+ UInt64(tier.level) &* 900011
            &+ UInt64(pairIndex) &* 131
            &+ BalanceContrastSupport.stableHash64(focus.focus.id)
        var rng = SeededRandomNumberGenerator(seed: pairSeed)
        let setup = makePairSetup(
            focus: focus,
            tier: tier,
            pairIndex: pairIndex,
            context: context,
            pairSeed: pairSeed,
            using: &rng
        )
        return (
            BattleSimulator.run(
                matchup: setup.withEntity,
                policy: policy,
                maxRounds: context.config.maxRounds,
                maxActions: context.config.maxActions
            ).isVictory,
            BattleSimulator.run(
                matchup: setup.withBaseline,
                policy: policy,
                maxRounds: context.config.maxRounds,
                maxActions: context.config.maxActions
            ).isVictory
        )
    }

    private static func makePairSetup(
        focus: Focus,
        tier: SimulationPowerTier,
        pairIndex: Int,
        context: BalanceContrastContext,
        pairSeed: UInt64,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> (withEntity: ConfiguredSimulationMatchup, withBaseline: ConfiguredSimulationMatchup) {
        let partnerPool = focus.owner.role == .hero ? context.companions : context.heroes
        let partner = partnerPool.randomElement(using: &randomNumberGenerator) ?? partnerPool[0]
        let enemy = BalanceSampling.stratifiedEnemy(
            enemies: context.enemies,
            battleIndex: pairIndex,
            using: &randomNumberGenerator
        )
        let progression = SimulationMatchupBuilder.progression(level: tier.level)
        let ownerBase = SimulationMatchupBuilder.sampleLoadout(
            for: focus.owner,
            level: tier.level,
            using: &randomNumberGenerator
        )
        let partnerLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: partner,
            level: tier.level,
            using: &randomNumberGenerator
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
