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
        var buckets: [String: (wins: Int, battles: Int)] = [:]
        for record in records {
            let key = record[keyPath: id]
            var bucket = buckets[key] ?? (0, 0)
            bucket.battles += 1
            if record.result.isVictory {
                bucket.wins += 1
            }
            buckets[key] = bucket
        }
        return buckets.sorted { $0.key < $1.key }.map { id, bucket in
            let targetDelta = targetBand.map { band in
                let rate = bucket.battles == 0 ? 0 : Double(bucket.wins) / Double(bucket.battles)
                return rate - ((band.lower + band.upper) / 2)
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
        .sorted { lhs, rhs in
            if lhs.flagged != rhs.flagged {
                return lhs.flagged && !rhs.flagged
            }
            return abs(lhs.deltaVsPeer) > abs(rhs.deltaVsPeer)
        }
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
        .sorted { lhs, rhs in
            if lhs.flagged != rhs.flagged {
                return lhs.flagged && !rhs.flagged
            }
            return abs(lhs.deltaVsPeer) > abs(rhs.deltaVsPeer)
        }
    }

    static func withinOwnerMargins(
        records: [BalanceBattleRecord],
        ownerAndIDs: (BalanceBattleRecord) -> [(String, String)],
        ownerRates: [String: Double],
        threshold: Double,
    ) -> [WinRateSummary] {
        var buckets: [String: (owner: String, id: String, wins: Int, battles: Int)] = [:]
        for record in records {
            var seen: Set<String> = []
            for pair in ownerAndIDs(record) {
                let key = "\(pair.0)|\(pair.1)"
                guard seen.insert(key).inserted else { continue }
                var bucket = buckets[key] ?? (pair.0, pair.1, 0, 0)
                bucket.battles += 1
                if record.result.isVictory {
                    bucket.wins += 1
                }
                buckets[key] = bucket
            }
        }
        return buckets.values.map { bucket in
            makeWinRate(
                WinRateSpec(
                    id: bucket.id,
                    ownerID: bucket.owner,
                    wins: bucket.wins,
                    battles: bucket.battles,
                    peerRate: ownerRates[bucket.owner] ?? 0,
                    threshold: threshold,
                    positiveFlag: "HIGH",
                    negativeFlag: "LOW",
                ),
            )
        }
        .sorted { lhs, rhs in
            if lhs.flagged != rhs.flagged {
                return lhs.flagged && !rhs.flagged
            }
            return abs(lhs.deltaVsPeer) > abs(rhs.deltaVsPeer)
        }
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
