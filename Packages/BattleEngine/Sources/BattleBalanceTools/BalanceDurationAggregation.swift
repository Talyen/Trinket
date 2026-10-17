import BattleEngine
import TrinketContent

enum BalanceDurationAggregation {
    static func durationStats(
        _ records: [BalanceBattleRecord],
        minRounds: Int,
        maxRounds: Int,
        flagRate: Double,
    ) -> BalanceDurationBucketStats {
        var total = DurationTally()
        var enemies: [String: DurationTally] = [:]
        for record in records {
            total.record(record, minRounds: minRounds, maxRounds: maxRounds)
            enemies[record.enemyID, default: DurationTally()].record(record, minRounds: minRounds, maxRounds: maxRounds)
        }
        let worstEnemy = enemies.lazy
            .filter { $0.value.battles >= BalanceSweepConfig.identityFlagMinBattles && $0.value.longBattles > 0 }
            .min {
                if $0.value.longRate != $1.value.longRate {
                    return $0.value.longRate > $1.value.longRate
                }
                return $0.key < $1.key
            }?.key
        let reason = total.flagReason(rate: flagRate, short: "SHORT", long: "LONG")
        return BalanceDurationBucketStats(
            battles: total.battles,
            shortBattles: total.shortBattles,
            longBattles: total.longBattles,
            averageRounds: total.averageRounds,
            averageRoundsWhenShort: total.averageRoundsWhenShort,
            averageRoundsWhenLong: total.averageRoundsWhenLong,
            maxRounds: total.maxRounds,
            worstEnemyID: worstEnemy,
            flagged: reason != nil,
            flagReason: reason,
        )
    }

    private struct EnemyKey: Hashable {
        let id: String
        let isBoss: Bool
    }

    static func enemyDurationTable(
        _ records: [BalanceBattleRecord],
        flagRate: Double,
    ) -> [BalanceEnemyDurationStats] {
        var groups: [EnemyKey: DurationTally] = [:]
        for record in records {
            groups[EnemyKey(id: record.enemyID, isBoss: record.isBoss), default: DurationTally()].record(record)
        }
        return groups.sorted {
            if $0.key.id != $1.key.id {
                return $0.key.id < $1.key.id
            }
            return !$0.key.isBoss && $1.key.isBoss
        }.map { key, total in
            let reason = total.flagReason(rate: flagRate)
            return BalanceEnemyDurationStats(
                enemyID: key.id,
                isBoss: key.isBoss,
                battles: total.battles,
                averageRounds: total.averageRounds,
                shortRate: total.shortRate,
                longRate: total.longRate,
                flagged: reason != nil,
                flagReason: reason,
            )
        }
    }

    static func combatantDurationTable(
        _ records: [BalanceBattleRecord],
        role: Combatant.Role,
        idPath: KeyPath<BalanceBattleRecord, String>,
        flagRate: Double,
    ) -> [BalanceCombatantDurationStats] {
        var groups: [String: DurationTally] = [:]
        for record in records {
            groups[record[keyPath: idPath], default: DurationTally()].record(record)
        }
        return groups.sorted { $0.key < $1.key }.map { id, total in
            let reason = total.flagReason(rate: flagRate)
            return BalanceCombatantDurationStats(
                combatantID: id,
                role: role,
                battles: total.battles,
                averageRounds: total.averageRounds,
                shortRate: total.shortRate,
                longRate: total.longRate,
                flagged: reason != nil,
                flagReason: reason,
            )
        }
    }

    /// All duration views use the same classification. A cap contributes observed
    /// rounds and may be long, but never short; mixed opponents use their own bands.
    private struct DurationTally {
        var battles = 0
        var shortBattles = 0
        var longBattles = 0
        var maxRounds = 0
        var totalRounds = 0.0
        var shortRounds = 0.0
        var longRounds = 0.0

        mutating func record(_ record: BalanceBattleRecord, minRounds: Int? = nil, maxRounds: Int? = nil) {
            let floor = minRounds ??
                (record.isBoss ? BalanceDurationThresholds.bossMinRounds : BalanceDurationThresholds.trashMinRounds)
            let ceiling = maxRounds ??
                (record.isBoss ? BalanceDurationThresholds.bossMaxRounds : BalanceDurationThresholds.trashMaxRounds)
            let rounds = record.result.rounds
            battles += 1
            totalRounds += Double(rounds)
            self.maxRounds = max(self.maxRounds, rounds)
            if record.result.isDecided, rounds < floor {
                shortBattles += 1
                shortRounds += Double(rounds)
            } else if rounds > ceiling {
                longBattles += 1
                longRounds += Double(rounds)
            }
        }

        var averageRounds: Double {
            average(totalRounds, count: battles)
        }

        var averageRoundsWhenShort: Double {
            average(shortRounds, count: shortBattles)
        }

        var averageRoundsWhenLong: Double {
            average(longRounds, count: longBattles)
        }

        var shortRate: Double {
            average(Double(shortBattles), count: battles)
        }

        var longRate: Double {
            average(Double(longBattles), count: battles)
        }

        func flagReason(rate: Double, short: String = "FAST", long: String = "SLOW") -> String? {
            guard battles >= BalanceSweepConfig.identityFlagMinBattles else { return nil }
            var flags: [String] = []
            if shortRate >= rate {
                flags.append(short)
            }
            if longRate >= rate {
                flags.append(long)
            }
            return flags.isEmpty ? nil : flags.joined(separator: " ")
        }

        private func average(_ sum: Double, count: Int) -> Double {
            count == 0 ? 0 : sum / Double(count)
        }
    }
}
