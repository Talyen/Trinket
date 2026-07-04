import Foundation

public enum AnomalyDetector {
    public struct Thresholds: Equatable, Sendable {
        public let hardCounterWinRate: Double
        public let timeoutRate: Double
        public let prolongedFightTicks: Int
        public let underpoweredAbilityWinRate: Double
        public let overpoweredAbilityWinRate: Double

        public init(
            hardCounterWinRate: Double = 0.25,
            timeoutRate: Double = 0.10,
            prolongedFightTicks: Int = 100,
            underpoweredAbilityWinRate: Double = 0.45,
            overpoweredAbilityWinRate: Double = 0.55
        ) {
            self.hardCounterWinRate = hardCounterWinRate
            self.timeoutRate = timeoutRate
            self.prolongedFightTicks = prolongedFightTicks
            self.underpoweredAbilityWinRate = underpoweredAbilityWinRate
            self.overpoweredAbilityWinRate = overpoweredAbilityWinRate
        }

        public static let `default` = Thresholds()
    }

    public struct WinRateBand: Equatable, Sendable {
        public let min: Double
        public let max: Double

        public init(min: Double, max: Double) {
            self.min = min
            self.max = max
        }
    }

    public static func targetBand(for row: MatchupSweepRow) -> WinRateBand {
        if row.isBoss || row.isElite {
            return WinRateBand(min: 0.70, max: 0.80)
        }

        switch row.tier {
        case .early:
            return WinRateBand(min: 0.90, max: 0.99)
        case .middle:
            return WinRateBand(min: 0.80, max: 0.90)
        case .lateGame:
            return WinRateBand(min: 0.70, max: 0.80)
        }
    }

    public static func detect(
        matchupRows: [MatchupSweepRow],
        abilityRows: [AbilityComparisonRow],
        thresholds: Thresholds = .default
    ) -> [BalanceAnomaly] {
        var anomalies: [BalanceAnomaly] = []

        for row in matchupRows {
            let target = targetBand(for: row)

            if row.tickLimitRate >= thresholds.timeoutRate {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .timeout,
                        severity: .critical,
                        detail: "\(row.tier.displayName): \(row.heroID)+\(row.petID) vs \(row.enemyID) exceeded \(thresholds.prolongedFightTicks)-tick limit \(percent(row.tickLimitRate)) of runs",
                        value: row.tickLimitRate
                    )
                )
            } else if row.averageTickCount > Double(thresholds.prolongedFightTicks) {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .prolongedFight,
                        severity: .critical,
                        detail: "\(row.tier.displayName): \(row.heroID)+\(row.petID) vs \(row.enemyID) averaged \(String(format: "%.0f", row.averageTickCount)) ticks (limit \(thresholds.prolongedFightTicks))",
                        value: row.averageTickCount
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
            } else if row.winRate < target.min {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .belowTarget,
                        severity: .warning,
                        detail: "\(row.tier.displayName): \(row.heroID)+\(row.petID) vs \(row.enemyID) win rate \(percent(row.winRate)) (target \(percent(target.min))-\(percent(target.max)))",
                        value: row.winRate
                    )
                )
            } else if row.winRate > target.max {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .aboveTarget,
                        severity: .warning,
                        detail: "\(row.tier.displayName): \(row.heroID)+\(row.petID) vs \(row.enemyID) win rate \(percent(row.winRate)) (target \(percent(target.min))-\(percent(target.max)))",
                        value: row.winRate
                    )
                )
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
