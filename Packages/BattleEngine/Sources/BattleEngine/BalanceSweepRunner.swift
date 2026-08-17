import BattleEngine
import Foundation
import Synchronization
import TrinketContent
import TrinketCore

public enum BalanceSweepRunner {
    public static func run(
        config: BalanceSweepConfig,
        policy: GreedyHeuristicPolicy = GreedyHeuristicPolicy(),
        heroes: [Combatant] = GameContent.heroes,
        companions: [Combatant] = GameContent.companions,
        enemies: [Enemy] = GameContent.enemies
    ) -> BalanceSweepReport {
        precondition(!heroes.isEmpty && !companions.isEmpty && !enemies.isEmpty)

        let started = ContinuousClock.now
        let records = config.mode == .identity || config.mode == .all
            ? runIdentitySweep(
                config: config,
                policy: policy,
                heroes: heroes,
                companions: companions,
                enemies: enemies
            )
            : []
        let contrasts = runContrastsIfNeeded(
            config: config,
            policy: policy,
            heroes: heroes,
            companions: companions,
            enemies: enemies
        )
        let progression = runProgressionIfNeeded(config: config, policy: policy)

        let elapsed = ContinuousClock.now - started
        return BalanceSweepReport(
            config: config,
            policyID: policy.id,
            records: records,
            abilityContrasts: contrasts.ability,
            affixContrasts: contrasts.affix,
            progressionHotspots: progression.hotspots,
            progressionRecords: progression.records,
            progressionPlayerStates: progression.playerStates,
            progressionTruncatedRuns: progression.truncatedRuns,
            elapsedSeconds: Double(elapsed.components.seconds)
                + Double(elapsed.components.attoseconds) / 1e18
        )
    }

    private static func runContrastsIfNeeded(
        config: BalanceSweepConfig,
        policy: GreedyHeuristicPolicy,
        heroes: [Combatant],
        companions: [Combatant],
        enemies: [Enemy]
    ) -> (ability: [PairedContrastSummary], affix: [PairedContrastSummary]) {
        let runAbility = config.mode == .abilityContrast || config.mode == .all
        let runAffix = config.mode == .affixContrast || config.mode == .all
        guard runAbility || runAffix else { return ([], []) }

        let contrastContext = BalanceContrastContext(
            config: config,
            heroes: heroes,
            companions: companions,
            enemies: enemies
        )
        let ability = runAbility
            ? BalanceAbilityContrastRunner.run(context: contrastContext, policy: policy)
            : []
        let affix = runAffix
            ? BalanceAffixContrastRunner.run(context: contrastContext, policy: policy)
            : []
        return (ability, affix)
    }

    private static func runProgressionIfNeeded(
        config: BalanceSweepConfig,
        policy: GreedyHeuristicPolicy
    ) -> (
        records: [ProgressionBattleRecord],
        hotspots: [NodeHotspotSummary],
        playerStates: [PlayerProgressionState],
        truncatedRuns: Int
    ) {
        guard config.mode == .modeProgression || config.mode == .all else {
            return ([], [], [], 0)
        }
        return BalanceProgressionRunner.run(config: config, policy: policy)
    }

    private static func runIdentitySweep(
        config: BalanceSweepConfig,
        policy: GreedyHeuristicPolicy,
        heroes: [Combatant],
        companions: [Combatant],
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
                companions: companions,
                enemies: enemies,
                tier: entry.0,
                battleIndex: entry.1
            )
        }
    }

    private static func simulateIdentityBattle(
        config: BalanceSweepConfig,
        policy: GreedyHeuristicPolicy,
        heroes: [Combatant],
        companions: [Combatant],
        enemies: [Enemy],
        tier: SimulationPowerTier,
        battleIndex: Int
    ) -> BalanceBattleRecord {
        let battleSeed = config.seed
            &+ UInt64(tier.level) &* 1000003
            &+ UInt64(battleIndex) &* 97
        var rng = SeededRandomNumberGenerator(seed: battleSeed)

        let hero = heroes[battleIndex % heroes.count]
        let companion = companions[(battleIndex / max(heroes.count, 1)) % companions.count]
        let enemy = BalanceSampling.stratifiedEnemy(
            enemies: enemies,
            battleIndex: battleIndex,
            using: &rng
        )

        let heroLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: hero,
            using: &rng
        )
        let companionLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: companion,
            using: &rng
        )

        let matchup = SimulationMatchupBuilder.build(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tier: tier,
            heroLoadout: heroLoadout,
            companionLoadout: companionLoadout,
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
            companionID: companion.id,
            enemyID: enemy.id,
            isBoss: enemy.isBoss,
            heroAbilityIDs: matchup.context.heroLoadout.abilities.map(\.id),
            companionAbilityIDs: matchup.context.companionLoadout.abilities.map(\.id),
            enemyAbilityIDs: matchup.enemy.abilities.map(\.id),
            enemyTraitID: enemy.traitID,
            affixIDs: matchup.context.heroAffixIDs + matchup.context.companionAffixIDs,
            seed: battleSeed,
            result: result
        )
    }
}

enum BalanceSampling {
    static func stratifiedEnemy(
        enemies: [Enemy],
        battleIndex: Int,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> Enemy {
        precondition(!enemies.isEmpty, "stratifiedEnemy requires a non-empty enemy list")
        let normal = enemies.filter { !$0.isBoss }
        let bosses = enemies.filter(\.isBoss)
        let bucket = battleIndex % 2
        let pool: [Enemy] = switch bucket {
        case 0 where !normal.isEmpty: normal
        case 1 where !bosses.isEmpty: bosses
        default: enemies
        }
        return pool.randomElement(using: &randomNumberGenerator)
            ?? enemies[battleIndex % enemies.count]
    }
}

enum ParallelMap {
    static func map<Input: Sendable, Output: Sendable>(
        _ inputs: [Input],
        jobs: Int,
        transform: @escaping @Sendable (Input) -> Output
    ) -> [Output] {
        guard !inputs.isEmpty else { return [] }
        #if DEBUG
        // Debug builds use `-Onone`, whose large pipeline/harness frames overflow the
        // 512 KB GCD worker stacks used by `concurrentPerform`. Run the sweep on a
        // dedicated large-stack thread so balance diagnostics stay green in debug.
        var results: [Output] = []
        let done = DispatchSemaphore(value: 0)
        let worker = Thread {
            results = inputs.map(transform)
            done.signal()
        }
        worker.stackSize = 16 * 1024 * 1024
        worker.start()
        done.wait()
        return results
        #else
        if jobs <= 1 || inputs.count == 1 {
            return inputs.map(transform)
        }

        let buffer = ResultBuffer<Output>(count: inputs.count)
        let workerCount = min(jobs, inputs.count)
        // Concurrency-Safety: concurrentPerform is intentional for CLI parallelism;
        // slots are written via Mutex-backed ResultBuffer.
        DispatchQueue.concurrentPerform(iterations: workerCount) { worker in
            var index = worker
            while index < inputs.count {
                buffer.set(transform(inputs[index]), at: index)
                index += workerCount
            }
        }
        return buffer.values
        #endif
    }
}

private final class ResultBuffer<Value: Sendable>: Sendable {
    private let storage: Mutex<[Value?]>

    init(count: Int) {
        storage = Mutex(Array(repeating: nil, count: count))
    }

    func set(_ value: Value, at index: Int) {
        storage.withLock { array in
            array[index] = value
        }
    }

    var values: [Value] {
        storage.withLock { array in
            array.map { value in
                guard let value else {
                    preconditionFailure("ParallelMap left a nil slot")
                }
                return value
            }
        }
    }
}
