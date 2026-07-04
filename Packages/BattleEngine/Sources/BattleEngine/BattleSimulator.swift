import Foundation
import TrinketCore
import TrinketContent

private struct BattleSimulationMetricsAccumulator {
    private var abilityDamage = 0
    private var statusDamage = 0
    private var actorDamage: [String: Int] = [:]
    private var keywordDamage: [Keyword: Int] = [:]

    mutating func record(_ events: [ActionEvent]) {
        for event in events {
            switch event.kind {
            case .ability:
                abilityDamage += event.amount
                actorDamage[event.actorName, default: 0] += event.amount
                keywordDamage[event.keyword, default: 0] += event.amount
            case .status:
                statusDamage += event.amount
                actorDamage[event.actorName, default: 0] += event.amount
                keywordDamage[event.keyword, default: 0] += event.amount
            case .effect, .milestone:
                break
            }
        }
    }

    var metrics: BattleSimulationMetrics {
        BattleSimulationMetrics(
            totalDamage: abilityDamage + statusDamage,
            abilityDamage: abilityDamage,
            statusDamage: statusDamage,
            actorDamage: actorDamage,
            keywordDamage: keywordDamage
        )
    }
}

public enum BattleSimulator {
    /// Runs a single battle to completion or to `maxTicks`. Convenience
    /// overload for the common call shape.
    public static func run(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant? = nil,
        maxTicks: Int = 100
    ) -> BattleSimulationResult {
        run(
            hero: hero,
            pet: pet,
            enemy: enemy,
            options: BattleSimulationOptions(maxTicks: maxTicks)
        )
    }

    /// Runs a single battle to completion or to `options.resolvedMaxTicks`.
    public static func run(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant? = nil,
        options: BattleSimulationOptions
    ) -> BattleSimulationResult {
        let resolvedEnemy = enemy ?? Enemy.fallbackCombatant
        return run(
            BattleMatchup(hero: hero, pet: pet, enemy: resolvedEnemy),
            options: options
        )
    }

    /// Runs a single battle for the given matchup.
    public static func run(
        _ matchup: BattleMatchup,
        options: BattleSimulationOptions = BattleSimulationOptions()
    ) -> BattleSimulationResult {
        run(
            ConfiguredSimulationMatchup(
                hero: matchup.hero,
                pet: matchup.pet,
                enemy: matchup.enemy,
                heroModifiers: .zero,
                petModifiers: .zero,
                context: SimulationBuildContext(
                    tier: .early,
                    heroLoadout: matchup.hero.abilityLoadout,
                    petLoadout: matchup.pet.abilityLoadout,
                    loadoutSampleIndex: 0,
                    seed: options.seed ?? 0
                ),
                enemyID: matchup.enemy.id,
                isBoss: false
            ),
            options: options
        )
    }

    /// Runs a production-faithful configured matchup with gear modifiers applied.
    public static func run(
        _ configured: ConfiguredSimulationMatchup,
        options: BattleSimulationOptions = BattleSimulationOptions()
    ) -> BattleSimulationResult {
        let useIncrementalLog = options.recordsLog && options.rebuildLogEachStep
        return run(
            BattleState(
                hero: configured.hero,
                pet: configured.pet,
                enemy: configured.enemy,
                heroModifiers: configured.heroModifiers,
                petModifiers: configured.petModifiers,
                rngSeed: options.seed,
                tracksLog: useIncrementalLog
            ),
            options: options
        )
    }

    /// Drives an already-constructed `BattleState` to completion or
    /// `options.resolvedMaxTicks`. Determinism is controlled by the seed
    /// already baked into `BattleState.rng`. Prefer
    /// `BattleStateTestFactory.makeBattle(...)` in tests (seed `0`).
    public static func run(
        _ initialBattle: BattleState,
        options: BattleSimulationOptions = BattleSimulationOptions()
    ) -> BattleSimulationResult {
        var battle = initialBattle
        var capturedEvents: [ActionEvent] = []
        if options.recordsEvents {
            capturedEvents = battle.events
        }
        var metricsAccumulator = BattleSimulationMetricsAccumulator()
        let tickLimit = options.resolvedMaxTicks
        let useIncrementalLog = options.recordsLog && options.rebuildLogEachStep

        while !battle.isBattleOver, battle.tickCount < tickLimit {
            let tickEvents = battle.advanceOneStep(rebuildLog: useIncrementalLog).events
            metricsAccumulator.record(tickEvents)
            if options.recordsEvents {
                capturedEvents.append(contentsOf: tickEvents)
            }
        }

        let capturedLog: [LogEntry]
        if options.recordsLog {
            if useIncrementalLog {
                battle.syncLog()
                capturedLog = battle.log
            } else {
                capturedLog = BattleLogProjection.entries(from: battle.events, matchup: battle.matchup)
            }
        } else {
            capturedLog = []
        }
        let outcome: BattleSimulationOutcome
        if battle.isPartyDefeated {
            outcome = .defeat
        } else if battle.isEnemyDefeated {
            outcome = .victory
        } else {
            outcome = .tickLimit
        }

        return BattleSimulationResult(
            matchup: BattleMatchup(hero: battle.hero, pet: battle.pet, enemy: battle.enemy),
            outcome: outcome,
            tickCount: battle.tickCount,
            actionCount: battle.actionCount,
            finalEnemyHealth: battle.health(of: battle.enemy),
            finalEnemyEffects: battle.activeEffects(of: battle.enemy),
            finalEnemyEffectSummaries: battle.effectSummaries(of: battle.enemy),
            finalHeroHealth: battle.health(of: battle.hero),
            finalPetHealth: battle.health(of: battle.pet),
            finalHeroEffects: battle.activeEffects(of: battle.hero),
            finalPetEffects: battle.activeEffects(of: battle.pet),
            finalHeroEffectSummaries: battle.effectSummaries(of: battle.hero),
            finalPetEffectSummaries: battle.effectSummaries(of: battle.pet),
            metrics: metricsAccumulator.metrics,
            events: capturedEvents,
            log: capturedLog
        )
    }

    /// Runs every matchup the requested number of times, summarizing the
    /// results. Useful for win-rate sweeps.
    public static func runBatch(
        matchups: [BattleMatchup],
        options: BattleSimulationOptions = BattleSimulationOptions()
    ) -> [BattleBatchResult] {
        matchups.map { matchup in
            let results = (0 ..< options.resolvedRunCount).map { runIndex in
                let runOptions = BattleSimulationOptions(
                    maxTicks: options.maxTicks,
                    runCount: options.runCount,
                    seed: options.seed.map { $0 &+ UInt64(runIndex) },
                    recordsEvents: options.recordsEvents,
                    recordsLog: options.recordsLog,
                    rebuildLogEachStep: options.rebuildLogEachStep
                )
                return run(matchup, options: runOptions)
            }

            return BattleBatchResult(
                matchup: matchup,
                options: options,
                results: results,
                summary: BattleSimulationSummary.summarize(results)
            )
        }
    }
}
