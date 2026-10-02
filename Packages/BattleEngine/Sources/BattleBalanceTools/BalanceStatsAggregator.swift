import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

public struct WinRateSummary: Equatable, Sendable {
    public var id: String
    public var ownerID: String?
    public var wins: Int
    public var battles: Int
    public var winRate: Double
    public var wilsonLow: Double
    public var wilsonHigh: Double
    public var deltaVsPeer: Double
    public var targetBandDelta: Double?
    public var flagged: Bool
    public var flagReason: String?
    public var sampleTooLow: Bool
}

public struct PairCellSummary: Equatable, Sendable {
    public var leftID: String
    public var rightID: String
    public var wins: Int
    public var battles: Int
    public var winRate: Double
    public var deltaVsPeer: Double
    public var flagged: Bool
    public var flagReason: String?
}

public enum BalanceDurationThresholds {
    public static let trashMinRounds = 5
    public static let trashMaxRounds = 15
    public static let bossMinRounds = 15
    public static let bossMaxRounds = 30
    public static let flagRate = BalanceSweepConfig.durationFlagRateDefault

    public static var trashGoalBand: String {
        "\(trashMinRounds)-\(trashMaxRounds)"
    }

    public static var bossGoalBand: String {
        "\(bossMinRounds)-\(bossMaxRounds)"
    }
}

public struct BalanceDurationBucketStats: Equatable, Sendable {
    public var battles: Int
    public var shortBattles: Int
    public var longBattles: Int
    public var averageRounds: Double
    public var averageRoundsWhenShort: Double
    public var averageRoundsWhenLong: Double
    public var maxRounds: Int
    public var worstEnemyID: String?
    public var flagged: Bool
    public var flagReason: String?

    public var shortRate: Double {
        guard battles > 0 else { return 0 }
        return Double(shortBattles) / Double(battles)
    }

    public var longRate: Double {
        guard battles > 0 else { return 0 }
        return Double(longBattles) / Double(battles)
    }
}

public struct BalanceEnemyDurationStats: Equatable, Sendable {
    public var enemyID: String
    public var isBoss: Bool
    public var battles: Int
    public var averageRounds: Double
    public var shortRate: Double
    public var longRate: Double
    public var flagged: Bool
    public var flagReason: String?
}

public struct BalanceCombatantDurationStats: Equatable, Sendable {
    public var combatantID: String
    public var role: Combatant.Role
    public var battles: Int
    public var averageRounds: Double
    public var shortRate: Double
    public var longRate: Double
    public var flagged: Bool
    public var flagReason: String?
}

public struct BalanceTierStats: Sendable {
    public var tier: SimulationPowerTier
    public var battles: Int
    public var decidedBattles: Int
    public var wins: Int
    public var timeouts: Int
    public var averageRounds: Double
    public var averagePartyHPOnWin: Double
    public var averageEnemyHPOnLoss: Double
    public var trashDuration: BalanceDurationBucketStats
    public var bossDuration: BalanceDurationBucketStats
    public var enemyDurations: [BalanceEnemyDurationStats]
    public var heroDurations: [BalanceCombatantDurationStats]
    public var companionDurations: [BalanceCombatantDurationStats]
    public var heroes: [WinRateSummary]
    public var heroesTrash: [WinRateSummary]
    public var heroesBoss: [WinRateSummary]
    public var companions: [WinRateSummary]
    public var companionsTrash: [WinRateSummary]
    public var companionsBoss: [WinRateSummary]
    public var enemies: [WinRateSummary]
    public var items: [WinRateSummary]
    public var abilities: [WinRateSummary]
    public var talents: [WinRateSummary]
    public var enemyAbilities: [WinRateSummary]
    public var enemyTraits: [WinRateSummary]
    public var affixes: [WinRateSummary]
    public var heroCompanionCells: [PairCellSummary]
    public var heroEnemyCells: [PairCellSummary]
}

public enum BalanceStatsAggregator {
    public static func summarize(
        report: BalanceSweepReport,
        records: [BalanceBattleRecord]? = nil,
    ) -> [BalanceTierStats] {
        let recordsByTier = Dictionary(grouping: records ?? report.records, by: \.tier)
        return report.config.tiers.map { tier in
            TierAggregation(tier: tier, records: recordsByTier[tier] ?? [], config: report.config).summary
        }
    }

    public static func winPercent(wins: Int, decided: Int) -> Double {
        guard decided > 0 else { return 0 }
        return 100.0 * Double(wins) / Double(decided)
    }

    public static func wilson(wins: Int, battles: Int, z: Double = 1.96) -> (low: Double, high: Double) {
        guard battles > 0 else { return (0, 0) }
        let n = Double(battles)
        let p = Double(wins) / n
        let z2 = z * z
        let denominator = 1 + z2 / n
        let center = p + z2 / (2 * n)
        let margin = z * ((p * (1 - p) / n + z2 / (4 * n * n)).squareRoot())
        let low = max(0, (center - margin) / denominator)
        let high = min(1, (center + margin) / denominator)
        return (low, high)
    }
}

/// One tier's inputs and shared comparison context. Report assembly calls the
/// metric owners directly rather than passing intermediate tuples between helpers.
private struct TierAggregation {
    let tier: SimulationPowerTier
    let records: [BalanceBattleRecord]
    let config: BalanceSweepConfig
    let decided: [BalanceBattleRecord]
    private let wins: Int
    private let winRate: Double

    init(tier: SimulationPowerTier, records: [BalanceBattleRecord], config: BalanceSweepConfig) {
        self.tier = tier
        self.records = records
        self.config = config
        decided = records.filter(\.result.isDecided)
        wins = decided.count { $0.result.isVictory }
        winRate = decided.isEmpty ? 0 : Double(wins) / Double(decided.count)
    }

    var summary: BalanceTierStats {
        let heroes = ownerMargins(decided, id: \.heroID)
        let companions = ownerMargins(decided, id: \.companionID)
        let ownerRates = Dictionary(uniqueKeysWithValues: (heroes + companions).map { ($0.id, $0.winRate) })
        let trash = decided.filter { !$0.isBoss }
        let boss = decided.filter(\.isBoss)
        func presence(
            _ hero: KeyPath<BalanceBattleRecord, [String]>,
            _ companion: KeyPath<BalanceBattleRecord, [String]>,
        ) -> [WinRateSummary] {
            BalanceIdentityMargins.withinOwnerMargins(
                records: decided,
                ownerAndIDs: { record in
                    record[keyPath: hero].map { (record.heroID, $0) } + record[keyPath: companion].map { (record.companionID, $0) }
                },
                ownerRates: ownerRates, threshold: config.peerDeltaFlagThreshold,
            )
        }
        return BalanceTierStats(
            tier: tier, battles: records.count, decidedBattles: decided.count, wins: wins,
            timeouts: records.count { $0.result.timedOut },
            averageRounds: average(records) { Double($0.result.rounds) },
            averagePartyHPOnWin: average(decided.filter(\.result.isVictory)) { $0.result.partyHPRemainingFraction },
            averageEnemyHPOnLoss: average(decided.filter { !$0.result.isVictory }) { $0.result.enemyHPRemainingFraction },
            trashDuration: durationBucket(isBoss: false),
            bossDuration: durationBucket(isBoss: true),
            enemyDurations: BalanceDurationAggregation.enemyDurationTable(records, flagRate: config.durationFlagRate),
            heroDurations: combatantDurations(role: .hero, id: \.heroID),
            companionDurations: combatantDurations(role: .companion, id: \.companionID),
            heroes: heroes,
            heroesTrash: ownerMargins(trash, id: \.heroID),
            heroesBoss: ownerMargins(boss, id: \.heroID, isBoss: true),
            companions: companions,
            companionsTrash: ownerMargins(trash, id: \.companionID),
            companionsBoss: ownerMargins(boss, id: \.companionID, isBoss: true),
            enemies: BalanceIdentityMargins.enemyMargins(records: decided, targetBand: targetBand),
            items: presence(\.heroItemBaseIDs, \.companionItemBaseIDs),
            abilities: presence(\.heroAbilityIDs, \.companionAbilityIDs),
            talents: presence(\.heroTalentIDs, \.companionTalentIDs),
            enemyAbilities: opponentMargins(\.enemyAbilityIDs),
            enemyTraits: opponentMargins(\.enemyTraitIDs),
            affixes: presence(\.heroAffixIDs, \.companionAffixIDs),
            heroCompanionCells: matchupCells(right: \.companionID),
            heroEnemyCells: matchupCells(right: \.enemyID),
        )
    }

    private func ownerMargins(
        _ records: [BalanceBattleRecord],
        id: KeyPath<BalanceBattleRecord, String>,
        isBoss: Bool = false,
    ) -> [WinRateSummary] {
        BalanceIdentityMargins.ownerMargins(
            records: records, id: id, peerRate: winRate,
            threshold: config.peerDeltaFlagThreshold, targetBand: targetBand(isBoss: isBoss),
        )
    }

    private func opponentMargins(_ ids: KeyPath<BalanceBattleRecord, [String]>) -> [WinRateSummary] {
        BalanceIdentityMargins.margin(
            records: decided, ids: { $0[keyPath: ids] }, peerRate: winRate,
            threshold: config.peerDeltaFlagThreshold, positiveFlag: "EASY", negativeFlag: "HARD",
        )
    }

    private func matchupCells(right: KeyPath<BalanceBattleRecord, String>) -> [PairCellSummary] {
        BalanceIdentityMargins.flaggedPairCells(
            records: decided, left: \.heroID, right: right,
            peerRate: winRate, threshold: config.peerDeltaFlagThreshold,
        )
    }

    private func durationBucket(isBoss: Bool) -> BalanceDurationBucketStats {
        BalanceDurationAggregation.durationStats(
            records.filter { $0.isBoss == isBoss },
            minRounds: isBoss ? BalanceDurationThresholds.bossMinRounds : BalanceDurationThresholds.trashMinRounds,
            maxRounds: isBoss ? BalanceDurationThresholds.bossMaxRounds : BalanceDurationThresholds.trashMaxRounds,
            flagRate: config.durationFlagRate,
        )
    }

    private func combatantDurations(role: Combatant.Role, id: KeyPath<BalanceBattleRecord, String>) -> [BalanceCombatantDurationStats] {
        BalanceDurationAggregation.combatantDurationTable(records, role: role, idPath: id, flagRate: config.durationFlagRate)
    }

    private func targetBand(isBoss: Bool) -> (lower: Double, upper: Double) {
        if isBoss {
            return (0.70, 0.80)
        }
        switch tier {
        case .early: return (0.90, 0.99)
        case .middle: return (0.80, 0.90)
        case .lateGame: return (0.70, 0.80)
        }
    }

    private func average(_ records: [BalanceBattleRecord], value: (BalanceBattleRecord) -> Double) -> Double {
        records.isEmpty ? 0 : records.reduce(0.0) { $0 + value($1) } / Double(records.count)
    }
}
