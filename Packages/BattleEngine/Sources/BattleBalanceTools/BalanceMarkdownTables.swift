import BattleEngine
import Foundation

enum BalanceMarkdownTables {
    static func appendIdentityTier(
        _ tierStats: BalanceTierStats,
        compared: BalanceTierStats?,
        into lines: inout [String],
    ) {
        lines.append("## \(tierStats.tier.displayName)")
        lines.append("")
        let winPct = tierStats.decidedBattles == 0
            ? 0
            : 100.0 * Double(tierStats.wins) / Double(tierStats.decidedBattles)
        var summary = String(
            format: "Battles: %d · Decided: %d · Wins: %d (%.1f%%) · Timeouts: %d · Avg rounds: %.1f · Avg party HP on win: %.0f%% · Avg enemy HP on loss: %.0f%%",
            tierStats.battles,
            tierStats.decidedBattles,
            tierStats.wins,
            winPct,
            tierStats.timeouts,
            tierStats.averageRounds,
            tierStats.averagePartyHPOnWin * 100,
            tierStats.averageEnemyHPOnLoss * 100,
        )
        if let compared {
            let comparedPct = compared.decidedBattles == 0
                ? 0
                : 100.0 * Double(compared.wins) / Double(compared.decidedBattles)
            summary += String(format: " · Compare win%%: %.1f%%", comparedPct)
        }
        lines.append(summary)
        lines.append("")
        appendDurationSection(tierStats, into: &lines)
        appendSection(title: "Heroes", summaries: tierStats.heroes, into: &lines)
        appendSection(title: "Heroes vs trash", summaries: tierStats.heroesTrash, into: &lines)
        appendSection(title: "Heroes vs bosses", summaries: tierStats.heroesBoss, into: &lines)
        appendSection(title: "Companions", summaries: tierStats.companions, into: &lines)
        appendSection(title: "Companions vs trash", summaries: tierStats.companionsTrash, into: &lines)
        appendSection(title: "Companions vs bosses", summaries: tierStats.companionsBoss, into: &lines)
        appendSection(title: "Enemies", summaries: tierStats.enemies, into: &lines)
        appendSection(
            title: "Party Abilities (within owner)",
            summaries: tierStats.abilities,
            into: &lines,
            flaggedPlusTop: 25,
        )
        appendSection(
            title: "Talents (within owner)",
            summaries: tierStats.talents,
            into: &lines,
            flaggedPlusTop: 25,
        )
        appendSection(title: "Enemy Abilities", summaries: tierStats.enemyAbilities, into: &lines, flaggedPlusTop: 25)
        appendSection(title: "Enemy Traits", summaries: tierStats.enemyTraits, into: &lines)
        if tierStats.tier.includesGear {
            appendSection(
                title: "Item Affixes (within owner)",
                summaries: tierStats.affixes,
                into: &lines,
                flaggedPlusTop: 25,
            )
        }
        appendPairSection(title: "Hero × companion (flagged)", cells: tierStats.heroCompanionCells, into: &lines)
        appendPairSection(title: "Hero × enemy (flagged)", cells: tierStats.heroEnemyCells, into: &lines)
        appendEnemyDurationSection(tierStats.enemyDurations, into: &lines)
    }

    static func appendDurationSection(_ tierStats: BalanceTierStats, into lines: inout [String]) {
        lines.append("### Duration")
        lines.append("")
        lines.append(
            "| Bucket | Goal | n | SHORT% | LONG% | Avg rounds | "
                + "Avg when SHORT | Avg when LONG | Max rounds | Worst enemy | Flag |",
        )
        lines.append(
            "|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---|",
        )
        appendDurationRow(
            label: "trash",
            goalBand: BalanceDurationThresholds.trashGoalBand,
            stats: tierStats.trashDuration,
            into: &lines,
        )
        appendDurationRow(
            label: "boss",
            goalBand: BalanceDurationThresholds.bossGoalBand,
            stats: tierStats.bossDuration,
            into: &lines,
        )
        lines.append("")
    }

    static func appendDurationRow(
        label: String,
        goalBand: String,
        stats: BalanceDurationBucketStats,
        into lines: inout [String],
    ) {
        let flag = stats.flagged ? "⚠ \(stats.flagReason ?? "")" : ""
        let worst = stats.worstEnemyID.map { "`\($0)`" } ?? "-"
        lines.append(String(
            format: "| %@ | %@ | %d | %.1f%% | %.1f%% | %.1f | %.1f | %.1f | %d | %@ | %@ |",
            label,
            goalBand,
            stats.battles,
            stats.shortRate * 100,
            stats.longRate * 100,
            stats.averageRounds,
            stats.averageRoundsWhenShort,
            stats.averageRoundsWhenLong,
            stats.maxRounds,
            worst,
            flag,
        ))
    }

    static func appendEnemyDurationSection(
        _ stats: [BalanceEnemyDurationStats],
        into lines: inout [String],
    ) {
        guard !stats.isEmpty else { return }
        lines.append("### Enemy duration")
        lines.append("")
        lines.append("| Enemy | n | Avg rounds | SHORT% | LONG% |")
        lines.append("|---|---:|---:|---:|---:|")
        for row in stats {
            lines.append(String(
                format: "| `%@` | %d | %.1f | %.1f%% | %.1f%% |",
                row.enemyID,
                row.battles,
                row.averageRounds,
                row.shortRate * 100,
                row.longRate * 100,
            ))
        }
        lines.append("")
    }

    static func appendContrasts(
        title: String,
        summaries: [PairedContrastSummary],
        into lines: inout [String],
    ) {
        lines.append("## \(title)")
        lines.append("")
        lines.append(
            "| Entity | Baseline | Kind | Owner | Tier | Entity% | Baseline% | Lift | ΔHP | Δrounds | n | decided | Flag |",
        )
        lines.append("|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|")
        let flagged = summaries.filter(\.flagged)
        let rest = summaries.filter { !$0.flagged }
        let rows = flagged + Array(rest.prefix(max(0, 40 - flagged.count)))
        for row in rows {
            let flag = row.flagReason.map { row.flagged ? "⚠ \($0)" : $0 } ?? ""
            lines.append(String(
                format: "| `%@` | `%@` | %@ | `%@` | %@ | %.1f%% | %.1f%% | %+.1f pp | %+.2f | %+.1f | %d | %d | %@ |",
                row.entityID,
                row.baselineID,
                row.baselineKind.rawValue,
                row.ownerID,
                row.tier.displayName,
                row.entityWinRate * 100,
                row.baselineWinRate * 100,
                row.lift * 100,
                row.meanDeltaPartyHP,
                row.meanDeltaRounds,
                row.pairs,
                row.decidedPairs,
                flag,
            ))
        }
        lines.append("")
    }

    static func appendSection(
        title: String,
        summaries: [WinRateSummary],
        into lines: inout [String],
        flaggedPlusTop: Int? = nil,
    ) {
        guard !summaries.isEmpty else { return }
        lines.append("### \(title)")
        lines.append("")
        lines.append("| ID | Owner | Win% | Wilson 95% | n | Δ peer | Flag |")
        lines.append("|---|---|---:|---|---:|---:|---|")
        let rows: [WinRateSummary]
        if let flaggedPlusTop {
            let flagged = summaries.filter(\.flagged)
            let rest = summaries.filter { !$0.flagged && !$0.sampleTooLow }
            rows = flagged + Array(rest.prefix(flaggedPlusTop))
        } else {
            rows = summaries.filter { !$0.sampleTooLow || $0.flagged }
        }
        for row in rows {
            let flag = row.flagged ? "⚠ \(row.flagReason ?? "")" : ""
            let owner = row.ownerID.map { "`\($0)`" } ?? "-"
            lines.append(String(
                format: "| `%@` | %@ | %.1f%% | [%.1f–%.1f] | %d | %+.1f pp | %@ |",
                row.id,
                owner,
                row.winRate * 100,
                row.wilsonLow * 100,
                row.wilsonHigh * 100,
                row.battles,
                row.deltaVsPeer * 100,
                flag,
            ))
        }
        lines.append("")
    }

    static func appendPairSection(
        title: String,
        cells: [PairCellSummary],
        into lines: inout [String],
    ) {
        guard !cells.isEmpty else { return }
        lines.append("### \(title)")
        lines.append("")
        lines.append("| Left | Right | Win% | n | Δ peer | Flag |")
        lines.append("|---|---|---:|---:|---:|---|")
        for row in cells {
            lines.append(String(
                format: "| `%@` | `%@` | %.1f%% | %d | %+.1f pp | ⚠ %@ |",
                row.leftID,
                row.rightID,
                row.winRate * 100,
                row.battles,
                row.deltaVsPeer * 100,
                row.flagReason ?? "",
            ))
        }
        lines.append("")
    }

    static func appendUnderNAppendix(
        tiers: [BalanceTierStats],
        report: BalanceSweepReport,
        into lines: inout [String],
    ) {
        var identityLow: [WinRateSummary] = []
        for tier in tiers {
            identityLow.append(contentsOf: tier.heroes)
            identityLow.append(contentsOf: tier.companions)
            identityLow.append(contentsOf: tier.enemies)
            identityLow.append(contentsOf: tier.abilities)
            identityLow.append(contentsOf: tier.talents)
            identityLow.append(contentsOf: tier.affixes)
        }
        identityLow = identityLow.filter(\.sampleTooLow)
        var contrastLow = report.abilityContrasts
        contrastLow.append(contentsOf: report.affixContrasts)
        contrastLow.append(contentsOf: report.talentContrasts)
        contrastLow.append(contentsOf: report.talentKitContrasts)
        contrastLow = contrastLow.filter {
            $0.decidedPairs < BalanceSweepConfig.contrastFlagMinPairs && !$0.nonCombat
        }
        guard !identityLow.isEmpty || !contrastLow.isEmpty else { return }
        lines.append("## n too low to flag")
        lines.append("")
        if !identityLow.isEmpty {
            lines.append("| ID | Owner | n |")
            lines.append("|---|---|---:|")
            for row in identityLow.prefix(40) {
                let owner = row.ownerID.map { "`\($0)`" } ?? "-"
                lines.append("| `\(row.id)` | \(owner) | \(row.battles) |")
            }
            lines.append("")
        }
        if !contrastLow.isEmpty {
            lines.append("| Entity | Owner | decided |")
            lines.append("|---|---|---:|")
            for row in contrastLow.prefix(40) {
                lines.append("| `\(row.entityID)` | `\(row.ownerID)` | \(row.decidedPairs) |")
            }
            lines.append("")
        }
    }
}
