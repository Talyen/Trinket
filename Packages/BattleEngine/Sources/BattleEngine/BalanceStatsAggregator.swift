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

public struct BalanceTierStats: Sendable {
    public var tier: SimulationPowerTier
    public var battles: Int
    public var wins: Int
    public var timeouts: Int
    public var averageRounds: Double
    public var averagePartyHPOnWin: Double
    public var averageEnemyHPOnLoss: Double
    public var heroes: [WinRateSummary]
    public var companions: [WinRateSummary]
    public var enemies: [WinRateSummary]
    public var abilities: [WinRateSummary]
    public var affixes: [WinRateSummary]
}

public enum BalanceStatsAggregator {
    public static func summarize(
        report: BalanceSweepReport
    ) -> [BalanceTierStats] {
        report.config.tiers.map { tier in
            let records = report.records.filter { $0.tier == tier }
            let overallRate = winRate(records)
            let threshold = report.config.peerDeltaFlagThreshold
            let wins = records.filter(\.result.isVictory)

            return BalanceTierStats(
                tier: tier,
                battles: records.count,
                wins: wins.count,
                timeouts: records.filter(\.result.timedOut).count,
                averageRounds: average(records.map { Double($0.result.rounds) }),
                averagePartyHPOnWin: average(wins.map(\.result.partyHPRemainingFraction)),
                averageEnemyHPOnLoss: average(
                    records.filter { !$0.result.isVictory }.map(\.result.enemyHPRemainingFraction)
                ),
                heroes: margin(
                    records: records,
                    ids: { [$0.heroID] },
                    peerRate: overallRate,
                    threshold: threshold
                ),
                companions: margin(
                    records: records,
                    ids: { [$0.companionID] },
                    peerRate: overallRate,
                    threshold: threshold
                ),
                enemies: enemyMargins(records: records),
                abilities: margin(
                    records: records,
                    ids: { $0.heroAbilityIDs + $0.companionAbilityIDs },
                    peerRate: overallRate,
                    threshold: threshold
                ),
                affixes: margin(
                    records: records,
                    ids: \.affixIDs,
                    peerRate: overallRate,
                    threshold: threshold
                )
            )
        }
    }

    private static func margin(
        records: [BalanceBattleRecord],
        ids: (BalanceBattleRecord) -> [String],
        peerRate: Double,
        threshold: Double
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
                flagReason: flagged ? (delta > 0 ? "HIGH" : "LOW") : nil
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
