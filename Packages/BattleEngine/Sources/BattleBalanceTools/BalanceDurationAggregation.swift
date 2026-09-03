import BattleEngine
import Foundation
import TrinketContent

enum BalanceDurationAggregation {
    static func durationStats(
        _ records: [BalanceBattleRecord],
        minRounds: Int,
        maxRounds: Int,
        flagRate: Double,
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
                worstEnemyID: nil,
                flagged: false,
                flagReason: nil,
            )
        }
        var acc = DurationAcc()
        acc.accumulate(records, minRounds: minRounds, maxRounds: maxRounds)
        let totalCount = Double(records.count)
        let shortRate = Double(acc.shortBattles) / totalCount
        let longRate = Double(acc.longBattles) / totalCount
        let worstEnemyID = acc.longByEnemy
            .filter { $0.value.battles >= BalanceSweepConfig.identityFlagMinBattles }
            .max(by: {
                Double($0.value.long) / Double($0.value.battles)
                    < Double($1.value.long) / Double($1.value.battles)
            })?
            .key
        var flags: [String] = []
        if shortRate >= flagRate {
            flags.append("SHORT")
        }
        if longRate >= flagRate {
            flags.append("LONG")
        }
        return BalanceDurationBucketStats(
            battles: records.count,
            shortBattles: acc.shortBattles,
            longBattles: acc.longBattles,
            averageRounds: acc.totalRounds / totalCount,
            averageRoundsWhenShort: acc.shortBattles > 0
                ? acc.shortRoundsSum / Double(acc.shortBattles)
                : 0,
            averageRoundsWhenLong: acc.longBattles > 0
                ? acc.longRoundsSum / Double(acc.longBattles)
                : 0,
            maxRounds: acc.maxRoundsValue,
            worstEnemyID: worstEnemyID,
            flagged: !flags.isEmpty,
            flagReason: flags.isEmpty ? nil : flags.joined(separator: " "),
        )
    }

    private struct DurationAcc {
        var shortBattles = 0
        var longBattles = 0
        var totalRounds = 0.0
        var shortRoundsSum = 0.0
        var longRoundsSum = 0.0
        var maxRoundsValue = 0
        var longByEnemy: [String: (long: Int, battles: Int)] = [:]

        mutating func accumulate(
            _ records: [BalanceBattleRecord],
            minRounds: Int,
            maxRounds: Int,
        ) {
            for record in records {
                let rounds = record.result.rounds
                totalRounds += Double(rounds)
                var enemyBucket = longByEnemy[record.enemyID] ?? (0, 0)
                enemyBucket.battles += 1
                if rounds > maxRoundsValue {
                    maxRoundsValue = rounds
                }
                if rounds < minRounds {
                    shortBattles += 1
                    shortRoundsSum += Double(rounds)
                } else if rounds > maxRounds {
                    longBattles += 1
                    longRoundsSum += Double(rounds)
                    enemyBucket.long += 1
                }
                longByEnemy[record.enemyID] = enemyBucket
            }
        }
    }

    static func enemyDurationTable(
        _ records: [BalanceBattleRecord],
        flagRate: Double,
    ) -> [BalanceEnemyDurationStats] {
        let grouped = Dictionary(grouping: records, by: \.enemyID)
        return grouped.keys.sorted().compactMap { enemyID -> BalanceEnemyDurationStats? in
            let recs = grouped[enemyID] ?? []
            guard !recs.isEmpty else { return nil }
            let isBoss = recs[0].isBoss
            let minRounds = isBoss
                ? BalanceDurationThresholds.bossMinRounds
                : BalanceDurationThresholds.trashMinRounds
            let maxRounds = isBoss
                ? BalanceDurationThresholds.bossMaxRounds
                : BalanceDurationThresholds.trashMaxRounds
            let short = recs.count { $0.result.rounds < minRounds }
            let long = recs.count { $0.result.rounds > maxRounds }
            let avg = recs.reduce(0.0) { $0 + Double($1.result.rounds) } / Double(recs.count)
            let shortRate = Double(short) / Double(recs.count)
            let longRate = Double(long) / Double(recs.count)
            let sampleTooLow = recs.count < BalanceSweepConfig.identityFlagMinBattles
            var flags: [String] = []
            if !sampleTooLow {
                if shortRate >= flagRate {
                    flags.append("FAST")
                }
                if longRate >= flagRate {
                    flags.append("SLOW")
                }
            }
            return BalanceEnemyDurationStats(
                enemyID: enemyID,
                isBoss: isBoss,
                battles: recs.count,
                averageRounds: avg,
                shortRate: shortRate,
                longRate: longRate,
                flagged: !flags.isEmpty,
                flagReason: flags.isEmpty ? nil : flags.joined(separator: " "),
            )
        }
    }

    static func combatantDurationTable(
        _ records: [BalanceBattleRecord],
        role: Combatant.Role,
        idPath: KeyPath<BalanceBattleRecord, String>,
        flagRate: Double,
    ) -> [BalanceCombatantDurationStats] {
        let grouped = Dictionary(grouping: records, by: { $0[keyPath: idPath] })
        return grouped.keys.sorted().compactMap { combatantID -> BalanceCombatantDurationStats? in
            let recs = grouped[combatantID] ?? []
            guard !recs.isEmpty else { return nil }
            let short = recs.count { rec in
                let minR = rec.isBoss
                    ? BalanceDurationThresholds.bossMinRounds
                    : BalanceDurationThresholds.trashMinRounds
                return rec.result.rounds < minR
            }
            let long = recs.count { rec in
                let maxR = rec.isBoss
                    ? BalanceDurationThresholds.bossMaxRounds
                    : BalanceDurationThresholds.trashMaxRounds
                return rec.result.rounds > maxR
            }
            let avg = recs.reduce(0.0) { $0 + Double($1.result.rounds) } / Double(recs.count)
            let shortRate = Double(short) / Double(recs.count)
            let longRate = Double(long) / Double(recs.count)
            let sampleTooLow = recs.count < BalanceSweepConfig.identityFlagMinBattles
            var flags: [String] = []
            if !sampleTooLow {
                if shortRate >= flagRate {
                    flags.append("FAST")
                }
                if longRate >= flagRate {
                    flags.append("SLOW")
                }
            }
            return BalanceCombatantDurationStats(
                combatantID: combatantID,
                role: role,
                battles: recs.count,
                averageRounds: avg,
                shortRate: shortRate,
                longRate: longRate,
                flagged: !flags.isEmpty,
                flagReason: flags.isEmpty ? nil : flags.joined(separator: " "),
            )
        }
    }
}
