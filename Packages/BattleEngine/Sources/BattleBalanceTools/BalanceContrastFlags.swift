import BattleEngine
import Foundation

enum BalanceContrastFlags {
    struct Identity: Hashable {
        let tier: SimulationPowerTier
        let entityID: String
        let baselineID: String
        let ownerID: String
        let baselineKind: ContrastBaselineKind
    }

    struct ContrastAcc {
        let entityID: String
        let baselineID: String
        let ownerID: String
        let tier: SimulationPowerTier
        let baselineKind: ContrastBaselineKind
        let nonCombat: Bool
        var pairs = 0
        var decidedPairs = 0
        var winsWithEntity = 0
        var winsWithBaseline = 0
        var entityOnlyWins = 0
        var baselineOnlyWins = 0
        var entityTimeouts = 0
        var baselineTimeouts = 0
        var deltaPartyHP = 0.0
        var deltaRounds = 0.0

        var identity: Identity {
            Identity(tier: tier, entityID: entityID, baselineID: baselineID, ownerID: ownerID, baselineKind: baselineKind)
        }

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
            deltaRounds += row.meanDeltaRounds * n
        }
    }

    static func makeSummary(_ acc: ContrastAcc, config: BalanceSweepConfig) -> PairedContrastSummary {
        let entityRate = acc.decidedPairs == 0 ? 0 : Double(acc.winsWithEntity) / Double(acc.decidedPairs)
        let baselineRate = acc.decidedPairs == 0 ? 0 : Double(acc.winsWithBaseline) / Double(acc.decidedPairs)
        let lift = entityRate - baselineRate
        let decidedCount = Double(max(acc.decidedPairs, 1))
        let meanDeltaPartyHP = acc.deltaPartyHP / decidedCount
        let meanDeltaRounds = acc.deltaRounds / decidedCount
        let tags = flagTags(acc, config: config, lift: lift, partyHP: meanDeltaPartyHP, rounds: meanDeltaRounds)
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
            meanDeltaPartyHP: meanDeltaPartyHP,
            meanDeltaRounds: meanDeltaRounds,
            flagged: !tags.isEmpty && !acc.nonCombat,
            flagReason: tags.isEmpty ? nil : tags.joined(separator: ", "),
            nonCombat: acc.nonCombat,
        )
    }

    private static func flagTags(
        _ acc: ContrastAcc,
        config: BalanceSweepConfig,
        lift: Double,
        partyHP: Double,
        rounds: Double,
    ) -> [String] {
        if acc.nonCombat {
            return ["NONCOMBAT"]
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
        if acc.decidedPairs >= BalanceSweepConfig.contrastFlagMinPairs {
            if abs(lift) >= config.peerDeltaFlagThreshold, acc.entityOnlyWins + acc.baselineOnlyWins >= 4 {
                tags.append(lift > 0 ? "HIGH" : "LOW")
            }
            if abs(partyHP) >= config.comfortHPThreshold {
                tags.append(partyHP > 0 ? "SAFER" : "GLASS")
            }
            if abs(rounds) >= config.comfortRoundThreshold {
                tags.append(rounds < 0 ? "FASTER" : "SLOWER")
            }
        }
        return tags
    }

    static func summarySort(_ lhs: PairedContrastSummary, _ rhs: PairedContrastSummary) -> Bool {
        if lhs.flagged != rhs.flagged {
            return lhs.flagged && !rhs.flagged
        }
        if abs(lhs.lift) != abs(rhs.lift) {
            return abs(lhs.lift) > abs(rhs.lift)
        }
        return (lhs.tier.rawValue, lhs.entityID, lhs.baselineID, lhs.ownerID, lhs.baselineKind.rawValue)
            < (rhs.tier.rawValue, rhs.entityID, rhs.baselineID, rhs.ownerID, rhs.baselineKind.rawValue)
    }
}
