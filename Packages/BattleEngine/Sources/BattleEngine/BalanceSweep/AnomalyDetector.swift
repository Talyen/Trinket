import Foundation

public enum AnomalyDetector {
    public struct Thresholds: Equatable, Sendable {
        public let hardCounterWinRate: Double
        public let trivialFightWinRate: Double
        public let underpoweredAbilityWinRate: Double
        public let overpoweredAbilityWinRate: Double
        public let bossLateGameWinRate: Double

        public init(
            hardCounterWinRate: Double = 0.25,
            trivialFightWinRate: Double = 0.95,
            underpoweredAbilityWinRate: Double = 0.45,
            overpoweredAbilityWinRate: Double = 0.55,
            bossLateGameWinRate: Double = 0.40
        ) {
            self.hardCounterWinRate = hardCounterWinRate
            self.trivialFightWinRate = trivialFightWinRate
            self.underpoweredAbilityWinRate = underpoweredAbilityWinRate
            self.overpoweredAbilityWinRate = overpoweredAbilityWinRate
            self.bossLateGameWinRate = bossLateGameWinRate
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
            if row.winRate < thresholds.hardCounterWinRate {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .hardCounter,
                        severity: .critical,
                        detail: "\(row.tier.displayName): \(row.heroID)+\(row.petID) vs \(row.enemyID) win rate \(percent(row.winRate))",
                        value: row.winRate
                    )
                )
            } else if row.winRate > thresholds.trivialFightWinRate {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .trivialFight,
                        severity: .critical,
                        detail: "\(row.tier.displayName): \(row.heroID)+\(row.petID) vs \(row.enemyID) win rate \(percent(row.winRate))",
                        value: row.winRate
                    )
                )
            }

            if row.isBoss,
               row.tier == .lateGame,
               row.winRate < thresholds.bossLateGameWinRate {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .bossTuning,
                        severity: .critical,
                        detail: "Late boss \(row.enemyID) vs \(row.heroID)+\(row.petID) win rate \(percent(row.winRate))",
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
