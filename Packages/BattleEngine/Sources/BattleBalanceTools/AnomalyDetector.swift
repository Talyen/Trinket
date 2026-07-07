import BattleEngine
import Foundation

enum EnemyDifficultyRole: String, Codable, CaseIterable {
    case fodder
    case elite
    case boss
}

enum AnomalyDetector {
    struct Thresholds: Equatable {
        let hardCounterWinRate: Double
        let timeoutRate: Double
        let minFightTicks: Int
        let maxFightTicks: Int
        let underpoweredAbilityWinRate: Double
        let overpoweredAbilityWinRate: Double

        init(
            hardCounterWinRate: Double = 0.25,
            timeoutRate: Double = 0.10,
            minFightTicks: Int = BalanceSweepDefaults.minFightTicks,
            maxFightTicks: Int = BalanceSweepDefaults.maxTicks,
            underpoweredAbilityWinRate: Double = 0.45,
            overpoweredAbilityWinRate: Double = 0.55
        ) {
            self.hardCounterWinRate = hardCounterWinRate
            self.timeoutRate = timeoutRate
            self.minFightTicks = minFightTicks
            self.maxFightTicks = maxFightTicks
            self.underpoweredAbilityWinRate = underpoweredAbilityWinRate
            self.overpoweredAbilityWinRate = overpoweredAbilityWinRate
        }

        static let `default` = Thresholds()
    }

    struct WinRateBand: Equatable {
        let min: Double
        let max: Double
        let role: EnemyDifficultyRole
        let tier: SimulationPowerTier

        init(min: Double, max: Double, role: EnemyDifficultyRole, tier: SimulationPowerTier) {
            self.min = min
            self.max = max
            self.role = role
            self.tier = tier
        }
    }

    static func enemyRole(for row: MatchupSweepRow) -> EnemyDifficultyRole {
        if row.isBoss { return .boss }
        if row.isElite { return .elite }
        return .fodder
    }

    static func enemyRole(isBoss: Bool, isElite: Bool) -> EnemyDifficultyRole {
        if isBoss { return .boss }
        if isElite { return .elite }
        return .fodder
    }

    /// Win-rate targets by simulation tier and enemy role.
    ///
    /// | Role   | Early   | Middle  | Late    |
    /// |--------|---------|---------|---------|
    /// | Fodder | 90–99%  | 80–90%  | 70–80%  |
    /// | Elite  | 80–90%  | 70–80%  | 60–70%  |
    /// | Boss   | 70–80%  | 60–70%  | 50–60%  |
    static func targetBand(for row: MatchupSweepRow) -> WinRateBand {
        targetBand(tier: row.tier, role: enemyRole(for: row))
    }

    static func targetBand(tier: SimulationPowerTier, role: EnemyDifficultyRole) -> WinRateBand {
        let bounds: (min: Double, max: Double)
        switch (tier, role) {
        case (.early, .fodder): bounds = (0.90, 0.99)
        case (.middle, .fodder): bounds = (0.80, 0.90)
        case (.lateGame, .fodder): bounds = (0.70, 0.80)
        case (.early, .elite): bounds = (0.80, 0.90)
        case (.middle, .elite): bounds = (0.70, 0.80)
        case (.lateGame, .elite): bounds = (0.60, 0.70)
        case (.early, .boss): bounds = (0.70, 0.80)
        case (.middle, .boss): bounds = (0.60, 0.70)
        case (.lateGame, .boss): bounds = (0.50, 0.60)
        }
        return WinRateBand(min: bounds.min, max: bounds.max, role: role, tier: tier)
    }

    static func isDurationInBand(
        averageTickCount: Double,
        thresholds: Thresholds = .default
    ) -> Bool {
        averageTickCount >= Double(thresholds.minFightTicks)
            && averageTickCount <= Double(thresholds.maxFightTicks)
    }

    static func detect(
        matchupRows: [MatchupSweepRow],
        abilityRows: [AbilityComparisonRow],
        thresholds: Thresholds = .default
    ) -> [BalanceAnomaly] {
        var anomalies: [BalanceAnomaly] = []

        for row in matchupRows {
            let target = targetBand(for: row)
            let roleLabel = target.role.rawValue

            if row.tickLimitRate >= thresholds.timeoutRate {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .timeout,
                        severity: .critical,
                        subjectID: row.id,
                        detail: "\(row.tier.displayName) (\(roleLabel)): \(row.heroID)+\(row.petID) vs \(row.enemyID) exceeded \(thresholds.maxFightTicks)-tick limit \(percent(row.tickLimitRate)) of runs",
                        value: row.tickLimitRate
                    )
                )
            } else if row.averageTickCount > Double(thresholds.maxFightTicks) {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .timeout,
                        severity: .critical,
                        subjectID: row.id,
                        detail: "\(row.tier.displayName) (\(roleLabel)): \(row.heroID)+\(row.petID) vs \(row.enemyID) averaged \(String(format: "%.0f", row.averageTickCount)) ticks (max \(thresholds.maxFightTicks))",
                        value: row.averageTickCount
                    )
                )
            } else if row.averageTickCount < Double(thresholds.minFightTicks) {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .tooShort,
                        severity: .warning,
                        subjectID: row.id,
                        detail: "\(row.tier.displayName) (\(roleLabel)): \(row.heroID)+\(row.petID) vs \(row.enemyID) averaged \(String(format: "%.0f", row.averageTickCount)) ticks (min \(thresholds.minFightTicks))",
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
                        subjectID: row.id,
                        detail: "\(row.tier.displayName) (\(roleLabel)): \(row.heroID)+\(row.petID) vs \(row.enemyID) win rate \(percent(row.winRate))",
                        value: row.winRate
                    )
                )
            } else if row.winRate < target.min {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .belowTarget,
                        severity: .warning,
                        subjectID: row.id,
                        detail: "\(row.tier.displayName) (\(roleLabel)): \(row.heroID)+\(row.petID) vs \(row.enemyID) win rate \(percent(row.winRate)) (target \(percent(target.min))-\(percent(target.max)))",
                        value: row.winRate
                    )
                )
            } else if row.winRate > target.max {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .aboveTarget,
                        severity: .warning,
                        subjectID: row.id,
                        detail: "\(row.tier.displayName) (\(roleLabel)): \(row.heroID)+\(row.petID) vs \(row.enemyID) win rate \(percent(row.winRate)) (target \(percent(target.min))-\(percent(target.max)))",
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
                        subjectID: row.id,
                        detail: "\(row.tier.displayName) \(row.combatantName) \(row.abilityTier.rawValue) \(row.abilityName) vs \(row.siblingAbilityName): \(percent(row.winRate))",
                        value: row.winRate
                    )
                )
            } else if row.winRate > thresholds.overpoweredAbilityWinRate {
                anomalies.append(
                    BalanceAnomaly(
                        kind: .overpoweredAbility,
                        severity: .warning,
                        subjectID: row.id,
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
