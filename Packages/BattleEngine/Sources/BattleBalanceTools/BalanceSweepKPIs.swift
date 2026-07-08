import BattleEngine
import Foundation

struct BalanceRoleKPI: Equatable, Codable {
    let rowCount: Int
    let inBandCount: Int
    let perfectWinCount: Int
    let durationInBandCount: Int

    var inBandRate: Double {
        guard rowCount > 0 else { return 0 }
        return Double(inBandCount) / Double(rowCount)
    }

    var perfectWinRate: Double {
        guard rowCount > 0 else { return 0 }
        return Double(perfectWinCount) / Double(rowCount)
    }

    var durationInBandRate: Double {
        guard rowCount > 0 else { return 0 }
        return Double(durationInBandCount) / Double(rowCount)
    }
}

struct BalanceTierKPI: Equatable, Codable {
    let rowCount: Int
    let inBandCount: Int
    let perfectWinCount: Int
    let durationInBandCount: Int
    let byRole: [String: BalanceRoleKPI]

    var inBandRate: Double {
        guard rowCount > 0 else { return 0 }
        return Double(inBandCount) / Double(rowCount)
    }

    var perfectWinRate: Double {
        guard rowCount > 0 else { return 0 }
        return Double(perfectWinCount) / Double(rowCount)
    }

    var durationInBandRate: Double {
        guard rowCount > 0 else { return 0 }
        return Double(durationInBandCount) / Double(rowCount)
    }
}

struct BalanceSweepKPIs: Equatable, Codable {
    let totalMatchupRows: Int
    let inBandCount: Int
    let perfectWinCount: Int
    let durationInBandCount: Int
    let byTier: [String: BalanceTierKPI]

    var inBandRate: Double {
        guard totalMatchupRows > 0 else { return 0 }
        return Double(inBandCount) / Double(totalMatchupRows)
    }

    var perfectWinRate: Double {
        guard totalMatchupRows > 0 else { return 0 }
        return Double(perfectWinCount) / Double(totalMatchupRows)
    }

    var durationInBandRate: Double {
        guard totalMatchupRows > 0 else { return 0 }
        return Double(durationInBandCount) / Double(totalMatchupRows)
    }

    static func compute(
        from rows: [MatchupSweepRow],
        thresholds: AnomalyDetector.Thresholds = .default
    ) -> BalanceSweepKPIs {
        var inBandCount = 0
        var perfectWinCount = 0
        var durationInBandCount = 0

        var tierBuckets: [String: [MatchupSweepRow]] = [:]
        for row in rows {
            let band = AnomalyDetector.targetBand(for: row)
            if row.winRate >= band.min, row.winRate <= band.max {
                inBandCount += 1
            }
            if row.winRate >= 1.0 {
                perfectWinCount += 1
            }
            if AnomalyDetector.isDurationInBand(
                averageTickCount: row.averageTickCount,
                thresholds: thresholds
            ) {
                durationInBandCount += 1
            }
            tierBuckets[row.tier.rawValue, default: []].append(row)
        }

        let byTier = tierBuckets.mapValues { tierRows in
            makeTierKPI(from: tierRows, thresholds: thresholds)
        }

        return BalanceSweepKPIs(
            totalMatchupRows: rows.count,
            inBandCount: inBandCount,
            perfectWinCount: perfectWinCount,
            durationInBandCount: durationInBandCount,
            byTier: byTier
        )
    }

    private static func makeTierKPI(
        from rows: [MatchupSweepRow],
        thresholds: AnomalyDetector.Thresholds
    ) -> BalanceTierKPI {
        var inBandCount = 0
        var perfectWinCount = 0
        var durationInBandCount = 0
        var roleBuckets: [String: [MatchupSweepRow]] = [:]

        for row in rows {
            let band = AnomalyDetector.targetBand(for: row)
            if row.winRate >= band.min, row.winRate <= band.max {
                inBandCount += 1
            }
            if row.winRate >= 1.0 {
                perfectWinCount += 1
            }
            if AnomalyDetector.isDurationInBand(
                averageTickCount: row.averageTickCount,
                thresholds: thresholds
            ) {
                durationInBandCount += 1
            }
            let role = AnomalyDetector.enemyRole(for: row).rawValue
            roleBuckets[role, default: []].append(row)
        }

        let byRole = roleBuckets.mapValues { roleRows in
            makeRoleKPI(from: roleRows, thresholds: thresholds)
        }

        return BalanceTierKPI(
            rowCount: rows.count,
            inBandCount: inBandCount,
            perfectWinCount: perfectWinCount,
            durationInBandCount: durationInBandCount,
            byRole: byRole
        )
    }

    private static func makeRoleKPI(
        from rows: [MatchupSweepRow],
        thresholds: AnomalyDetector.Thresholds
    ) -> BalanceRoleKPI {
        var inBandCount = 0
        var perfectWinCount = 0
        var durationInBandCount = 0

        for row in rows {
            let band = AnomalyDetector.targetBand(for: row)
            if row.winRate >= band.min, row.winRate <= band.max {
                inBandCount += 1
            }
            if row.winRate >= 1.0 {
                perfectWinCount += 1
            }
            if AnomalyDetector.isDurationInBand(
                averageTickCount: row.averageTickCount,
                thresholds: thresholds
            ) {
                durationInBandCount += 1
            }
        }

        return BalanceRoleKPI(
            rowCount: rows.count,
            inBandCount: inBandCount,
            perfectWinCount: perfectWinCount,
            durationInBandCount: durationInBandCount
        )
    }
}
