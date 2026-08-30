import BattleEngine
import Foundation

struct IdentityTierInputs {
    var tier: SimulationPowerTier
    var records: [BalanceBattleRecord]
    var decided: [BalanceBattleRecord]
    var config: BalanceSweepConfig
    var overallRate: Double
    var winCount: Int
    var lossCount: Int
    var timeoutCount: Int
    var totalRoundsSum: Double
    var partyHPWinSum: Double
    var enemyHPLossSum: Double
    var heroOverall: [WinRateSummary]
    var companionOverall: [WinRateSummary]
    var heroRates: [String: Double]
    var companionRates: [String: Double]
}

enum BalanceIdentityTables {
    static func assemble(_ inputs: IdentityTierInputs) -> BalanceTierStats {
        makeTierStats(
            inputs: inputs,
            ownerRates: inputs.heroRates.merging(inputs.companionRates) { lhs, _ in lhs },
            threshold: inputs.config.peerDeltaFlagThreshold,
        )
    }

    private static func makeTierStats(
        inputs: IdentityTierInputs,
        ownerRates: [String: Double],
        threshold: Double,
    ) -> BalanceTierStats {
        let decided = inputs.decided
        let records = inputs.records
        let overallRate = inputs.overallRate
        let duration = durationBundle(records: records, flagRate: inputs.config.durationFlagRate)
        let entities = entityBundle(
            decided: decided,
            ownerRates: ownerRates,
            overallRate: overallRate,
            threshold: threshold,
        )
        return BalanceTierStats(
            tier: inputs.tier,
            battles: records.count,
            decidedBattles: decided.count,
            wins: inputs.winCount,
            timeouts: inputs.timeoutCount,
            averageRounds: records.isEmpty ? 0 : inputs.totalRoundsSum / Double(records.count),
            averagePartyHPOnWin: inputs.winCount == 0 ? 0 : inputs.partyHPWinSum / Double(inputs.winCount),
            averageEnemyHPOnLoss: inputs.lossCount == 0 ? 0 : inputs.enemyHPLossSum / Double(inputs.lossCount),
            trashDuration: duration.trash,
            bossDuration: duration.boss,
            enemyDurations: duration.enemies,
            heroes: inputs.heroOverall,
            heroesTrash: BalanceIdentityMargins.ownerMargins(
                records: decided.filter { !$0.isBoss },
                id: \.heroID,
                peerRate: overallRate,
                threshold: threshold,
            ),
            heroesBoss: BalanceIdentityMargins.ownerMargins(
                records: decided.filter(\.isBoss),
                id: \.heroID,
                peerRate: overallRate,
                threshold: threshold,
            ),
            companions: inputs.companionOverall,
            companionsTrash: BalanceIdentityMargins.ownerMargins(
                records: decided.filter { !$0.isBoss },
                id: \.companionID,
                peerRate: overallRate,
                threshold: threshold,
            ),
            companionsBoss: BalanceIdentityMargins.ownerMargins(
                records: decided.filter(\.isBoss),
                id: \.companionID,
                peerRate: overallRate,
                threshold: threshold,
            ),
            enemies: entities.enemies,
            abilities: entities.abilities,
            talents: entities.talents,
            enemyAbilities: entities.enemyAbilities,
            enemyTraits: entities.enemyTraits,
            affixes: entities.affixes,
            heroCompanionCells: entities.heroCompanionCells,
            heroEnemyCells: entities.heroEnemyCells,
        )
    }

    private struct DurationBundle {
        var trash: BalanceDurationBucketStats
        var boss: BalanceDurationBucketStats
        var enemies: [BalanceEnemyDurationStats]
    }

    private static func durationBundle(
        records: [BalanceBattleRecord],
        flagRate: Double,
    ) -> DurationBundle {
        DurationBundle(
            trash: BalanceDurationAggregation.durationStats(
                records.filter { !$0.isBoss },
                minRounds: BalanceDurationThresholds.trashMinRounds,
                maxRounds: BalanceDurationThresholds.trashMaxRounds,
                flagRate: flagRate,
            ),
            boss: BalanceDurationAggregation.durationStats(
                records.filter(\.isBoss),
                minRounds: BalanceDurationThresholds.bossMinRounds,
                maxRounds: BalanceDurationThresholds.bossMaxRounds,
                flagRate: flagRate,
            ),
            enemies: BalanceDurationAggregation.enemyDurationTable(records, flagRate: flagRate),
        )
    }

    private struct EntityBundle {
        var enemies: [WinRateSummary]
        var abilities: [WinRateSummary]
        var talents: [WinRateSummary]
        var enemyAbilities: [WinRateSummary]
        var enemyTraits: [WinRateSummary]
        var affixes: [WinRateSummary]
        var heroCompanionCells: [PairCellSummary]
        var heroEnemyCells: [PairCellSummary]
    }

    private static func entityBundle(
        decided: [BalanceBattleRecord],
        ownerRates: [String: Double],
        overallRate: Double,
        threshold: Double,
    ) -> EntityBundle {
        EntityBundle(
            enemies: enemyMargins(records: decided),
            abilities: partyPresenceMargins(
                records: decided,
                ownerRates: ownerRates,
                threshold: threshold,
            ) { record in
                record.heroAbilityIDs.map { (record.heroID, $0) }
                    + record.companionAbilityIDs.map { (record.companionID, $0) }
            },
            talents: partyPresenceMargins(
                records: decided,
                ownerRates: ownerRates,
                threshold: threshold,
            ) { record in
                record.heroTalentIDs.map { (record.heroID, $0) }
                    + record.companionTalentIDs.map { (record.companionID, $0) }
            },
            enemyAbilities: opponentMargins(
                records: decided,
                ids: \.enemyAbilityIDs,
                peerRate: overallRate,
                threshold: threshold,
            ),
            enemyTraits: opponentMargins(
                records: decided,
                ids: { [$0.enemyTraitID] },
                peerRate: overallRate,
                threshold: threshold,
            ),
            affixes: partyPresenceMargins(
                records: decided,
                ownerRates: ownerRates,
                threshold: threshold,
            ) { record in
                record.heroAffixIDs.map { (record.heroID, $0) }
                    + record.companionAffixIDs.map { (record.companionID, $0) }
            },
            heroCompanionCells: BalanceIdentityMargins.flaggedPairCells(
                records: decided,
                left: \.heroID,
                right: \.companionID,
                peerRate: overallRate,
                threshold: threshold,
            ),
            heroEnemyCells: BalanceIdentityMargins.flaggedPairCells(
                records: decided,
                left: \.heroID,
                right: \.enemyID,
                peerRate: overallRate,
                threshold: threshold,
            ),
        )
    }

    private static func partyPresenceMargins(
        records: [BalanceBattleRecord],
        ownerRates: [String: Double],
        threshold: Double,
        ownerAndIDs: (BalanceBattleRecord) -> [(String, String)],
    ) -> [WinRateSummary] {
        BalanceIdentityMargins.withinOwnerMargins(
            records: records,
            ownerAndIDs: ownerAndIDs,
            ownerRates: ownerRates,
            threshold: threshold,
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

    private static func enemyMargins(
        records: [BalanceBattleRecord],
    ) -> [WinRateSummary] {
        var buckets: [String: (wins: Int, battles: Int, boss: Bool)] = [:]
        for record in records {
            var bucket = buckets[record.enemyID] ?? (0, 0, record.isBoss)
            bucket.battles += 1
            if record.result.isVictory {
                bucket.wins += 1
            }
            bucket.boss = record.isBoss
            buckets[record.enemyID] = bucket
        }

        return buckets.sorted { $0.key < $1.key }.map { id, bucket in
            let rate = bucket.battles == 0 ? 0 : Double(bucket.wins) / Double(bucket.battles)
            let ci = BalanceStatsAggregator.wilson(wins: bucket.wins, battles: bucket.battles)
            let band = targetBand(isBoss: bucket.boss, tier: records.first?.tier ?? .early)
            let inBand = rate >= band.lower && rate <= band.upper
            let sampleTooLow = bucket.battles < BalanceSweepConfig.identityFlagMinBattles
            let flagged = !inBand && !sampleTooLow
            let reason: String? = if flagged {
                rate > band.upper ? "EASY" : "HARD"
            } else {
                nil
            }
            return WinRateSummary(
                id: id,
                ownerID: nil,
                wins: bucket.wins,
                battles: bucket.battles,
                winRate: rate,
                wilsonLow: ci.low,
                wilsonHigh: ci.high,
                deltaVsPeer: rate - ((band.lower + band.upper) / 2),
                flagged: flagged,
                flagReason: reason,
                sampleTooLow: sampleTooLow,
            )
        }
        .sorted { lhs, rhs in
            if lhs.flagged != rhs.flagged {
                return lhs.flagged && !rhs.flagged
            }
            return lhs.id < rhs.id
        }
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
