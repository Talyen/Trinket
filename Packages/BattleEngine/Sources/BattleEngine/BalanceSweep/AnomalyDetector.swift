import Foundation

public enum AnomalyDetector {
    public struct Thresholds: Equatable, Sendable {
        public let targetWinRateMin: Double
        public let targetWinRateMax: Double
        public let hardCounterWinRate: Double
        public let timeoutRate: Double
        public let underpoweredAbilityWinRate: Double
        public let overpoweredAbilityWinRate: Double
        public let bossLateGameWinRateMin: Double
        public let bossLateGameWinRateMax: Double

        public init(
            targetWinRateMin: Double = 0.90,
            targetWinRateMax: Double = 0.99,
            hardCounterWinRate: Double = 0.25,
            timeoutRate: Double = 0.10,
            underpoweredAbilityWinRate: Double = 0.45,
            overpoweredAbilityWinRate: Double = 0.55,
            bossLateGameWinRateMin: Double = 0.85,
            bossLateGameWinRateMax: Double = 0.99
        ) {
            self.targetWinRateMin = targetWinRateMin
            self.targetWinRateMax = targetWinRateMax
            self.hardCounterWinRate = hardCounterWinRate
            self.timeoutRate = timeoutRate
            self.underpoweredAbilityWinRate = underpoweredAbilityWinRate
            self.overpoweredAbilityWinRate = overpoweredAbilityWinRate
            self.bossLateGameWinRateMin = bossLateGameWinRateMin
            self.bossLateGameWinRateMax = bossLateGameWinRateMax
        }

        public static let `default` = Thresholds()
    }

    public static func detect(
        matchupRows: [MatchupSweepRow],
        abilityRows: [AbilityComparisonRow],
        thresholds: Thresholds = .default
    ) -> [BalanceAnomaly] {
        var anomalies: [BalanceAnomaly] = []

        for row in matchupRows {
            if row.tickLimitRate >= thresholds.timeoutRate {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .timeout,
                        severity: .critical,
                        detail: "\(row.tier.displayName): \(row.heroID)+\(row.petID) vs \(row.enemyID) timed out \(percent(row.tickLimitRate)) of runs",
                        value: row.tickLimitRate
                    )
                )
            }

            if row.winRate < thresholds.hardCounterWinRate,
               row.tickLimitRate < thresholds.timeoutRate {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .hardCounter,
                        severity: .critical,
                        detail: "\(row.tier.displayName): \(row.heroID)+\(row.petID) vs \(row.enemyID) win rate \(percent(row.winRate))",
                        value: row.winRate
                    )
                )
            } else if row.winRate < thresholds.targetWinRateMin {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .belowTarget,
                        severity: .warning,
                        detail: "\(row.tier.displayName): \(row.heroID)+\(row.petID) vs \(row.enemyID) win rate \(percent(row.winRate))",
                        value: row.winRate
                    )
                )
            } else if row.winRate > thresholds.targetWinRateMax {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .aboveTarget,
                        severity: .warning,
                        detail: "\(row.tier.displayName): \(row.heroID)+\(row.petID) vs \(row.enemyID) win rate \(percent(row.winRate))",
                        value: row.winRate
                    )
                )
            }

            if row.isBoss, row.tier == .lateGame {
                if row.winRate < thresholds.bossLateGameWinRateMin {
                    anomalies.append(
                        BalanceAnomaly(
                            kind: .bossTuning,
                            severity: .critical,
                            detail: "Late boss \(row.enemyID) vs \(row.heroID)+\(row.petID) win rate \(percent(row.winRate)) (under-tuned)",
                            value: row.winRate
                        )
                    )
                } else if row.winRate > thresholds.bossLateGameWinRateMax {
                    anomalies.append(
                        BalanceAnomaly(
                            kind: .bossTuning,
                            severity: .warning,
                            detail: "Late boss \(row.enemyID) vs \(row.heroID)+\(row.petID) win rate \(percent(row.winRate)) (over-tuned)",
                            value: row.winRate
                        )
                    )
                }
            }
        }

        for row in abilityRows {
            if row.sampleCount == 0 { continue }

            if row.winRate < thresholds.underpoweredAbilityWinRate {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .underpoweredAbility,
                        severity: .critical,
                        detail: "\(row.tier.displayName) \(row.combatantName) \(row.abilityTier.rawValue) \(row.abilityName) vs \(row.siblingAbilityName): \(percent(row.winRate))",
                        value: row.winRate
                    )
                )
            } else if row.winRate > thresholds.overpoweredAbilityWinRate {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .overpoweredAbility,
                        severity: .warning,
                        detail: "\(row.tier.displayName) \(row.combatantName) \(row.abilityTier.rawValue) \(row.abilityName) vs \(row.siblingAbilityName): \(percent(row.winRate))",
                        value: row.winRate
                    )
                )
            }
        }

        return anomalies.sorted {
            if $0.severity != $1.severity {
                return $0.severity == .critical
            }
            return $0.detail < $1.detail
        }
    }

    private static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }
}
