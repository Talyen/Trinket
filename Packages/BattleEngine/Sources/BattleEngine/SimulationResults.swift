import Foundation
import TrinketContent
import TrinketCore

public struct BattleSimulationOptions: Equatable {
    public let maxTicks: Int
    public let runCount: Int
    public let seed: UInt64?
    public let recordsEvents: Bool
    public let recordsLog: Bool
    /// When `false` (default), `BattleSimulator` skips per-tick log rebuilds and
    /// reduces the log once at the end from `events` when `recordsLog` is `true`.
    /// When `true`, an incremental `BattleLogProjection` is maintained on
    /// `BattleState` during the run.
    public let rebuildLogEachStep: Bool

    public init(
        maxTicks: Int = 100,
        runCount: Int = 1,
        seed: UInt64? = nil,
        recordsEvents: Bool = true,
        recordsLog: Bool = true,
        rebuildLogEachStep: Bool = false
    ) {
        self.maxTicks = maxTicks
        self.runCount = runCount
        self.seed = seed
        self.recordsEvents = recordsEvents
        self.recordsLog = recordsLog
        self.rebuildLogEachStep = rebuildLogEachStep
    }

    public var resolvedMaxTicks: Int {
        max(0, maxTicks)
    }

    public var resolvedRunCount: Int {
        max(0, runCount)
    }
}

public struct BattleMatchup: Equatable, Hashable {
    public let hero: Combatant
    public let pet: Combatant
    public let enemy: Combatant

    public init(hero: Combatant, pet: Combatant, enemy: Combatant? = nil) {
        self.hero = hero
        self.pet = pet
        self.enemy = enemy ?? Enemy.fallbackCombatant
    }

    public func combatant(for participant: BattleParticipant) -> Combatant {
        switch participant {
        case .hero: return hero
        case .pet: return pet
        case .enemy: return enemy
        }
    }
}

public enum BattleSimulationOutcome: Equatable {
    case victory
    case defeat
    case tickLimit

    public static func resolve(isPartyDefeated: Bool, isEnemyDefeated: Bool) -> BattleSimulationOutcome? {
        if isEnemyDefeated, isPartyDefeated { return .victory }
        if isPartyDefeated { return .defeat }
        if isEnemyDefeated { return .victory }
        return nil
    }
}

public struct BattleSimulationMetrics: Equatable {
    public let totalDamage: Int
    public let abilityDamage: Int
    public let statusDamage: Int
    public let actorDamage: [String: Int]
    public let keywordDamage: [Keyword: Int]
}

public struct BattleSimulationResult: Equatable {
    public let matchup: BattleMatchup
    public let outcome: BattleSimulationOutcome
    public let tickCount: Int
    public let actionCount: Int
    public let finalEnemyHealth: Int
    public let finalEnemyEffects: [ActiveEffect]
    public let finalEnemyEffectSummaries: [EffectSummary]
    public let finalHeroHealth: Int
    public let finalPetHealth: Int
    public let finalHeroEffects: [ActiveEffect]
    public let finalPetEffects: [ActiveEffect]
    public let finalHeroEffectSummaries: [EffectSummary]
    public let finalPetEffectSummaries: [EffectSummary]
    public let metrics: BattleSimulationMetrics
    public let events: [ActionEvent]
    public let log: [LogEntry]

    public var didWin: Bool {
        outcome == .victory
    }

    public var didHitTickLimit: Bool {
        outcome == .tickLimit
    }
}

public struct BattleSimulationSummary: Equatable {
    public let runCount: Int
    public let winCount: Int
    public let tickLimitCount: Int
    public let winRate: Double
    public let averageTickCount: Double
    public let minimumTickCount: Int?
    public let maximumTickCount: Int?
    public let averageActionCount: Double
    public let averageFinalEnemyHealth: Double
    public let averageTotalDamage: Double
    public let averageAbilityDamage: Double
    public let averageStatusDamage: Double

    public static func summarize(_ results: [BattleSimulationResult]) -> BattleSimulationSummary {
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

public struct BattleBatchResult: Equatable {
    public let matchup: BattleMatchup
    public let options: BattleSimulationOptions
    public let results: [BattleSimulationResult]
    public let summary: BattleSimulationSummary
}
