import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

public struct WinRateSummary: Equatable, Sendable {
    public var id: String
    public var wins: Int
    public var battles: Int
    public var winRate: Double
    public var wilsonLow: Double
    public var wilsonHigh: Double
    public var deltaVsPeer: Double
    public var flagged: Bool
    public var flagReason: String?
}

/// Gameplay duration goal bands on sim `rounds` (`turnCount` = player phase + enemy phase).
public enum BalanceDurationThresholds {
    public static let trashMinRounds = 5
    public static let trashMaxRounds = 10
    public static let bossMinRounds = 10
    public static let bossMaxRounds = 20

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

    public var shortRate: Double {
        guard battles > 0 else { return 0 }
        return Double(shortBattles) / Double(battles)
    }

    public var longRate: Double {
        guard battles > 0 else { return 0 }
        return Double(longBattles) / Double(battles)
    }
}

public struct BalanceTierStats: Sendable {
    public var tier: SimulationPowerTier
    public var battles: Int
    public var wins: Int
    public var timeouts: Int
    public var averageRounds: Double
    public var averagePartyHPOnWin: Double
    public var averageEnemyHPOnLoss: Double
    public var trashDuration: BalanceDurationBucketStats
    public var bossDuration: BalanceDurationBucketStats
    public var heroes: [WinRateSummary]
    public var companions: [WinRateSummary]
    public var enemies: [WinRateSummary]
    public var abilities: [WinRateSummary]
    public var enemyAbilities: [WinRateSummary]
    public var enemyTraits: [WinRateSummary]
    public var affixes: [WinRateSummary]
}

public enum BalanceStatsAggregator {
    public static func summarize(
        report: BalanceSweepReport
    ) -> [BalanceTierStats] {
        report.config.tiers.map { tier in
            summarizeTier(
                tier: tier,
                records: report.records.filter { $0.tier == tier },
                threshold: report.config.peerDeltaFlagThreshold
            )
        }
    }

    private struct TierMetrics {
        let totalBattles: Int
        let winCount: Int
        let timeoutCount: Int
        let avgRounds: Double
        let avgPartyHPWin: Double
        let avgEnemyHPLoss: Double
        let overallRate: Double
        let trashRecords: [BalanceBattleRecord]
        let bossRecords: [BalanceBattleRecord]
    }

    private static func computeTierMetrics(_ records: [BalanceBattleRecord]) -> TierMetrics {
        let totalBattles = records.count
        var winCount = 0
        var timeoutCount = 0
        var totalRoundsSum = 0.0
        var partyHPWinSum = 0.0
        var enemyHPLossSum = 0.0
        var lossCount = 0
        var trashRecords: [BalanceBattleRecord] = []
        var bossRecords: [BalanceBattleRecord] = []

        for record in records {
            if record.isBoss {
                bossRecords.append(record)
            } else {
                trashRecords.append(record)
            }
            totalRoundsSum += Double(record.result.rounds)
            if record.result.timedOut {
                timeoutCount += 1
            }
            if record.result.isVictory {
                winCount += 1
                partyHPWinSum += record.result.partyHPRemainingFraction
            } else {
                lossCount += 1
                enemyHPLossSum += record.result.enemyHPRemainingFraction
            }
        }

        let overallRate = totalBattles == 0 ? 0.0 : Double(winCount) / Double(totalBattles)
        let avgRounds = totalBattles == 0 ? 0.0 : totalRoundsSum / Double(totalBattles)
        let avgPartyHPWin = winCount == 0 ? 0.0 : partyHPWinSum / Double(winCount)
        let avgEnemyHPLoss = lossCount == 0 ? 0.0 : enemyHPLossSum / Double(lossCount)

        return TierMetrics(
            totalBattles: totalBattles,
            winCount: winCount,
            timeoutCount: timeoutCount,
            avgRounds: avgRounds,
            avgPartyHPWin: avgPartyHPWin,
            avgEnemyHPLoss: avgEnemyHPLoss,
            overallRate: overallRate,
            trashRecords: trashRecords,
            bossRecords: bossRecords
        )
    }

    private static func summarizeTier(
        tier: SimulationPowerTier,
        records: [BalanceBattleRecord],
        threshold: Double
    ) -> BalanceTierStats {
        let metrics = computeTierMetrics(records)
        let overallRate = metrics.overallRate

        return BalanceTierStats(
            tier: tier,
            battles: metrics.totalBattles,
            wins: metrics.winCount,
            timeouts: metrics.timeoutCount,
            averageRounds: metrics.avgRounds,
            averagePartyHPOnWin: metrics.avgPartyHPWin,
            averageEnemyHPOnLoss: metrics.avgEnemyHPLoss,
            trashDuration: durationStats(
                metrics.trashRecords,
                minRounds: BalanceDurationThresholds.trashMinRounds,
                maxRounds: BalanceDurationThresholds.trashMaxRounds
            ),
            bossDuration: durationStats(
                metrics.bossRecords,
                minRounds: BalanceDurationThresholds.bossMinRounds,
                maxRounds: BalanceDurationThresholds.bossMaxRounds
            ),
            heroes: margin(records: records, ids: { [$0.heroID] }, peerRate: overallRate, threshold: threshold),
            companions: margin(
                records: records, ids: { [$0.companionID] }, peerRate: overallRate, threshold: threshold
            ),
            enemies: enemyMargins(records: records),
            abilities: margin(
                records: records,
                ids: { $0.heroAbilityIDs + $0.companionAbilityIDs },
                peerRate: overallRate,
                threshold: threshold
            ),
            enemyAbilities: opponentMargins(records: records, ids: \.enemyAbilityIDs, peerRate: overallRate, threshold: threshold),
            enemyTraits: opponentMargins(
                records: records, ids: { [$0.enemyTraitID] }, peerRate: overallRate, threshold: threshold
            ),
            affixes: margin(records: records, ids: \.affixIDs, peerRate: overallRate, threshold: threshold)
        )
    }

    private static func opponentMargins(
        records: [BalanceBattleRecord],
        ids: (BalanceBattleRecord) -> [String],
        peerRate: Double,
        threshold: Double
    ) -> [WinRateSummary] {
        margin(
            records: records,
            ids: ids,
            peerRate: peerRate,
            threshold: threshold,
            positiveFlag: "EASY",
            negativeFlag: "HARD"
        )
    }

    private static func durationStats(
        _ records: [BalanceBattleRecord],
        minRounds: Int,
        maxRounds: Int
    ) -> BalanceDurationBucketStats {
        guard !records.isEmpty else {
            return BalanceDurationBucketStats(
                battles: 0,
                shortBattles: 0,
                longBattles: 0,
                averageRounds: 0,
                averageRoundsWhenShort: 0,
                averageRoundsWhenLong: 0,
                maxRounds: 0,
                worstEnemyID: nil
            )
        }
        var shortBattles = 0
        var longBattles = 0
        var totalRounds = 0.0
        var shortRoundsSum = 0.0
        var longRoundsSum = 0.0
        var maxRoundsValue = 0
        var worstEnemyID: String?

        for record in records {
            let rounds = record.result.rounds
            totalRounds += Double(rounds)
            if rounds > maxRoundsValue {
                maxRoundsValue = rounds
                worstEnemyID = record.enemyID
            }
            if rounds < minRounds {
                shortBattles += 1
                shortRoundsSum += Double(rounds)
            } else if rounds > maxRounds {
                longBattles += 1
                longRoundsSum += Double(rounds)
            }
        }

        let totalCount = Double(records.count)
        return BalanceDurationBucketStats(
            battles: records.count,
            shortBattles: shortBattles,
            longBattles: longBattles,
            averageRounds: totalCount > 0 ? totalRounds / totalCount : 0,
            averageRoundsWhenShort: shortBattles > 0 ? shortRoundsSum / Double(shortBattles) : 0,
            averageRoundsWhenLong: longBattles > 0 ? longRoundsSum / Double(longBattles) : 0,
            maxRounds: maxRoundsValue,
            worstEnemyID: worstEnemyID
        )
    }

    private static func margin(
        records: [BalanceBattleRecord],
        ids: (BalanceBattleRecord) -> [String],
        peerRate: Double,
        threshold: Double,
        positiveFlag: String = "HIGH",
        negativeFlag: String = "LOW"
    ) -> [WinRateSummary] {
        var buckets: [String: (wins: Int, battles: Int)] = [:]
        for record in records {
            for id in Set(ids(record)) {
                var bucket = buckets[id] ?? (0, 0)
                bucket.battles += 1
                if record.result.isVictory {
                    bucket.wins += 1
                }
                buckets[id] = bucket
            }
        }
        return buckets.sorted { $0.key < $1.key }.map { id, bucket in
            let rate = bucket.battles == 0 ? 0 : Double(bucket.wins) / Double(bucket.battles)
            let ci = wilson(wins: bucket.wins, battles: bucket.battles)
            let delta = rate - peerRate
            let flagged = abs(delta) >= threshold && (ci.low > peerRate || ci.high < peerRate)
            return WinRateSummary(
                id: id,
                wins: bucket.wins,
                battles: bucket.battles,
                winRate: rate,
                wilsonLow: ci.low,
                wilsonHigh: ci.high,
                deltaVsPeer: delta,
                flagged: flagged,
                flagReason: flagged ? (delta > 0 ? positiveFlag : negativeFlag) : nil
            )
        }
        .sorted { lhs, rhs in
            if lhs.flagged != rhs.flagged {
                return lhs.flagged && !rhs.flagged
            }
            return abs(lhs.deltaVsPeer) > abs(rhs.deltaVsPeer)
        }
    }

    private static func enemyMargins(
        records: [BalanceBattleRecord]
    ) -> [WinRateSummary] {
        var buckets: [String: (wins: Int, battles: Int, boss: Bool)] = [:]
        for record in records {
            var bucket = buckets[record.enemyID] ?? (0, 0, record.isBoss)
            bucket.battles += 1
            if record.result.isVictory {
                bucket.wins += 1
            }
            bucket.boss = record.isBoss
            buckets[record.enemyID] = bucket
        }

        return buckets.sorted { $0.key < $1.key }.map { id, bucket in
            let rate = bucket.battles == 0 ? 0 : Double(bucket.wins) / Double(bucket.battles)
            let ci = wilson(wins: bucket.wins, battles: bucket.battles)
            let band = targetBand(isBoss: bucket.boss, tier: records.first?.tier ?? .early)
            let inBand = rate >= band.lower && rate <= band.upper
            let flagged = !inBand && bucket.battles >= 10
            let reason: String? = if flagged {
                rate > band.upper ? "EASY" : "HARD"
            } else {
                nil
            }
            return WinRateSummary(
                id: id,
                wins: bucket.wins,
                battles: bucket.battles,
                winRate: rate,
                wilsonLow: ci.low,
                wilsonHigh: ci.high,
                deltaVsPeer: rate - ((band.lower + band.upper) / 2),
                flagged: flagged,
                flagReason: reason
            )
        }
        .sorted { lhs, rhs in
            if lhs.flagged != rhs.flagged {
                return lhs.flagged && !rhs.flagged
            }
            return lhs.id < rhs.id
        }
    }

    private static func targetBand(
        isBoss: Bool,
        tier: SimulationPowerTier
    ) -> (lower: Double, upper: Double) {
        if isBoss {
            return (0.70, 0.80)
        }
        switch tier {
        case .early: return (0.90, 0.99)
        case .middle: return (0.80, 0.90)
        case .lateGame: return (0.70, 0.80)
        }
    }

    private static func winRate(_ records: [BalanceBattleRecord]) -> Double {
        guard !records.isEmpty else { return 0 }
        return Double(records.filter(\.result.isVictory).count) / Double(records.count)
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Wilson score interval at ~95% confidence.
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
