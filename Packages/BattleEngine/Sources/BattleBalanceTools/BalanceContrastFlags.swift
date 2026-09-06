import BattleEngine
import Foundation

enum BalanceContrastFlags {
    struct ContrastAcc {
        var entityID: String
        var baselineID: String
        var ownerID: String
        var tier: SimulationPowerTier
        var baselineKind: ContrastBaselineKind
        var nonCombat: Bool
        var pairs = 0
        var decidedPairs = 0
        var winsWithEntity = 0
        var winsWithBaseline = 0
        var entityOnlyWins = 0
        var baselineOnlyWins = 0
        var entityTimeouts = 0
        var baselineTimeouts = 0
        var deltaPartyHP = 0.0
        var deltaEnemyHP = 0.0
        var deltaRounds = 0.0

        mutating func accumulate(entity: BattleSimResult, baseline: BattleSimResult) {
            pairs += 1
            if entity.timedOut {
                entityTimeouts += 1
            }
            if baseline.timedOut {
                baselineTimeouts += 1
            }
            guard entity.isDecided, baseline.isDecided else { return }
            decidedPairs += 1
            deltaPartyHP += entity.partyHPRemainingFraction - baseline.partyHPRemainingFraction
            deltaEnemyHP += entity.enemyHPRemainingFraction - baseline.enemyHPRemainingFraction
            deltaRounds += Double(entity.rounds - baseline.rounds)
            let entityWon = entity.isVictory
            let baselineWon = baseline.isVictory
            if entityWon {
                winsWithEntity += 1
            }
            if baselineWon {
                winsWithBaseline += 1
            }
            if entityWon, !baselineWon {
                entityOnlyWins += 1
            }
            if baselineWon, !entityWon {
                baselineOnlyWins += 1
            }
        }

        mutating func merge(_ row: PairedContrastSummary) {
            let n = Double(row.decidedPairs)
            pairs += row.pairs
            decidedPairs += row.decidedPairs
            winsWithEntity += row.winsWithEntity
            winsWithBaseline += row.winsWithBaseline
            entityOnlyWins += row.entityOnlyWins
            baselineOnlyWins += row.baselineOnlyWins
            entityTimeouts += row.entityTimeouts
            baselineTimeouts += row.baselineTimeouts
            deltaPartyHP += row.meanDeltaPartyHP * n
            deltaEnemyHP += row.meanDeltaEnemyHP * n
            deltaRounds += row.meanDeltaRounds * n
        }
    }

    static func summaryKey(
        tier: SimulationPowerTier,
        entityID: String,
        baselineID: String,
        ownerID: String,
        baselineKind: ContrastBaselineKind,
    ) -> String {
        "\(tier.rawValue)|\(entityID)|\(baselineID)|\(ownerID)|\(baselineKind.rawValue)"
    }

    static func makeSummary(_ acc: ContrastAcc, config: BalanceSweepConfig) -> PairedContrastSummary {
        let entityRate = acc.decidedPairs == 0 ? 0 : Double(acc.winsWithEntity) / Double(acc.decidedPairs)
        let baselineRate = acc.decidedPairs == 0 ? 0 : Double(acc.winsWithBaseline) / Double(acc.decidedPairs)
        let lift = entityRate - baselineRate
        let decidedCount = Double(max(acc.decidedPairs, 1))
        let meanDeltaPartyHP = acc.deltaPartyHP / decidedCount
        let meanDeltaEnemyHP = acc.deltaEnemyHP / decidedCount
        let meanDeltaRounds = acc.deltaRounds / decidedCount
        let discordant = acc.entityOnlyWins + acc.baselineOnlyWins
        let wrFlag = !acc.nonCombat
            && acc.decidedPairs >= BalanceSweepConfig.contrastFlagMinPairs
            && abs(lift) >= config.peerDeltaFlagThreshold
            && discordant >= 4
        let comfortFlag = !acc.nonCombat
            && acc.decidedPairs >= BalanceSweepConfig.contrastFlagMinPairs
            && (
                abs(meanDeltaPartyHP) >= config.comfortHPThreshold
                    || abs(meanDeltaRounds) >= config.comfortRoundThreshold
            )
        let means = ContrastMeans(
            partyHP: acc.decidedPairs == 0 ? 0 : meanDeltaPartyHP,
            enemyHP: acc.decidedPairs == 0 ? 0 : meanDeltaEnemyHP,
            rounds: acc.decidedPairs == 0 ? 0 : meanDeltaRounds,
        )
        let flags = contrastFlags(
            acc: acc,
            config: config,
            lift: lift,
            means: means,
            wrFlag: wrFlag,
            comfortFlag: comfortFlag,
        )
        return PairedContrastSummary(
            entityID: acc.entityID,
            baselineID: acc.baselineID,
            ownerID: acc.ownerID,
            tier: acc.tier,
            baselineKind: acc.baselineKind,
            pairs: acc.pairs,
            decidedPairs: acc.decidedPairs,
            winsWithEntity: acc.winsWithEntity,
            winsWithBaseline: acc.winsWithBaseline,
            entityOnlyWins: acc.entityOnlyWins,
            baselineOnlyWins: acc.baselineOnlyWins,
            entityTimeouts: acc.entityTimeouts,
            baselineTimeouts: acc.baselineTimeouts,
            lift: lift,
            meanDeltaPartyHP: means.partyHP,
            meanDeltaEnemyHP: means.enemyHP,
            meanDeltaRounds: means.rounds,
            flagged: flags.flagged,
            flagReason: flags.reason,
            nonCombat: acc.nonCombat,
        )
    }

    private struct ContrastMeans {
        var partyHP: Double
        var enemyHP: Double
        var rounds: Double
    }

    private static func contrastFlags(
        acc: ContrastAcc,
        config: BalanceSweepConfig,
        lift: Double,
        means: ContrastMeans,
        wrFlag: Bool,
        comfortFlag: Bool,
    ) -> (flagged: Bool, reason: String?) {
        if acc.nonCombat {
            return (false, "NONCOMBAT")
        }
        var tags: [String] = []
        if acc.pairs >= BalanceSweepConfig.contrastFlagMinPairs {
            if Double(acc.entityTimeouts) / Double(acc.pairs) >= config.durationFlagRate {
                tags.append("ENTITY STALL")
            }
            if Double(acc.baselineTimeouts) / Double(acc.pairs) >= config.durationFlagRate {
                tags.append("BASELINE STALL")
            }
        }
        if wrFlag {
            tags.append(lift > 0 ? "HIGH" : "LOW")
        }
        if comfortFlag {
            if abs(means.partyHP) >= config.comfortHPThreshold {
                tags.append(means.partyHP > 0 ? "SAFER" : "GLASS")
            }
            if abs(means.rounds) >= config.comfortRoundThreshold {
                tags.append(means.rounds < 0 ? "FASTER" : "SLOWER")
            }
        }
        if tags.isEmpty {
            return (false, nil)
        }
        return (true, tags.joined(separator: ", "))
    }

    static func summarySort(_ lhs: PairedContrastSummary, _ rhs: PairedContrastSummary) -> Bool {
        if lhs.flagged != rhs.flagged {
            return lhs.flagged && !rhs.flagged
        }
        if abs(lhs.lift) != abs(rhs.lift) {
            return abs(lhs.lift) > abs(rhs.lift)
        }
        if lhs.tier.rawValue != rhs.tier.rawValue {
            return lhs.tier.rawValue < rhs.tier.rawValue
        }
        if lhs.entityID != rhs.entityID {
            return lhs.entityID < rhs.entityID
        }
        if lhs.baselineID != rhs.baselineID {
            return lhs.baselineID < rhs.baselineID
        }
        if lhs.ownerID != rhs.ownerID {
            return lhs.ownerID < rhs.ownerID
        }
        return lhs.baselineKind.rawValue < rhs.baselineKind.rawValue
    }
}
