import BattleEngine
import Foundation
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
            talentContrasts: contrasts.talent,
            talentKitContrasts: contrasts.talentKit,
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
    ) -> (
        ability: [PairedContrastSummary],
        affix: [PairedContrastSummary],
        talent: [PairedContrastSummary],
        talentKit: [PairedContrastSummary]
    ) {
        let runAbility = config.mode == .abilityContrast || config.mode == .all
        let runAffix = config.mode == .affixContrast || config.mode == .all
        let runTalent = config.mode == .talentContrast || config.mode == .all
        guard runAbility || runAffix || runTalent else { return ([], [], [], []) }

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
        let talent = runTalent
            ? BalanceTalentContrastRunner.run(context: contrastContext, policy: policy)
            : (sibling: [], kit: [])
        return (ability, affix, talent.sibling, talent.kit)
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
        let work: [(SimulationPowerTier, Int)] = config.sliceWork(
            config.tiers.flatMap { tier in
                (0 ..< config.battlesPerTier).map { (tier, $0) }
            }
        )
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
        let heroLoadout = SimulationMatchupBuilder.sampleLoadout(for: hero, using: &rng)
        let companionLoadout = SimulationMatchupBuilder.sampleLoadout(for: companion, using: &rng)
        let matchup = SimulationMatchupBuilder.build(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tier: tier,
            heroLoadout: heroLoadout,
            companionLoadout: companionLoadout,
            seed: battleSeed,
            loadoutSampleIndex: battleIndex,
            heroTalents: SimulationMatchupBuilder.legalTalentKit(
                for: hero.id,
                level: tier.level,
                using: &rng
            ),
            companionTalents: SimulationMatchupBuilder.legalTalentKit(
                for: companion.id,
                level: tier.level,
                using: &rng
            )
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
            heroTalentIDs: matchup.context.heroTalentIDs,
            companionTalentIDs: matchup.context.companionTalentIDs,
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
        jobs _: Int,
        transform: @escaping @Sendable (Input) -> Output
    ) -> [Output] {
        guard !inputs.isEmpty else { return [] }
        // Sequential on the caller thread. Never hop to GCD/`Thread` pools:
        // those stacks are 512 KB and Debug combat frames overflow them.
        // Bulk CLI work uses process-isolated chunks instead.
        var results: [Output] = []
        results.reserveCapacity(inputs.count)
        for input in inputs {
            results.append(transform(input))
        }
        return results
    }
}
