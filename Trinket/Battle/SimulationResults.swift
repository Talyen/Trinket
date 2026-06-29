struct BattleSimulationOptions: Equatable {
    let maxTicks: Int
    let runCount: Int
    let seed: UInt64?
    let recordsEvents: Bool
    let recordsLog: Bool

    init(
        maxTicks: Int = 100,
        runCount: Int = 1,
        seed: UInt64? = nil,
        recordsEvents: Bool = true,
        recordsLog: Bool = true
    ) {
        self.maxTicks = maxTicks
        self.runCount = runCount
        self.seed = seed
        self.recordsEvents = recordsEvents
        self.recordsLog = recordsLog
    }

    var resolvedMaxTicks: Int {
        max(0, maxTicks)
    }

    var resolvedRunCount: Int {
        max(0, runCount)
    }
}

struct BattleMatchup: Equatable, Hashable {
    let hero: Combatant
    let pet: Combatant
    let enemy: Combatant

    init(hero: Combatant, pet: Combatant, enemy: Combatant = .trainingSlime) {
        self.hero = hero
        self.pet = pet
        self.enemy = enemy
    }
}

enum BattleSimulationOutcome: Equatable {
    case victory
    case tickLimit
}

struct BattleSimulationMetrics: Equatable {
    let totalDamage: Int
    let abilityDamage: Int
    let statusDamage: Int
    let actorDamage: [String: Int]
    let keywordDamage: [Keyword: Int]
}

struct BattleSimulationResult: Equatable {
    let matchup: BattleMatchup
    let outcome: BattleSimulationOutcome
    let tickCount: Int
    let actionCount: Int
    let finalEnemyHealth: Int
    let finalEnemyStatuses: [ActiveStatus]
    let finalEnemyStatusSummaries: [StatusSummary]
    let metrics: BattleSimulationMetrics
    let events: [BattleState.ActionEvent]
    let log: [BattleState.LogEntry]

    var didWin: Bool {
        outcome == .victory
    }

    var didHitTickLimit: Bool {
        outcome == .tickLimit
    }
}

struct BattleSimulationSummary: Equatable {
    let runCount: Int
    let winCount: Int
    let tickLimitCount: Int
    let winRate: Double
    let averageTickCount: Double
    let minimumTickCount: Int?
    let maximumTickCount: Int?
    let averageActionCount: Double
    let averageFinalEnemyHealth: Double
    let averageTotalDamage: Double
    let averageAbilityDamage: Double
    let averageStatusDamage: Double

    static func summarize(_ results: [BattleSimulationResult]) -> BattleSimulationSummary {
        let runCount = results.count
        let winCount = results.filter(\.didWin).count
        let tickLimitCount = results.filter(\.didHitTickLimit).count

        return BattleSimulationSummary(
            runCount: runCount,
            winCount: winCount,
            tickLimitCount: tickLimitCount,
            winRate: ratio(winCount, to: runCount),
            averageTickCount: average(results.map(\.tickCount)),
            minimumTickCount: results.map(\.tickCount).min(),
            maximumTickCount: results.map(\.tickCount).max(),
            averageActionCount: average(results.map(\.actionCount)),
            averageFinalEnemyHealth: average(results.map(\.finalEnemyHealth)),
            averageTotalDamage: average(results.map(\.metrics.totalDamage)),
            averageAbilityDamage: average(results.map(\.metrics.abilityDamage)),
            averageStatusDamage: average(results.map(\.metrics.statusDamage))
        )
    }

    private static func average(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    private static func ratio(_ value: Int, to total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(value) / Double(total)
    }
}

struct BattleBatchResult: Equatable {
    let matchup: BattleMatchup
    let options: BattleSimulationOptions
    let results: [BattleSimulationResult]
    let summary: BattleSimulationSummary
}
