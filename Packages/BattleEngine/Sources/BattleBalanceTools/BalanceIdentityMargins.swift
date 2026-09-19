import BattleEngine
import Foundation

struct WinRateSpec {
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

enum BalanceIdentityMargins {
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

    static func flaggedPairCells(
        records: [BalanceBattleRecord],
        left: KeyPath<BalanceBattleRecord, String>,
        right: KeyPath<BalanceBattleRecord, String>,
        peerRate: Double,
        threshold: Double,
    ) -> [PairCellSummary] {
        var buckets: [String: (left: String, right: String, wins: Int, battles: Int)] = [:]
        for record in records {
            let lhs = record[keyPath: left]
            let rhs = record[keyPath: right]
            let key = "\(lhs)|\(rhs)"
            var bucket = buckets[key] ?? (lhs, rhs, 0, 0)
            bucket.battles += 1
            if record.result.isVictory {
                bucket.wins += 1
            }
            buckets[key] = bucket
        }
        return buckets.values.compactMap { bucket in
            guard bucket.battles >= BalanceSweepConfig.identityFlagMinBattles else { return nil }
            let rate = Double(bucket.wins) / Double(bucket.battles)
            let delta = rate - peerRate
            let ci = BalanceStatsAggregator.wilson(wins: bucket.wins, battles: bucket.battles)
            let flagged = abs(delta) >= threshold && (ci.low > peerRate || ci.high < peerRate)
            guard flagged else { return nil }
            return PairCellSummary(
                leftID: bucket.left,
                rightID: bucket.right,
                wins: bucket.wins,
                battles: bucket.battles,
                winRate: rate,
                deltaVsPeer: delta,
                flagged: true,
                flagReason: delta > 0 ? "HIGH" : "LOW",
            )
        }
        .sorted { abs($0.deltaVsPeer) > abs($1.deltaVsPeer) }
    }

    private struct Tally {
        var wins = 0
        var battles = 0

        var rate: Double {
            battles == 0 ? 0 : Double(wins) / Double(battles)
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
                bucket.battles += 1
                if record.result.isVictory {
                    bucket.wins += 1
                }
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

    static func makeWinRate(_ spec: WinRateSpec) -> WinRateSummary {
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
