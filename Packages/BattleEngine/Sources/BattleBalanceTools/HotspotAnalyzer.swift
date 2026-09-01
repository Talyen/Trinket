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

    public init(
        step: ModeProgressionStep,
        playerLevel: Int,
        enemyLevel: Int,
        seed: UInt64,
        result: BattleSimResult,
    ) {
        self.step = step
        self.playerLevel = playerLevel
        self.enemyLevel = enemyLevel
        self.seed = seed
        self.result = result
    }
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

    public init(
        step: ModeProgressionStep,
        battles: Int,
        wins: Int,
        winRate: Double,
        wilsonLow: Double,
        wilsonHigh: Double,
        averagePlayerLevel: Double,
        averageEnemyLevel: Double,
        averageEnemyPowerRating: Double,
        status: HotspotStatus,
        flagReason: String? = nil,
    ) {
        self.step = step
        self.battles = battles
        self.wins = wins
        self.winRate = winRate
        self.wilsonLow = wilsonLow
        self.wilsonHigh = wilsonHigh
        self.averagePlayerLevel = averagePlayerLevel
        self.averageEnemyLevel = averageEnemyLevel
        self.averageEnemyPowerRating = averageEnemyPowerRating
        self.status = status
        self.flagReason = flagReason
    }

    public var isFlagged: Bool {
        status != .smooth
    }
}

public enum HotspotAnalyzer {
    public static let targetLowerBound = 0.80
    public static let targetUpperBound = 0.95

    public static func analyze(records: [ProgressionBattleRecord]) -> [NodeHotspotSummary] {
        var buckets: [String: (step: ModeProgressionStep, records: [ProgressionBattleRecord])] = [:]
        for record in records {
            var entry = buckets[record.step.id] ?? (record.step, [])
            entry.records.append(record)
            buckets[record.step.id] = entry
        }

        let summaries = buckets.values.map { step, recs in
            let total = recs.count
            let wins = recs.filter(\.result.isVictory).count
            let winRate = total == 0 ? 0.0 : Double(wins) / Double(total)
            let wilson = BalanceStatsAggregator.wilson(wins: wins, battles: total)

            let avgPlayer = total == 0 ? 0.0 : Double(recs.reduce(0) { $0 + $1.playerLevel }) / Double(total)
            let avgEnemy = total == 0 ? 0.0 : Double(recs.reduce(0) { $0 + $1.enemyLevel }) / Double(total)
            let avgPowerRating = averageEnemyPowerRating(for: step, averageEnemyLevel: avgEnemy)
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

        return summaries.sorted { lhs, rhs in
            if lhs.step.mode != rhs.step.mode {
                return lhs.step.mode.rawValue < rhs.step.mode.rawValue
            }
            if lhs.step.containerID != rhs.step.containerID {
                return lhs.step.containerID < rhs.step.containerID
            }
            return lhs.step.stepIndex < rhs.step.stepIndex
        }
    }

    private static func averageEnemyPowerRating(
        for step: ModeProgressionStep,
        averageEnemyLevel: Double,
    ) -> Double {
        guard let enemy = GameContent.enemy(matching: step.enemyID) else { return 0 }
        let level = max(1, Int(averageEnemyLevel.rounded()))
        let snapshot = CombatantLevelScaler.powerRating(for: enemy, level: level)
        return Double(snapshot.maxHealth) * (1 + snapshot.rawDamagePercent)
    }
}
