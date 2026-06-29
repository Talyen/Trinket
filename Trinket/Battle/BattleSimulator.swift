private struct BattleSimulationMetricsAccumulator {
    private var abilityDamage = 0
    private var statusDamage = 0
    private var actorDamage: [String: Int] = [:]
    private var keywordDamage: [Keyword: Int] = [:]

    mutating func record(_ events: [BattleState.ActionEvent]) {
        for event in events {
            switch event.kind {
            case .ability:
                abilityDamage += event.amount
            case .status:
                statusDamage += event.amount
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
    static func run(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant = .trainingSlime,
        maxTicks: Int = 100
    ) -> BattleSimulationResult {
        run(
            BattleMatchup(hero: hero, pet: pet, enemy: enemy),
            options: BattleSimulationOptions(maxTicks: maxTicks)
        )
    }

    static func run(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant = .trainingSlime,
        options: BattleSimulationOptions
    ) -> BattleSimulationResult {
        run(
            BattleMatchup(hero: hero, pet: pet, enemy: enemy),
            options: options
        )
    }

    static func run(
        _ matchup: BattleMatchup,
        options: BattleSimulationOptions = BattleSimulationOptions()
    ) -> BattleSimulationResult {
        run(
            BattleState(hero: matchup.hero, pet: matchup.pet, enemy: matchup.enemy),
            options: options
        )
    }

    static func run(
        _ initialBattle: BattleState,
        maxTicks: Int = 100
    ) -> BattleSimulationResult {
        run(
            initialBattle,
            options: BattleSimulationOptions(maxTicks: maxTicks)
        )
    }

    static func run(
        _ initialBattle: BattleState,
        options: BattleSimulationOptions = BattleSimulationOptions()
    ) -> BattleSimulationResult {
        if let seed = options.seed {
            var rng = SeededRandomNumberGenerator(seed: seed)
            return run(initialBattle, options: options, rng: &rng)
        }

        var rng = SystemRandomNumberGenerator()
        return run(initialBattle, options: options, rng: &rng)
    }

    static func run<RNG: RandomNumberGenerator>(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant = .trainingSlime,
        options: BattleSimulationOptions = BattleSimulationOptions(),
        rng: inout RNG
    ) -> BattleSimulationResult {
        run(
            BattleMatchup(hero: hero, pet: pet, enemy: enemy),
            options: options,
            rng: &rng
        )
    }

    static func run<RNG: RandomNumberGenerator>(
        _ matchup: BattleMatchup,
        options: BattleSimulationOptions = BattleSimulationOptions(),
        rng: inout RNG
    ) -> BattleSimulationResult {
        run(
            BattleState(hero: matchup.hero, pet: matchup.pet, enemy: matchup.enemy),
            options: options,
            rng: &rng
        )
    }

    static func run<RNG: RandomNumberGenerator>(
        _ initialBattle: BattleState,
        options: BattleSimulationOptions = BattleSimulationOptions(),
        rng: inout RNG
    ) -> BattleSimulationResult {
        var battle = initialBattle
        var capturedEvents: [BattleState.ActionEvent] = []
        var metricsAccumulator = BattleSimulationMetricsAccumulator()
        let tickLimit = options.resolvedMaxTicks
        _ = rng

        while !battle.isEnemyDefeated, battle.tickCount < tickLimit {
            let tickEvents = battle.performNextAction()
            metricsAccumulator.record(tickEvents)
            if options.recordsEvents {
                capturedEvents.append(contentsOf: tickEvents)
            }
        }

        let capturedLog = options.recordsLog ? battle.log : []
        return BattleSimulationResult(
            matchup: BattleMatchup(hero: battle.hero, pet: battle.pet, enemy: battle.enemy),
            outcome: battle.isEnemyDefeated ? .victory : .tickLimit,
            tickCount: battle.tickCount,
            actionCount: battle.actionCount,
            finalEnemyHealth: battle.enemyHealth,
            finalEnemyStatuses: battle.activeEnemyStatuses,
            finalEnemyStatusSummaries: battle.enemyStatusSummaries,
            metrics: metricsAccumulator.metrics,
            events: capturedEvents,
            log: capturedLog
        )
    }

    static func runBatch(
        matchups: [BattleMatchup],
        options: BattleSimulationOptions = BattleSimulationOptions()
    ) -> [BattleBatchResult] {
        if let seed = options.seed {
            var rng = SeededRandomNumberGenerator(seed: seed)
            return runBatch(matchups: matchups, options: options, rng: &rng)
        }

        var rng = SystemRandomNumberGenerator()
        return runBatch(matchups: matchups, options: options, rng: &rng)
    }

    static func runBatch<RNG: RandomNumberGenerator>(
        matchups: [BattleMatchup],
        options: BattleSimulationOptions = BattleSimulationOptions(),
        rng: inout RNG
    ) -> [BattleBatchResult] {
        matchups.map { matchup in
            let results = (0..<options.resolvedRunCount).map { _ in
                run(matchup, options: options, rng: &rng)
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
