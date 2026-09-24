import BattleEngine
import Foundation

enum BalanceIdentityMargins {
    private struct WinRateSpec {
        var id: String
        var ownerID: String?
        var wins: Int
        var battles: Int
        var peerRate: Double
        var threshold: Double
        var positiveFlag: String
        var negativeFlag: String
        var targetBandDelta: Double?
    }

    static func ownerMargins(
        records: [BalanceBattleRecord],
        id: KeyPath<BalanceBattleRecord, String>,
        peerRate: Double,
        threshold: Double,
        targetBand: (lower: Double, upper: Double)? = nil,
    ) -> [WinRateSummary] {
        tally(records) { [$0[keyPath: id]] }
            .sorted { $0.key < $1.key }
            .map { id, bucket in
                let targetDelta = targetBand.map { band in
                    bucket.rate - ((band.lower + band.upper) / 2)
                }
                return makeWinRate(
                    WinRateSpec(
                        id: id,
                        ownerID: nil,
                        wins: bucket.wins,
                        battles: bucket.battles,
                        peerRate: peerRate,
                        threshold: threshold,
                        positiveFlag: "HIGH",
                        negativeFlag: "LOW",
                        targetBandDelta: targetDelta,
                    ),
                )
            }
            .sorted(by: flaggedFirst)
    }

    static func margin(
        records: [BalanceBattleRecord],
        ids: (BalanceBattleRecord) -> [String],
        peerRate: Double,
        threshold: Double,
        positiveFlag: String = "HIGH",
        negativeFlag: String = "LOW",
        ownerID: String? = nil,
    ) -> [WinRateSummary] {
        tally(records) { ids($0) }
            .sorted { $0.key < $1.key }
            .map { id, bucket in
                makeWinRate(
                    WinRateSpec(
                        id: id,
                        ownerID: ownerID,
                        wins: bucket.wins,
                        battles: bucket.battles,
                        peerRate: peerRate,
                        threshold: threshold,
                        positiveFlag: positiveFlag,
                        negativeFlag: negativeFlag,
                    ),
                )
            }
            .sorted(by: flaggedFirst)
    }

    static func withinOwnerMargins(
        records: [BalanceBattleRecord],
        ownerAndIDs: (BalanceBattleRecord) -> [(String, String)],
        ownerRates: [String: Double],
        threshold: Double,
    ) -> [WinRateSummary] {
        tally(records) { ownerAndIDs($0).map { OwnerID(owner: $0.0, id: $0.1) } }
            .sorted { ($0.key.id, $0.key.owner) < ($1.key.id, $1.key.owner) }
            .map { key, bucket in
                makeWinRate(
                    WinRateSpec(
                        id: key.id,
                        ownerID: key.owner,
                        wins: bucket.wins,
                        battles: bucket.battles,
                        peerRate: ownerRates[key.owner] ?? 0,
                        threshold: threshold,
                        positiveFlag: "HIGH",
                        negativeFlag: "LOW",
                    ),
                )
            }
            .sorted(by: flaggedFirst)
    }

    private struct OwnerID: Hashable {
        var owner: String
        var id: String
    }

    private struct EnemyID: Hashable {
        var id: String
        var isBoss: Bool
    }

    /// Enemy rows use the boss/trash target band instead of the tier's peer rate.
    static func enemyMargins(
        records: [BalanceBattleRecord],
        targetBand: (Bool) -> (lower: Double, upper: Double),
    ) -> [WinRateSummary] {
        tally(records) { [EnemyID(id: $0.enemyID, isBoss: $0.isBoss)] }
            .map { enemy, bucket in
                let band = targetBand(enemy.isBoss)
                let ci = BalanceStatsAggregator.wilson(wins: bucket.wins, battles: bucket.battles)
                let sampleTooLow = bucket.battles < BalanceSweepConfig.identityFlagMinBattles
                let isHard = ci.high < band.lower
                let isEasy = ci.low > band.upper
                let flagged = (isHard || isEasy) && !sampleTooLow
                let summary = WinRateSummary(
                    id: enemy.id,
                    ownerID: nil,
                    wins: bucket.wins,
                    battles: bucket.battles,
                    winRate: bucket.rate,
                    wilsonLow: ci.low,
                    wilsonHigh: ci.high,
                    deltaVsPeer: bucket.rate - ((band.lower + band.upper) / 2),
                    flagged: flagged,
                    flagReason: flagged ? (isEasy ? "EASY" : "HARD") : nil,
                    sampleTooLow: sampleTooLow,
                )
                return (enemy, summary)
            }
            .sorted { lhs, rhs in
                if lhs.1.flagged != rhs.1.flagged {
                    return lhs.1.flagged && !rhs.1.flagged
                }
                if lhs.0.id != rhs.0.id {
                    return lhs.0.id < rhs.0.id
                }
                return !lhs.0.isBoss && rhs.0.isBoss
            }
            .map(\.1)
    }

    private struct PairID: Hashable {
        var left: String
        var right: String
    }

    static func flaggedPairCells(
        records: [BalanceBattleRecord],
        left: KeyPath<BalanceBattleRecord, String>,
        right: KeyPath<BalanceBattleRecord, String>,
        peerRate: Double,
        threshold: Double,
    ) -> [PairCellSummary] {
        let buckets = tally(records) { [PairID(left: $0[keyPath: left], right: $0[keyPath: right])] }
        return buckets.compactMap { pair, bucket in
            guard bucket.battles >= BalanceSweepConfig.identityFlagMinBattles else { return nil }
            let rate = bucket.rate
            let delta = rate - peerRate
            let ci = BalanceStatsAggregator.wilson(wins: bucket.wins, battles: bucket.battles)
            let flagged = abs(delta) >= threshold && (ci.low > peerRate || ci.high < peerRate)
            guard flagged else { return nil }
            return PairCellSummary(
                leftID: pair.left,
                rightID: pair.right,
                wins: bucket.wins,
                battles: bucket.battles,
                winRate: rate,
                deltaVsPeer: delta,
                flagged: true,
                flagReason: delta > 0 ? "HIGH" : "LOW",
            )
        }
        .sorted { lhs, rhs in
            if abs(lhs.deltaVsPeer) != abs(rhs.deltaVsPeer) {
                return abs(lhs.deltaVsPeer) > abs(rhs.deltaVsPeer)
            }
            return (lhs.leftID, lhs.rightID) < (rhs.leftID, rhs.rightID)
        }
    }

    private struct Tally {
        var wins = 0
        var battles = 0

        var rate: Double {
            battles == 0 ? 0 : Double(wins) / Double(battles)
        }

        mutating func record(_ result: BattleSimResult) {
            battles += 1
            if result.isVictory {
                wins += 1
            }
        }
    }

    /// Counts wins/battles per unique key. Set dedupes repeated keys within one
    /// record (a build can carry the same affix in two slots).
    private static func tally<Key: Hashable>(
        _ records: [BalanceBattleRecord],
        keys: (BalanceBattleRecord) -> [Key],
    ) -> [Key: Tally] {
        var buckets: [Key: Tally] = [:]
        for record in records {
            for key in Set(keys(record)) {
                var bucket = buckets[key] ?? Tally()
                bucket.record(record.result)
                buckets[key] = bucket
            }
        }
        return buckets
    }

    /// Total order (id then owner): equal-delta rows previously depended on
    /// dictionary order, so report text could reorder between process runs.
    private static func flaggedFirst(_ lhs: WinRateSummary, _ rhs: WinRateSummary) -> Bool {
        if lhs.flagged != rhs.flagged {
            return lhs.flagged && !rhs.flagged
        }
        if abs(lhs.deltaVsPeer) != abs(rhs.deltaVsPeer) {
            return abs(lhs.deltaVsPeer) > abs(rhs.deltaVsPeer)
        }
        if lhs.id != rhs.id {
            return lhs.id < rhs.id
        }
        return (lhs.ownerID ?? "") < (rhs.ownerID ?? "")
    }

    private static func makeWinRate(_ spec: WinRateSpec) -> WinRateSummary {
        let rate = spec.battles == 0 ? 0 : Double(spec.wins) / Double(spec.battles)
        let ci = BalanceStatsAggregator.wilson(wins: spec.wins, battles: spec.battles)
        let delta = rate - spec.peerRate
        let sampleTooLow = spec.battles < BalanceSweepConfig.identityFlagMinBattles
        let flagged = !sampleTooLow && abs(delta) >= spec.threshold
            && (ci.low > spec.peerRate || ci.high < spec.peerRate)
        return WinRateSummary(
            id: spec.id,
            ownerID: spec.ownerID,
            wins: spec.wins,
            battles: spec.battles,
            winRate: rate,
            wilsonLow: ci.low,
            wilsonHigh: ci.high,
            deltaVsPeer: delta,
            targetBandDelta: spec.targetBandDelta,
            flagged: flagged,
            flagReason: flagged ? (delta > 0 ? spec.positiveFlag : spec.negativeFlag) : nil,
            sampleTooLow: sampleTooLow,
        )
    }
}
