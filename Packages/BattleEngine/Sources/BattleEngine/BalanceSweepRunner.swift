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
        let policyID = policy.id
        var records: [BalanceBattleRecord] = []
        var abilityContrasts: [PairedContrastSummary] = []
        var affixContrasts: [PairedContrastSummary] = []

        let runIdentity = config.mode == .identity || config.mode == .all
        let runAbility = config.mode == .abilityContrast || config.mode == .all
        let runAffix = config.mode == .affixContrast || config.mode == .all

        if runIdentity {
            records = runIdentitySweep(
                config: config,
                policy: policy,
                heroes: heroes,
                pets: pets,
                enemies: enemies
            )
        }
        if runAbility {
            abilityContrasts = BalanceContrastRunner.runAbilityContrasts(
                config: config,
                policy: policy,
                heroes: heroes,
                pets: pets,
                enemies: enemies
            )
        }
        if runAffix {
            affixContrasts = BalanceContrastRunner.runAffixContrasts(
                config: config,
                policy: policy,
                heroes: heroes,
                pets: pets,
                enemies: enemies
            )
        }

        let elapsed = ContinuousClock.now - started
        return BalanceSweepReport(
            config: config,
            policyID: policyID,
            records: records,
            abilityContrasts: abilityContrasts,
            affixContrasts: affixContrasts,
            elapsedSeconds: Double(elapsed.components.seconds)
                + Double(elapsed.components.attoseconds) / 1e18
        )
    }

    private static func runIdentitySweep(
        config: BalanceSweepConfig,
        policy: some PlayerPolicy,
        heroes: [Combatant],
        pets: [Combatant],
        enemies: [Enemy]
    ) -> [BalanceBattleRecord] {
        let work: [(SimulationPowerTier, Int)] = config.tiers.flatMap { tier in
            (0 ..< config.battlesPerTier).map { (tier, $0) }
        }
        return ParallelMap.map(work, jobs: config.resolvedJobs) { entry in
            simulateIdentityBattle(
                config: config,
                policy: policy,
                heroes: heroes,
                pets: pets,
                enemies: enemies,
                tier: entry.0,
                battleIndex: entry.1
            )
        }
    }

    private static func simulateIdentityBattle(
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
        let enemy = BalanceSampling.stratifiedEnemy(
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
}

enum BalanceSampling {
    static func stratifiedEnemy<RNG: RandomNumberGenerator>(
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

enum ParallelMap {
    static func map<Input: Sendable, Output: Sendable>(
        _ inputs: [Input],
        jobs: Int,
        transform: @Sendable (Input) -> Output
    ) -> [Output] {
        guard !inputs.isEmpty else { return [] }
        if jobs <= 1 || inputs.count == 1 {
            return inputs.map(transform)
        }

        let buffer = ResultBuffer<Output>(count: inputs.count)
        let workerCount = min(jobs, inputs.count)
        DispatchQueue.concurrentPerform(iterations: workerCount) { worker in
            var index = worker
            while index < inputs.count {
                buffer.set(transform(inputs[index]), at: index)
                index += workerCount
            }
        }
        return buffer.values
    }
}

private final class ResultBuffer<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Value?]

    init(count: Int) {
        storage = Array(repeating: nil, count: count)
    }

    func set(_ value: Value, at index: Int) {
        lock.lock()
        storage[index] = value
        lock.unlock()
    }

    var values: [Value] {
        lock.lock()
        defer { lock.unlock() }
        return storage.map { value in
            guard let value else {
                preconditionFailure("ParallelMap left a nil slot")
            }
            return value
        }
    }
}
