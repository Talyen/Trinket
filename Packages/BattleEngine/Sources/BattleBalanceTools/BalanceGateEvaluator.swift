import Foundation
import BattleEngine

public struct BalanceGateThresholds: Equatable, Sendable, Codable {
    /// Maximum share of matchup rows with a 100% win rate (middle-tier fodder).
    public let maxFodderPerfectWinRateMiddle: Double
    /// Minimum share of rows inside the win-rate target band (middle-tier fodder).
    public let minFodderInBandRateMiddle: Double
    /// Maximum share of rows that hit the tick limit.
    public let maxTimeoutRate: Double
    /// Maximum share of rows averaging below the minimum fight duration.
    public let maxTooShortRate: Double

    public init(
        maxFodderPerfectWinRateMiddle: Double = 0.45,
        minFodderInBandRateMiddle: Double = 0.35,
        maxTimeoutRate: Double = 0.12,
        maxTooShortRate: Double = 0.20
    ) {
        self.maxFodderPerfectWinRateMiddle = maxFodderPerfectWinRateMiddle
        self.minFodderInBandRateMiddle = minFodderInBandRateMiddle
        self.maxTimeoutRate = maxTimeoutRate
        self.maxTooShortRate = maxTooShortRate
    }

    public static let ci = BalanceGateThresholds()
}

public struct BalanceGateViolation: Equatable, Sendable, Codable {
    public let metric: String
    public let actual: Double
    public let limit: Double
    public let comparison: String

    public var detail: String {
        "\(metric): \(formatted(actual)) \(comparison) \(formatted(limit))"
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }
}

public enum BalanceGateEvaluator {
    public static func evaluate(
        _ result: BalanceSweepResult,
        thresholds: BalanceGateThresholds = .ci
    ) -> [BalanceGateViolation] {
        var violations: [BalanceGateViolation] = []

        let kpis = result.kpis
        let middleTier = kpis.byTier[SimulationPowerTier.middle.rawValue]
        let fodderMiddle = middleTier?.byRole[EnemyDifficultyRole.fodder.rawValue]

        if let fodderMiddle {
            if fodderMiddle.perfectWinRate > thresholds.maxFodderPerfectWinRateMiddle {
                violations.append(
                    BalanceGateViolation(
                        metric: "middle.fodder.perfectWinRate",
                        actual: fodderMiddle.perfectWinRate,
                        limit: thresholds.maxFodderPerfectWinRateMiddle,
                        comparison: ">"
                    )
                )
            }
            if fodderMiddle.inBandRate < thresholds.minFodderInBandRateMiddle {
                violations.append(
                    BalanceGateViolation(
                        metric: "middle.fodder.inBandRate",
                        actual: fodderMiddle.inBandRate,
                        limit: thresholds.minFodderInBandRateMiddle,
                        comparison: "<"
                    )
                )
            }
        }

        let timeoutRate = Double(result.anomalies.filter { $0.kind == .timeout }.count)
            / Double(max(1, result.matchupRows.count))
        if timeoutRate > thresholds.maxTimeoutRate {
            violations.append(
                BalanceGateViolation(
                    metric: "matchup.timeoutRate",
                    actual: timeoutRate,
                    limit: thresholds.maxTimeoutRate,
                    comparison: ">"
                )
            )
        }

        let tooShortRate = Double(result.anomalies.filter { $0.kind == .tooShort }.count)
            / Double(max(1, result.matchupRows.count))
        if tooShortRate > thresholds.maxTooShortRate {
            violations.append(
                BalanceGateViolation(
                    metric: "matchup.tooShortRate",
                    actual: tooShortRate,
                    limit: thresholds.maxTooShortRate,
                    comparison: ">"
                )
            )
        }

        return violations
    }
}
