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
        let winPct = BalanceStatsAggregator.winPercent(wins: tierStats.wins, decided: tierStats.decidedBattles)
        var summary = """
        Battles: \(tierStats.battles) · Decided: \(tierStats.decidedBattles) · Wins: \(tierStats.wins) (\(decimal(winPct))%) · \
        Timeouts: \(tierStats.timeouts) · Avg rounds: \(decimal(tierStats.averageRounds)) · \
        Avg party HP on win: \(decimal(tierStats.averagePartyHPOnWin * 100, "%.0f"))% · \
        Avg enemy HP on loss: \(decimal(tierStats.averageEnemyHPOnLoss * 100, "%.0f"))%
        """
        if let compared {
            let comparedPct = BalanceStatsAggregator.winPercent(wins: compared.wins, decided: compared.decidedBattles)
            summary += " · Compare win%: \(decimal(comparedPct))%"
        }
        lines.append(summary)
        lines.append("")
        appendDurationSection(tierStats, into: &lines)
        appendRosterSections(tierStats, into: &lines)
        for (title, summaries, limit) in [
            ("Party Abilities (within owner)", tierStats.abilities, 25),
            ("Talents (within owner)", tierStats.talents, 25),
            ("Enemy Abilities", tierStats.enemyAbilities, 25),
            ("Enemy Traits", tierStats.enemyTraits, nil),
        ] as [(String, [WinRateSummary], Int?)] {
            appendSection(title: title, summaries: summaries, into: &lines, flaggedPlusTop: limit)
        }
        if tierStats.tier.includesGear {
            appendSection(title: "Item Bases (within owner)", summaries: tierStats.items, into: &lines, flaggedPlusTop: 25)
            appendSection(title: "Item Affixes (within owner)", summaries: tierStats.affixes, into: &lines, flaggedPlusTop: 25)
        }
        for (title, cells) in [
            ("Hero × companion (flagged)", tierStats.heroCompanionCells),
            ("Hero × enemy (flagged)", tierStats.heroEnemyCells),
        ] {
            appendPairSection(title: title, cells: cells, into: &lines)
        }
        appendEnemyDurationSection(tierStats.enemyDurations, into: &lines)
    }

    private static func appendRosterSections(_ tierStats: BalanceTierStats, into lines: inout [String]) {
        for (title, rows) in [
            ("Heroes", tierStats.heroes),
            ("Heroes vs trash", tierStats.heroesTrash),
            ("Heroes vs bosses", tierStats.heroesBoss),
            ("Companions", tierStats.companions),
            ("Companions vs trash", tierStats.companionsTrash),
            ("Companions vs bosses", tierStats.companionsBoss),
            ("Enemies", tierStats.enemies),
        ] {
            appendSection(title: title, summaries: rows, into: &lines)
        }
    }

    private static func table(into lines: inout [String], heading: String, header: String, separator: String, rows: [String]) {
        lines.append(heading)
        lines.append("")
        rowsTable(into: &lines, header: header, separator: separator, rows: rows)
    }

    static func appendDurationSection(_ tierStats: BalanceTierStats, into lines: inout [String]) {
        table(
            into: &lines,
            heading: "### Duration",
            header: "| Bucket | Goal | n | SHORT% | LONG% | Avg rounds | Avg when SHORT | Avg when LONG | Max rounds | Worst enemy | Flag |",
            separator: "|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---|",
            rows: [
                durationRow(label: "trash", goalBand: BalanceDurationThresholds.trashGoalBand, stats: tierStats.trashDuration),
                durationRow(label: "boss", goalBand: BalanceDurationThresholds.bossGoalBand, stats: tierStats.bossDuration),
            ],
        )
    }

    private static func durationRow(label: String, goalBand: String, stats: BalanceDurationBucketStats) -> String {
        let flag = stats.flagged ? "⚠ \(stats.flagReason ?? "")" : ""
        let worst = stats.worstEnemyID.map { "`\($0)`" } ?? "-"
        return """
        | \(label) | \(goalBand) | \(stats.battles) | \(decimal(stats.shortRate * 100))% | \(decimal(stats.longRate * 100))% | \
        \(decimal(stats.averageRounds)) | \(decimal(stats.averageRoundsWhenShort)) | \(decimal(stats.averageRoundsWhenLong)) | \
        \(stats.maxRounds) | \(worst) | \(flag) |
        """
    }

    static func appendEnemyDurationSection(
        _ stats: [BalanceEnemyDurationStats],
        into lines: inout [String],
    ) {
        guard !stats.isEmpty else { return }
        table(
            into: &lines,
            heading: "### Enemy duration",
            header: "| Enemy | n | Avg rounds | SHORT% | LONG% |",
            separator: "|---|---:|---:|---:|---:|",
            rows: stats.map { row in
                """
                | `\(row.enemyID)` | \(row.battles) | \(decimal(row.averageRounds)) | \
                \(decimal(row.shortRate * 100))% | \(decimal(row.longRate * 100))% |
                """
            },
        )
    }

    static func appendContrasts(
        title: String,
        summaries: [PairedContrastSummary],
        into lines: inout [String],
    ) {
        let flagged = summaries.filter(\.flagged)
        let rest = summaries.filter { !$0.flagged }
        let rows = (flagged + Array(rest.prefix(max(0, 40 - flagged.count)))).map { row in
            let flag = row.flagReason.map { row.flagged ? "⚠ \($0)" : $0 } ?? ""
            return """
            | `\(row.entityID)` | `\(row.baselineID)` | \(row.baselineKind.rawValue) | `\(row.ownerID)` | \(row.tier.displayName) | \
            \(decimal(row.entityWinRate * 100))% | \(decimal(row.baselineWinRate * 100))% | \(decimal(row.lift * 100, "%+.1f")) pp | \
            \(decimal(row.meanDeltaPartyHP, "%+.2f")) | \(decimal(row.meanDeltaRounds, "%+.1f")) | \
            \(row.pairs) | \(row.decidedPairs) | \(flag) |
            """
        }
        table(
            into: &lines,
            heading: "## \(title)",
            header: "| Entity | Baseline | Kind | Owner | Tier | Entity% | Baseline% | Lift | ΔHP | Δrounds | n | decided | Flag |",
            separator: "|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|",
            rows: rows,
        )
    }

    static func appendSection(
        title: String,
        summaries: [WinRateSummary],
        into lines: inout [String],
        flaggedPlusTop: Int? = nil,
    ) {
        guard !summaries.isEmpty else { return }
        let rows: [WinRateSummary]
        if let flaggedPlusTop {
            let flagged = summaries.filter(\.flagged)
            rows = flagged + Array(summaries.filter { !$0.flagged && !$0.sampleTooLow }.prefix(flaggedPlusTop))
        } else {
            rows = summaries.filter { !$0.sampleTooLow || $0.flagged }
        }
        table(
            into: &lines,
            heading: "### \(title)",
            header: "| ID | Owner | Win% | Wilson 95% | n | Δ peer | Flag |",
            separator: "|---|---|---:|---|---:|---:|---|",
            rows: rows.map { row in
                let flag = row.flagged ? "⚠ \(row.flagReason ?? "")" : ""
                let owner = row.ownerID.map { "`\($0)`" } ?? "-"
                return """
                | `\(row.id)` | \(owner) | \(decimal(row.winRate * 100))% | \
                [\(decimal(row.wilsonLow * 100))–\(decimal(row.wilsonHigh * 100))] | \(row.battles) | \
                \(decimal(row.deltaVsPeer * 100, "%+.1f")) pp | \(flag) |
                """
            },
        )
    }

    static func appendPairSection(
        title: String,
        cells: [PairCellSummary],
        into lines: inout [String],
    ) {
        guard !cells.isEmpty else { return }
        table(
            into: &lines,
            heading: "### \(title)",
            header: "| Left | Right | Win% | n | Δ peer | Flag |",
            separator: "|---|---|---:|---:|---:|---|",
            rows: cells.map { row in
                """
                | `\(row.leftID)` | `\(row.rightID)` | \(decimal(row.winRate * 100))% | \(row.battles) | \
                \(decimal(row.deltaVsPeer * 100, "%+.1f")) pp | ⚠ \(row.flagReason ?? "") |
                """
            },
        )
    }

    private static func decimal(_ value: Double, _ format: String = "%.1f") -> String {
        String(format: format, value)
    }

    private static func rowsTable(into lines: inout [String], header: String, separator: String, rows: [String]) {
        lines.append(header)
        lines.append(separator)
        lines.append(contentsOf: rows)
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
        let contrastLow = report.contrastSections.flatMap(\.rows)
            .filter { $0.decidedPairs < BalanceSweepConfig.contrastFlagMinPairs && !$0.nonCombat }
        guard !identityLow.isEmpty || !contrastLow.isEmpty else { return }
        lines.append("## n too low to flag")
        lines.append("")
        if !identityLow.isEmpty {
            rowsTable(
                into: &lines,
                header: "| ID | Owner | n |",
                separator: "|---|---|---:|",
                rows: identityLow.prefix(40).map { row in
                    let owner = row.ownerID.map { "`\($0)`" } ?? "-"
                    return "| `\(row.id)` | \(owner) | \(row.battles) |"
                },
            )
        }
        if !contrastLow.isEmpty {
            rowsTable(
                into: &lines,
                header: "| Entity | Owner | decided |",
                separator: "|---|---|---:|",
                rows: contrastLow.prefix(40).map { "| `\($0.entityID)` | `\($0.ownerID)` | \($0.decidedPairs) |" },
            )
        }
    }
}
