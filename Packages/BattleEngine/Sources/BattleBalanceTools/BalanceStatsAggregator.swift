import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

public struct WinRateSummary: Equatable, Sendable {
    public var id: String
    public var ownerID: String?
    public var wins: Int
    public var battles: Int
    public var winRate: Double
    public var wilsonLow: Double
    public var wilsonHigh: Double
    public var deltaVsPeer: Double
    public var flagged: Bool
    public var flagReason: String?
    public var sampleTooLow: Bool
}

public struct PairCellSummary: Equatable, Sendable {
    public var leftID: String
    public var rightID: String
    public var wins: Int
    public var battles: Int
    public var winRate: Double
    public var deltaVsPeer: Double
    public var flagged: Bool
    public var flagReason: String?
}

public enum BalanceDurationThresholds {
    public static let trashMinRounds = 5
    public static let trashMaxRounds = 15
    public static let bossMinRounds = 15
    public static let bossMaxRounds = 30
    public static let flagRate = BalanceSweepConfig.durationFlagRateDefault

    public static var trashGoalBand: String {
        "\(trashMinRounds)-\(trashMaxRounds)"
    }

    public static var bossGoalBand: String {
        "\(bossMinRounds)-\(bossMaxRounds)"
    }
}

public struct BalanceDurationBucketStats: Equatable, Sendable {
    public var battles: Int
    public var shortBattles: Int
    public var longBattles: Int
    public var averageRounds: Double
    public var averageRoundsWhenShort: Double
    public var averageRoundsWhenLong: Double
    public var maxRounds: Int
    public var worstEnemyID: String?
    public var flagged: Bool
    public var flagReason: String?

    public var shortRate: Double {
        guard battles > 0 else { return 0 }
        return Double(shortBattles) / Double(battles)
    }

    public var longRate: Double {
        guard battles > 0 else { return 0 }
        return Double(longBattles) / Double(battles)
    }
}

public struct BalanceEnemyDurationStats: Equatable, Sendable {
    public var enemyID: String
    public var isBoss: Bool
    public var battles: Int
    public var averageRounds: Double
    public var shortRate: Double
    public var longRate: Double
}

public struct BalanceTierStats: Sendable {
    public var tier: SimulationPowerTier
    public var battles: Int
    public var decidedBattles: Int
    public var wins: Int
    public var timeouts: Int
    public var averageRounds: Double
    public var averagePartyHPOnWin: Double
    public var averageEnemyHPOnLoss: Double
    public var trashDuration: BalanceDurationBucketStats
    public var bossDuration: BalanceDurationBucketStats
    public var enemyDurations: [BalanceEnemyDurationStats]
    public var heroes: [WinRateSummary]
    public var heroesTrash: [WinRateSummary]
    public var heroesBoss: [WinRateSummary]
    public var companions: [WinRateSummary]
    public var companionsTrash: [WinRateSummary]
    public var companionsBoss: [WinRateSummary]
    public var enemies: [WinRateSummary]
    public var abilities: [WinRateSummary]
    public var talents: [WinRateSummary]
    public var enemyAbilities: [WinRateSummary]
    public var enemyTraits: [WinRateSummary]
    public var affixes: [WinRateSummary]
    public var heroCompanionCells: [PairCellSummary]
    public var heroEnemyCells: [PairCellSummary]
}

public enum BalanceStatsAggregator {
    public static func summarize(
        report: BalanceSweepReport,
        records: [BalanceBattleRecord]? = nil,
    ) -> [BalanceTierStats] {
        let source = records ?? report.records
        let recordsByTier = Dictionary(grouping: source, by: \.tier)
        return report.config.tiers.map { tier in
            summarizeTier(
                tier: tier,
                records: recordsByTier[tier] ?? [],
                config: report.config,
            )
        }
    }

    private static func summarizeTier(
        tier: SimulationPowerTier,
        records: [BalanceBattleRecord],
        config: BalanceSweepConfig,
    ) -> BalanceTierStats {
        let decided = records.filter(\.result.isDecided)
        let timeoutCount = records.count { $0.result.timedOut }
        let winCount = decided.count { $0.result.isVictory }
        let lossCount = decided.count { !$0.result.isVictory }
        let totalRoundsSum = records.reduce(0.0) { $0 + Double($1.result.rounds) }
        let partyHPWinSum = decided.filter(\.result.isVictory).reduce(0.0) {
            $0 + $1.result.partyHPRemainingFraction
        }
        let enemyHPLossSum = decided.filter { !$0.result.isVictory }.reduce(0.0) {
            $0 + $1.result.enemyHPRemainingFraction
        }
        let overallRate = decided.isEmpty ? 0.0 : Double(winCount) / Double(decided.count)
        let threshold = config.peerDeltaFlagThreshold

        let heroOverall = BalanceIdentityMargins.ownerMargins(
            records: decided,
            id: \.heroID,
            peerRate: overallRate,
            threshold: threshold,
        )
        let heroRates = Dictionary(uniqueKeysWithValues: heroOverall.map { ($0.id, $0.winRate) })
        let companionOverall = BalanceIdentityMargins.ownerMargins(
            records: decided,
            id: \.companionID,
            peerRate: overallRate,
            threshold: threshold,
        )
        let companionRates = Dictionary(uniqueKeysWithValues: companionOverall.map { ($0.id, $0.winRate) })

        return BalanceIdentityTables.assemble(
            IdentityTierInputs(
                tier: tier,
                records: records,
                decided: decided,
                config: config,
                overallRate: overallRate,
                winCount: winCount,
                lossCount: lossCount,
                timeoutCount: timeoutCount,
                totalRoundsSum: totalRoundsSum,
                partyHPWinSum: partyHPWinSum,
                enemyHPLossSum: enemyHPLossSum,
                heroOverall: heroOverall,
                companionOverall: companionOverall,
                heroRates: heroRates,
                companionRates: companionRates,
            ),
        )
    }

    public static func wilson(wins: Int, battles: Int, z: Double = 1.96) -> (low: Double, high: Double) {
        guard battles > 0 else { return (0, 0) }
        let n = Double(battles)
        let p = Double(wins) / n
        let z2 = z * z
        let denominator = 1 + z2 / n
        let center = p + z2 / (2 * n)
        let margin = z * ((p * (1 - p) / n + z2 / (4 * n * n)).squareRoot())
        let low = max(0, (center - margin) / denominator)
        let high = min(1, (center + margin) / denominator)
        return (low, high)
    }
}
