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
        margins(buckets: tally(records) { [$0[keyPath: id]] }) { id, bucket in
            WinRateSpec(
                id: id,
                ownerID: nil,
                wins: bucket.wins,
                battles: bucket.battles,
                peerRate: peerRate,
                threshold: threshold,
                positiveFlag: "HIGH",
                negativeFlag: "LOW",
                targetBandDelta: targetBand.map { bucket.rate - (($0.lower + $0.upper) / 2) },
            )
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
        margins(buckets: tally(records, keys: ids)) { id, bucket in
            WinRateSpec(
                id: id,
                ownerID: ownerID,
                wins: bucket.wins,
                battles: bucket.battles,
                peerRate: peerRate,
                threshold: threshold,
                positiveFlag: positiveFlag,
                negativeFlag: negativeFlag,
            )
        }
    }

    static func withinOwnerMargins(
        records: [BalanceBattleRecord],
        ownerAndIDs: (BalanceBattleRecord) -> [(String, String)],
        ownerRates: [String: Double],
        threshold: Double,
    ) -> [WinRateSummary] {
        margins(
            buckets: tally(records) { ownerAndIDs($0).map { OwnerID(owner: $0.0, id: $0.1) } },
        ) { key, bucket in
            WinRateSpec(
                id: key.id,
                ownerID: key.owner,
                wins: bucket.wins,
                battles: bucket.battles,
                peerRate: ownerRates[key.owner] ?? 0,
                threshold: threshold,
                positiveFlag: "HIGH",
                negativeFlag: "LOW",
            )
        }
    }

    private static func margins<Key: Hashable>(buckets: [Key: Tally], spec: (Key, Tally) -> WinRateSpec) -> [WinRateSummary] {
        buckets.map { makeWinRate(spec($0.key, $0.value)) }.sorted(by: flaggedFirst)
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
                let ci = bucket.interval
                let sampleTooLow = bucket.sampleTooLow
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
            guard let reason = bucket.flagReason(peerRate: peerRate, threshold: threshold) else { return nil }
            let delta = bucket.rate - peerRate
            return PairCellSummary(
                leftID: pair.left,
                rightID: pair.right,
                wins: bucket.wins,
                battles: bucket.battles,
                winRate: bucket.rate,
                deltaVsPeer: delta,
                flagged: true,
                flagReason: reason,
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

        var interval: (low: Double, high: Double) {
            BalanceStatsAggregator.wilson(wins: wins, battles: battles)
        }

        var sampleTooLow: Bool {
            battles < BalanceSweepConfig.identityFlagMinBattles
        }

        func flagReason(
            peerRate: Double,
            threshold: Double,
            positive: String = "HIGH",
            negative: String = "LOW",
        ) -> String? {
            let delta = rate - peerRate
            let ci = interval
            guard !sampleTooLow, abs(delta) >= threshold,
                  ci.low > peerRate || ci.high < peerRate else { return nil }
            return delta > 0 ? positive : negative
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
        let tally = Tally(wins: spec.wins, battles: spec.battles)
        let ci = tally.interval
        let reason = tally.flagReason(
            peerRate: spec.peerRate, threshold: spec.threshold,
            positive: spec.positiveFlag, negative: spec.negativeFlag,
        )
        return WinRateSummary(
            id: spec.id,
            ownerID: spec.ownerID,
            wins: spec.wins,
            battles: spec.battles,
            winRate: tally.rate,
            wilsonLow: ci.low,
            wilsonHigh: ci.high,
            deltaVsPeer: tally.rate - spec.peerRate,
            targetBandDelta: spec.targetBandDelta,
            flagged: reason != nil,
            flagReason: reason,
            sampleTooLow: tally.sampleTooLow,
        )
    }
}
