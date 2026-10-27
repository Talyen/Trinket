import BattleEngine
import TrinketContent

enum BalanceDurationAggregation {
    private struct EnemyKey: Hashable {
        let id: String
        let isBoss: Bool
    }

    struct Summary {
        var trash: BalanceDurationBucketStats
        var boss: BalanceDurationBucketStats
        var enemies: [BalanceEnemyDurationStats]
        var heroes: [BalanceCombatantDurationStats]
        var companions: [BalanceCombatantDurationStats]
    }

    static func summarize(_ records: [BalanceBattleRecord], flagRate: Double) -> Summary {
        var trash = DurationTally()
        var boss = DurationTally()
        var enemies: [EnemyKey: DurationTally] = [:]
        var heroes: [String: DurationTally] = [:]
        var companions: [String: DurationTally] = [:]
        for record in records {
            let sample = DurationSample(record)
            if record.isBoss {
                boss.record(sample)
            } else {
                trash.record(sample)
            }
            enemies[EnemyKey(id: record.enemyID, isBoss: record.isBoss), default: DurationTally()].record(sample)
            heroes[record.heroID, default: DurationTally()].record(sample)
            companions[record.companionID, default: DurationTally()].record(sample)
        }

        return Summary(
            trash: bucket(trash, enemies: enemies, isBoss: false, flagRate: flagRate),
            boss: bucket(boss, enemies: enemies, isBoss: true, flagRate: flagRate),
            enemies: enemyRows(enemies, flagRate: flagRate),
            heroes: combatantRows(heroes, role: .hero, flagRate: flagRate),
            companions: combatantRows(companions, role: .companion, flagRate: flagRate),
        )
    }

    private static func bucket(
        _ total: DurationTally, enemies: [EnemyKey: DurationTally], isBoss: Bool, flagRate: Double,
    ) -> BalanceDurationBucketStats {
        let worstEnemy = enemies.lazy
            .filter { $0.key.isBoss == isBoss && $0.value.battles >= BalanceSweepConfig.identityFlagMinBattles && $0.value.longBattles > 0 }
            .min {
                if $0.value.longRate != $1.value.longRate {
                    return $0.value.longRate > $1.value.longRate
                }
                return $0.key.id < $1.key.id
            }?.key.id
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

    private static func enemyRows(_ groups: [EnemyKey: DurationTally], flagRate: Double) -> [BalanceEnemyDurationStats] {
        groups.sorted {
            if $0.key.id != $1.key.id {
                return $0.key.id < $1.key.id
            }
            return !$0.key.isBoss && $1.key.isBoss
        }.map { key, total in
            let reason = total.flagReason(rate: flagRate)
            return BalanceEnemyDurationStats(
                enemyID: key.id, isBoss: key.isBoss, battles: total.battles,
                averageRounds: total.averageRounds, shortRate: total.shortRate, longRate: total.longRate,
                flagged: reason != nil, flagReason: reason,
            )
        }
    }

    private static func combatantRows(
        _ groups: [String: DurationTally], role: Combatant.Role, flagRate: Double,
    ) -> [BalanceCombatantDurationStats] {
        groups.sorted { $0.key < $1.key }.map { id, total in
            let reason = total.flagReason(rate: flagRate)
            return BalanceCombatantDurationStats(
                combatantID: id, role: role, battles: total.battles,
                averageRounds: total.averageRounds, shortRate: total.shortRate, longRate: total.longRate,
                flagged: reason != nil, flagReason: reason,
            )
        }
    }

    /// A cap contributes observed rounds and may be long, but never short.
    private struct DurationSample {
        let rounds: Int
        let isShort: Bool
        let isLong: Bool

        init(_ record: BalanceBattleRecord) {
            let rounds = record.result.rounds
            self.rounds = rounds
            let floor = record.isBoss ? BalanceDurationThresholds.bossMinRounds : BalanceDurationThresholds.trashMinRounds
            let ceiling = record.isBoss ? BalanceDurationThresholds.bossMaxRounds : BalanceDurationThresholds.trashMaxRounds
            isShort = record.result.isDecided && rounds < floor
            isLong = !isShort && rounds > ceiling
        }
    }

    private struct DurationTally {
        var battles = 0
        var shortBattles = 0
        var longBattles = 0
        var maxRounds = 0
        var totalRounds = 0.0
        var shortRounds = 0.0
        var longRounds = 0.0

        mutating func record(_ sample: DurationSample) {
            let rounds = sample.rounds
            battles += 1
            totalRounds += Double(rounds)
            maxRounds = max(maxRounds, rounds)
            if sample.isShort {
                shortBattles += 1
                shortRounds += Double(rounds)
            } else if sample.isLong {
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
