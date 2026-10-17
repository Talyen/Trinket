import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

public struct ProgressionBattleRecord: Equatable, Codable, Sendable {
    public var step: ModeProgressionStep
    public var playerLevel: Int
    public var enemyLevel: Int
    public var seed: UInt64
    public var result: BattleSimResult
}

public enum HotspotStatus: String, CaseIterable, Codable, Sendable {
    case overtuned
    case undertuned
    case levelGapWall = "level-gap-wall"
    case smooth

    public var displayName: String {
        switch self {
        case .overtuned: "OVERTUNED"
        case .undertuned: "UNDERTUNED"
        case .levelGapWall: "LEVEL WALL"
        case .smooth: "SMOOTH"
        }
    }
}

public struct NodeHotspotSummary: Equatable, Codable, Sendable {
    public var step: ModeProgressionStep
    /// Decided samples used for the win rate and confidence interval.
    public var battles: Int
    public var wins: Int
    public var winRate: Double
    public var wilsonLow: Double
    public var wilsonHigh: Double
    public var averagePlayerLevel: Double
    public var averageEnemyLevel: Double
    public var averageEnemyPowerRating: Double
    public var status: HotspotStatus
    public var flagReason: String?

    public var isFlagged: Bool {
        status != .smooth
    }
}

public enum HotspotAnalyzer {
    public static let targetLowerBound = 0.80
    public static let targetUpperBound = 0.95

    private struct EncounterKey: Hashable {
        let stepID: String
        let enemyID: String
    }

    /// Keep the first encounter descriptor even when every sample times out.
    private struct EncounterTally {
        let step: ModeProgressionStep
        var battles = 0
        var wins = 0
        var playerLevels = 0.0
        var enemyLevels = 0.0

        mutating func record(_ record: ProgressionBattleRecord) {
            guard record.result.isDecided else { return }
            battles += 1
            if record.result.isVictory {
                wins += 1
            }
            playerLevels += Double(record.playerLevel)
            enemyLevels += Double(record.enemyLevel)
        }
    }

    public static func analyze(records: [ProgressionBattleRecord]) -> [NodeHotspotSummary] {
        // Recovery jobs award XP but are not advancing-content difficulty nodes.
        var buckets: [EncounterKey: EncounterTally] = [:]
        for record in records where record.step.mode != .contract {
            let key = EncounterKey(stepID: record.step.id, enemyID: record.step.enemyID)
            buckets[key, default: EncounterTally(step: record.step)].record(record)
        }

        let summaries = buckets.values.map(summarize)

        return summaries.sorted { lhs, rhs in
            if lhs.step.mode != rhs.step.mode {
                return lhs.step.mode.rawValue < rhs.step.mode.rawValue
            }
            if lhs.step.containerID != rhs.step.containerID {
                return lhs.step.containerID < rhs.step.containerID
            }
            if lhs.step.stepIndex != rhs.step.stepIndex {
                return lhs.step.stepIndex < rhs.step.stepIndex
            }
            return lhs.step.enemyID < rhs.step.enemyID
        }
    }

    private static func summarize(_ tally: EncounterTally) -> NodeHotspotSummary {
        let step = tally.step
        let total = tally.battles
        let wins = tally.wins
        let winRate = total == 0 ? 0.0 : Double(wins) / Double(total)
        let wilson = BalanceStatsAggregator.wilson(wins: wins, battles: total)

        let avgPlayer = total == 0 ? 0.0 : tally.playerLevels / Double(total)
        let avgEnemy = total == 0 ? 0.0 : tally.enemyLevels / Double(total)
        let avgPowerRating = total == 0 ? 0 : averageEnemyPowerRating(for: step, averageEnemyLevel: avgEnemy)
        let levelGap = avgEnemy - avgPlayer

        let status: HotspotStatus
        let reason: String?
        let minBattles = BalanceSweepConfig.identityFlagMinBattles
        let ciExcludesLow = wilson.high < targetLowerBound
        let ciExcludesHigh = wilson.low > targetUpperBound

        if total >= minBattles, winRate < targetLowerBound, ciExcludesLow {
            if levelGap >= 3.0 {
                status = .levelGapWall
                reason = String(format: "Level Gap (+%.1f levels)", levelGap)
            } else {
                status = .overtuned
                reason = String(format: "Win rate %.1f%% below 80%%", winRate * 100)
            }
        } else if total >= minBattles, winRate > targetUpperBound, ciExcludesHigh {
            status = .undertuned
            reason = String(format: "Win rate %.1f%% above 95%%", winRate * 100)
        } else {
            status = .smooth
            reason = nil
        }

        return NodeHotspotSummary(
            step: step,
            battles: total,
            wins: wins,
            winRate: winRate,
            wilsonLow: wilson.low,
            wilsonHigh: wilson.high,
            averagePlayerLevel: avgPlayer,
            averageEnemyLevel: avgEnemy,
            averageEnemyPowerRating: avgPowerRating,
            status: status,
            flagReason: reason,
        )
    }

    private static func averageEnemyPowerRating(
        for step: ModeProgressionStep,
        averageEnemyLevel: Double,
    ) -> Double {
        guard let enemy = GameContent.enemy(matching: step.enemyID) else { return 0 }
        let level = max(1, CombatRounding.rounded(averageEnemyLevel))
        let profile = step.scaling.resolve(partyAverageLevel: level).profile
        let snapshot = CombatantLevelScaler.powerRating(for: enemy, level: level, profile: profile)
        return Double(snapshot.maxHealth) * (1 + snapshot.rawDamagePercent)
    }
}
