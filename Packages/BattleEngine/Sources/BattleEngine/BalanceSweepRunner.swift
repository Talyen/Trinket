import Foundation
import TrinketContent
import TrinketCore

public enum BalanceSweepRunner {
    public static func run(
        config: BalanceSweepConfig,
        policy: some PlayerPolicy = GreedyHeuristicPolicy(),
        heroes: [Combatant] = GameContent.heroes,
        pets: [Combatant] = GameContent.pets,
        enemies: [Enemy] = GameContent.enemies
    ) -> BalanceSweepReport {
        precondition(!heroes.isEmpty && !pets.isEmpty && !enemies.isEmpty)

        let started = ContinuousClock.now
        var records: [BalanceBattleRecord] = []
        records.reserveCapacity(config.battlesPerTier * config.tiers.count)

        for tier in config.tiers {
            for battleIndex in 0 ..< config.battlesPerTier {
                records.append(
                    simulateBattle(
                        config: config,
                        policy: policy,
                        heroes: heroes,
                        pets: pets,
                        enemies: enemies,
                        tier: tier,
                        battleIndex: battleIndex
                    )
                )
            }
        }

        let elapsed = ContinuousClock.now - started
        return BalanceSweepReport(
            config: config,
            policyID: policy.id,
            records: records,
            elapsedSeconds: Double(elapsed.components.seconds)
                + Double(elapsed.components.attoseconds) / 1e18
        )
    }

    private static func simulateBattle(
        config: BalanceSweepConfig,
        policy: some PlayerPolicy,
        heroes: [Combatant],
        pets: [Combatant],
        enemies: [Enemy],
        tier: SimulationPowerTier,
        battleIndex: Int
    ) -> BalanceBattleRecord {
        let battleSeed = config.seed
            &+ UInt64(tier.level) &* 1000003
            &+ UInt64(battleIndex) &* 97
        var rng = SeededRandomNumberGenerator(seed: battleSeed)

        let hero = heroes[battleIndex % heroes.count]
        let pet = pets[(battleIndex / max(heroes.count, 1)) % pets.count]
        let enemy = stratifiedEnemy(
            enemies: enemies,
            battleIndex: battleIndex,
            using: &rng
        )

        let heroLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: hero,
            level: tier.level,
            using: &rng
        )
        let petLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: pet,
            level: tier.level,
            using: &rng
        )

        let matchup = SimulationMatchupBuilder.build(
            hero: hero,
            pet: pet,
            enemy: enemy,
            tier: tier,
            heroLoadout: heroLoadout,
            petLoadout: petLoadout,
            seed: battleSeed,
            loadoutSampleIndex: battleIndex
        )

        let result = BattleSimulator.run(
            matchup: matchup,
            policy: policy,
            maxRounds: config.maxRounds,
            maxActions: config.maxActions
        )

        return BalanceBattleRecord(
            tier: tier,
            heroID: hero.id,
            petID: pet.id,
            enemyID: enemy.id,
            isBossOrElite: enemy.isBoss || enemy.isElite,
            heroAbilityIDs: matchup.context.heroLoadout.abilities.map(\.id),
            petAbilityIDs: matchup.context.petLoadout.abilities.map(\.id),
            affixIDs: matchup.context.heroAffixIDs + matchup.context.petAffixIDs,
            seed: battleSeed,
            result: result
        )
    }

    private static func stratifiedEnemy<RNG: RandomNumberGenerator>(
        enemies: [Enemy],
        battleIndex: Int,
        using randomNumberGenerator: inout RNG
    ) -> Enemy {
        let bosses = enemies.filter(\.isBoss)
        let elites = enemies.filter { $0.isElite && !$0.isBoss }
        let fodder = enemies.filter { !$0.isBoss && !$0.isElite }
        let bucket = battleIndex % 3
        let pool: [Enemy]
        switch bucket {
        case 0 where !fodder.isEmpty: pool = fodder
        case 1 where !elites.isEmpty: pool = elites
        case 2 where !bosses.isEmpty: pool = bosses
        default: pool = enemies
        }
        return pool.randomElement(using: &randomNumberGenerator) ?? enemies[battleIndex % enemies.count]
    }
}
