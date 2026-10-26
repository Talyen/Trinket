import BattleEngine
import Foundation

enum BalanceMarkdownTables {
    static func identityTier(
        _ tierStats: BalanceTierStats,
        compared: BalanceTierStats?,
    ) -> [String] {
        var lines = ["## \(tierStats.tier.displayName)"]
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
        lines += durationSection(tierStats)
        lines += rosterSections(tierStats)
        for (title, summaries, limit) in [
            ("Party Abilities (within owner)", tierStats.abilities, 25),
            ("Talents (within owner)", tierStats.talents, 25),
            ("Enemy Abilities", tierStats.enemyAbilities, 25),
            ("Enemy Traits", tierStats.enemyTraits, nil),
        ] as [(String, [WinRateSummary], Int?)] {
            lines += section(title: title, summaries: summaries, flaggedPlusTop: limit)
        }
        lines += section(title: "Item Bases (within owner)", summaries: tierStats.items, flaggedPlusTop: 25)
        lines += section(title: "Item Affixes (within owner)", summaries: tierStats.affixes, flaggedPlusTop: 25)
        for (title, cells) in [
            ("Hero × companion (flagged)", tierStats.heroCompanionCells),
            ("Hero × enemy (flagged)", tierStats.heroEnemyCells),
        ] {
            lines += pairSection(title: title, cells: cells)
        }
        return lines + enemyDurationSection(tierStats.enemyDurations)
    }

    private static func rosterSections(_ tierStats: BalanceTierStats) -> [String] {
        var lines: [String] = []
        for (title, rows) in [
            ("Heroes", tierStats.heroes),
            ("Heroes vs trash", tierStats.heroesTrash),
            ("Heroes vs bosses", tierStats.heroesBoss),
            ("Companions", tierStats.companions),
            ("Companions vs trash", tierStats.companionsTrash),
            ("Companions vs bosses", tierStats.companionsBoss),
            ("Enemies", tierStats.enemies),
        ] {
            lines += section(title: title, summaries: rows)
        }
        return lines
    }

    private static func table(heading: String? = nil, header: String, separator: String, rows: [String]) -> [String] {
        (heading.map { [$0, ""] } ?? []) + [header, separator] + rows + [""]
    }

    private static func durationSection(_ tierStats: BalanceTierStats) -> [String] {
        table(
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

    private static func enemyDurationSection(
        _ stats: [BalanceEnemyDurationStats],
    ) -> [String] {
        guard !stats.isEmpty else { return [] }
        return table(
            heading: "### Enemy duration",
            header: "| Enemy | Role | n | Avg rounds | SHORT% | LONG% |",
            separator: "|---|---|---:|---:|---:|---:|",
            rows: stats.map { row in
                """
                | `\(row.enemyID)` | \(row.isBoss ? "boss" : "regular") | \(row.battles) | \(decimal(row.averageRounds)) | \
                \(decimal(row.shortRate * 100))% | \(decimal(row.longRate * 100))% |
                """
            },
        )
    }

    static func contrasts(
        title: String,
        summaries: [PairedContrastSummary],
    ) -> [String] {
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
        return table(
            heading: "## \(title)",
            header: "| Entity | Baseline | Kind | Owner | Tier | Entity% | Baseline% | Lift | ΔHP | Δrounds | n | decided | Flag |",
            separator: "|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|",
            rows: rows,
        )
    }

    private static func section(
        title: String,
        summaries: [WinRateSummary],
        flaggedPlusTop: Int? = nil,
    ) -> [String] {
        guard !summaries.isEmpty else { return [] }
        let rows: [WinRateSummary]
        if let flaggedPlusTop {
            let flagged = summaries.filter(\.flagged)
            rows = flagged + Array(summaries.filter { !$0.flagged && !$0.sampleTooLow }.prefix(flaggedPlusTop))
        } else {
            rows = summaries.filter { !$0.sampleTooLow || $0.flagged }
        }
        return table(
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

    private static func pairSection(
        title: String,
        cells: [PairCellSummary],
    ) -> [String] {
        guard !cells.isEmpty else { return [] }
        return table(
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

    static func underNAppendix(
        tiers: [BalanceTierStats],
        report: BalanceSweepReport,
    ) -> [String] {
        let identityLow = tiers.flatMap { tier in
            [tier.heroes, tier.companions, tier.enemies, tier.items, tier.abilities,
             tier.talents, tier.enemyAbilities, tier.enemyTraits, tier.affixes].joined().filter(\.sampleTooLow)
        }
        let contrastLow = report.contrastSections.flatMap(\.rows)
            .filter { $0.decidedPairs < BalanceSweepConfig.contrastFlagMinPairs && !$0.nonCombat }
        guard !identityLow.isEmpty || !contrastLow.isEmpty else { return [] }
        var lines = ["## n too low to flag", ""]
        if !identityLow.isEmpty {
            lines += table(
                header: "| ID | Owner | n |",
                separator: "|---|---|---:|",
                rows: identityLow.prefix(40).map { row in
                    let owner = row.ownerID.map { "`\($0)`" } ?? "-"
                    return "| `\(row.id)` | \(owner) | \(row.battles) |"
                },
            )
        }
        if !contrastLow.isEmpty {
            lines += table(
                header: "| Entity | Owner | decided |",
                separator: "|---|---|---:|",
                rows: contrastLow.prefix(40).map { "| `\($0.entityID)` | `\($0.ownerID)` | \($0.decidedPairs) |" },
            )
        }
        return lines
    }
}
