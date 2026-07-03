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
            case .status:
                statusDamage += event.amount
            case .effect, .milestone:
                break
            }

            actorDamage[event.actorName, default: 0] += event.amount
            keywordDamage[event.keyword, default: 0] += event.amount
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

enum BattleSimulator {
    /// Runs a single battle to completion or to `maxTicks`. Convenience
    /// overload for the common call shape.
    static func run(
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
    static func run(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant? = nil,
        options: BattleSimulationOptions
    ) -> BattleSimulationResult {
        let resolvedEnemy = enemy ?? Enemy.randomNormalCombatant
        return run(
            BattleMatchup(hero: hero, pet: pet, enemy: resolvedEnemy),
            options: options
        )
    }

    /// Runs a single battle for the given matchup.
    static func run(
        _ matchup: BattleMatchup,
        options: BattleSimulationOptions = BattleSimulationOptions()
    ) -> BattleSimulationResult {
        run(
            BattleState(hero: matchup.hero, pet: matchup.pet, enemy: matchup.enemy, rngSeed: options.seed),
            options: options
        )
    }

    /// Drives an already-constructed `BattleState` to completion or
    /// `options.resolvedMaxTicks`. Determinism is controlled by the seed
    /// already baked into `BattleState.rng`. Prefer
    /// `BattleStateTestFactory.makeBattle(...)` in tests (seed `0`).
    static func run(
        _ initialBattle: BattleState,
        options: BattleSimulationOptions = BattleSimulationOptions()
    ) -> BattleSimulationResult {
        var battle = initialBattle
        var capturedEvents: [ActionEvent] = []
        var metricsAccumulator = BattleSimulationMetricsAccumulator()
        let tickLimit = options.resolvedMaxTicks

        while !battle.isBattleOver, battle.tickCount < tickLimit {
            let tickEvents = battle.advanceOneStep().events
            metricsAccumulator.record(tickEvents)
            if options.recordsEvents {
                capturedEvents.append(contentsOf: tickEvents)
            }
        }

        let capturedLog = options.recordsLog ? battle.log : []
        let outcome: BattleSimulationOutcome
        if battle.isEnemyDefeated {
            outcome = .victory
        } else if battle.isPartyDefeated {
            outcome = .defeat
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
    static func runBatch(
        matchups: [BattleMatchup],
        options: BattleSimulationOptions = BattleSimulationOptions()
    ) -> [BattleBatchResult] {
        matchups.map { matchup in
            let results = (0 ..< options.resolvedRunCount).map { _ in
                run(matchup, options: options)
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
