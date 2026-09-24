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

    public init(
        id: String,
        ownerID: String? = nil,
        wins: Int,
        battles: Int,
        winRate: Double,
        wilsonLow: Double,
        wilsonHigh: Double,
        deltaVsPeer: Double,
        targetBandDelta: Double? = nil,
        flagged: Bool,
        flagReason: String? = nil,
        sampleTooLow: Bool,
    ) {
        self.id = id
        self.ownerID = ownerID
        self.wins = wins
        self.battles = battles
        self.winRate = winRate
        self.wilsonLow = wilsonLow
        self.wilsonHigh = wilsonHigh
        self.deltaVsPeer = deltaVsPeer
        self.targetBandDelta = targetBandDelta
        self.flagged = flagged
        self.flagReason = flagReason
        self.sampleTooLow = sampleTooLow
    }
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
        let source = records ?? report.records
        let recordsByTier = Dictionary(grouping: source, by: \.tier)
        return report.config.tiers.map { tier in
            summarizeTier(
                tier: tier,
                records: recordsByTier[tier] ?? [],
                config: report.config,
            )
        }
    }

    private static func summarizeTier(
        tier: SimulationPowerTier,
        records: [BalanceBattleRecord],
        config: BalanceSweepConfig,
    ) -> BalanceTierStats {
        let overall = tierOverall(records: records)
        let decided = overall.decided
        let threshold = config.peerDeltaFlagThreshold
        let context = ownerMarginsContext(
            decided: decided,
            overallRate: overall.winRate,
            threshold: threshold,
            tier: tier,
        )
        let duration = durationStats(records: records, flagRate: config.durationFlagRate)
        let splits = rosterSplits(
            decided: decided,
            overallRate: overall.winRate,
            threshold: threshold,
            tier: tier,
        )
        let loadout = loadoutMargins(
            decided: decided,
            ownerRates: context.ownerRates,
            threshold: threshold,
        )
        let opponents = enemyFacingMargins(
            decided: decided,
            overallRate: overall.winRate,
            threshold: threshold,
        )
        let cells = matchupCells(decided: decided, overallRate: overall.winRate, threshold: threshold)

        return BalanceTierStats(
            tier: tier,
            battles: records.count,
            decidedBattles: decided.count,
            wins: overall.wins,
            timeouts: overall.timeouts,
            averageRounds: overall.averageRounds,
            averagePartyHPOnWin: overall.averagePartyHPOnWin,
            averageEnemyHPOnLoss: overall.averageEnemyHPOnLoss,
            trashDuration: duration.trash,
            bossDuration: duration.boss,
            enemyDurations: duration.enemies,
            heroDurations: duration.heroes,
            companionDurations: duration.companions,
            heroes: context.heroes,
            heroesTrash: splits.heroesTrash,
            heroesBoss: splits.heroesBoss,
            companions: context.companions,
            companionsTrash: splits.companionsTrash,
            companionsBoss: splits.companionsBoss,
            enemies: BalanceIdentityMargins.enemyMargins(records: decided) {
                targetBand(isBoss: $0, tier: tier)
            },
            items: loadout.items,
            abilities: loadout.abilities,
            talents: loadout.talents,
            enemyAbilities: opponents.abilities,
            enemyTraits: opponents.traits,
            affixes: loadout.affixes,
            heroCompanionCells: cells.heroCompanion,
            heroEnemyCells: cells.heroEnemy,
        )
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

private extension BalanceStatsAggregator {
    private struct TierOverall {
        var decided: [BalanceBattleRecord]
        var wins: Int
        var timeouts: Int
        var averageRounds: Double
        var averagePartyHPOnWin: Double
        var averageEnemyHPOnLoss: Double
        var winRate: Double
    }

    private static func tierOverall(records: [BalanceBattleRecord]) -> TierOverall {
        let decided = records.filter(\.result.isDecided)
        let wins = decided.count { $0.result.isVictory }
        let losses = decided.count { !$0.result.isVictory }
        return TierOverall(
            decided: decided,
            wins: wins,
            timeouts: records.count { $0.result.timedOut },
            averageRounds: records.isEmpty
                ? 0
                : records.reduce(0.0) { $0 + Double($1.result.rounds) } / Double(records.count),
            averagePartyHPOnWin: wins == 0
                ? 0
                : decided.filter(\.result.isVictory).reduce(0.0) { $0 + $1.result.partyHPRemainingFraction } / Double(wins),
            averageEnemyHPOnLoss: losses == 0
                ? 0
                : decided.filter { !$0.result.isVictory }.reduce(0.0) { $0 + $1.result.enemyHPRemainingFraction } / Double(losses),
            winRate: decided.isEmpty ? 0 : Double(wins) / Double(decided.count),
        )
    }

    private static func ownerMarginsContext(
        decided: [BalanceBattleRecord],
        overallRate: Double,
        threshold: Double,
        tier: SimulationPowerTier,
    ) -> (heroes: [WinRateSummary], companions: [WinRateSummary], ownerRates: [String: Double]) {
        func margins(_ id: KeyPath<BalanceBattleRecord, String>) -> [WinRateSummary] {
            BalanceIdentityMargins.ownerMargins(
                records: decided,
                id: id,
                peerRate: overallRate,
                threshold: threshold,
                targetBand: targetBand(isBoss: false, tier: tier),
            )
        }
        let heroes = margins(\.heroID)
        let companions = margins(\.companionID)
        let rates = Dictionary(uniqueKeysWithValues: (heroes + companions).map { ($0.id, $0.winRate) })
        return (heroes, companions, rates)
    }

    private static func enemyFacingMargins(
        decided: [BalanceBattleRecord],
        overallRate: Double,
        threshold: Double,
    ) -> (abilities: [WinRateSummary], traits: [WinRateSummary]) {
        (
            opponentMargins(
                records: decided,
                ids: \.enemyAbilityIDs,
                peerRate: overallRate,
                threshold: threshold,
            ),
            opponentMargins(
                records: decided,
                ids: { $0.enemyTraitIDs },
                peerRate: overallRate,
                threshold: threshold,
            ),
        )
    }

    private static func matchupCells(
        decided: [BalanceBattleRecord],
        overallRate: Double,
        threshold: Double,
    ) -> (heroCompanion: [PairCellSummary], heroEnemy: [PairCellSummary]) {
        (
            BalanceIdentityMargins.flaggedPairCells(
                records: decided,
                left: \.heroID,
                right: \.companionID,
                peerRate: overallRate,
                threshold: threshold,
            ),
            BalanceIdentityMargins.flaggedPairCells(
                records: decided,
                left: \.heroID,
                right: \.enemyID,
                peerRate: overallRate,
                threshold: threshold,
            ),
        )
    }

    private static func durationStats(
        records: [BalanceBattleRecord],
        flagRate: Double,
    ) -> (
        trash: BalanceDurationBucketStats,
        boss: BalanceDurationBucketStats,
        enemies: [BalanceEnemyDurationStats],
        heroes: [BalanceCombatantDurationStats],
        companions: [BalanceCombatantDurationStats],
    ) {
        (
            BalanceDurationAggregation.durationStats(
                records.filter { !$0.isBoss },
                minRounds: BalanceDurationThresholds.trashMinRounds,
                maxRounds: BalanceDurationThresholds.trashMaxRounds,
                flagRate: flagRate,
            ),
            BalanceDurationAggregation.durationStats(
                records.filter(\.isBoss),
                minRounds: BalanceDurationThresholds.bossMinRounds,
                maxRounds: BalanceDurationThresholds.bossMaxRounds,
                flagRate: flagRate,
            ),
            BalanceDurationAggregation.enemyDurationTable(records, flagRate: flagRate),
            BalanceDurationAggregation.combatantDurationTable(
                records,
                role: .hero,
                idPath: \.heroID,
                flagRate: flagRate,
            ),
            BalanceDurationAggregation.combatantDurationTable(
                records,
                role: .companion,
                idPath: \.companionID,
                flagRate: flagRate,
            ),
        )
    }

    private static func rosterSplits(
        decided: [BalanceBattleRecord],
        overallRate: Double,
        threshold: Double,
        tier: SimulationPowerTier,
    ) -> (
        heroesTrash: [WinRateSummary],
        heroesBoss: [WinRateSummary],
        companionsTrash: [WinRateSummary],
        companionsBoss: [WinRateSummary],
    ) {
        let trash = decided.filter { !$0.isBoss }
        let boss = decided.filter(\.isBoss)
        func margins(
            _ records: [BalanceBattleRecord],
            id: KeyPath<BalanceBattleRecord, String>,
            isBoss: Bool,
        ) -> [WinRateSummary] {
            BalanceIdentityMargins.ownerMargins(
                records: records,
                id: id,
                peerRate: overallRate,
                threshold: threshold,
                targetBand: targetBand(isBoss: isBoss, tier: tier),
            )
        }
        return (
            margins(trash, id: \.heroID, isBoss: false),
            margins(boss, id: \.heroID, isBoss: true),
            margins(trash, id: \.companionID, isBoss: false),
            margins(boss, id: \.companionID, isBoss: true),
        )
    }

    private static func loadoutMargins(
        decided: [BalanceBattleRecord],
        ownerRates: [String: Double],
        threshold: Double,
    ) -> (
        items: [WinRateSummary],
        abilities: [WinRateSummary],
        talents: [WinRateSummary],
        affixes: [WinRateSummary],
    ) {
        func presence(_ ids: (BalanceBattleRecord) -> [(String, String)]) -> [WinRateSummary] {
            BalanceIdentityMargins.withinOwnerMargins(
                records: decided,
                ownerAndIDs: ids,
                ownerRates: ownerRates,
                threshold: threshold,
            )
        }
        return (
            presence { ownerIDPairs($0, heroIDs: $0.heroItemBaseIDs, companionIDs: $0.companionItemBaseIDs) },
            presence { ownerIDPairs($0, heroIDs: $0.heroAbilityIDs, companionIDs: $0.companionAbilityIDs) },
            presence { ownerIDPairs($0, heroIDs: $0.heroTalentIDs, companionIDs: $0.companionTalentIDs) },
            presence { ownerIDPairs($0, heroIDs: $0.heroAffixIDs, companionIDs: $0.companionAffixIDs) },
        )
    }

    private static func opponentMargins(
        records: [BalanceBattleRecord],
        ids: (BalanceBattleRecord) -> [String],
        peerRate: Double,
        threshold: Double,
    ) -> [WinRateSummary] {
        BalanceIdentityMargins.margin(
            records: records,
            ids: ids,
            peerRate: peerRate,
            threshold: threshold,
            positiveFlag: "EASY",
            negativeFlag: "HARD",
        )
    }

    private static func ownerIDPairs(
        _ record: BalanceBattleRecord,
        heroIDs: [String],
        companionIDs: [String],
    ) -> [(String, String)] {
        heroIDs.map { (record.heroID, $0) } + companionIDs.map { (record.companionID, $0) }
    }

    private static func targetBand(
        isBoss: Bool,
        tier: SimulationPowerTier,
    ) -> (lower: Double, upper: Double) {
        if isBoss {
            return (0.70, 0.80)
        }
        switch tier {
        case .early: return (0.90, 0.99)
        case .middle: return (0.80, 0.90)
        case .lateGame: return (0.70, 0.80)
        }
    }
}
