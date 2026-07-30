import BattleEngine
import Foundation

public enum BalanceMarkdownReporter {
    public static func render(_ report: BalanceSweepReport) -> String {
        if report.config.mode == .modeProgression {
            return BalanceProgressionReportFormatter.render(
                config: report.config,
                hotspots: report.progressionHotspots,
                records: report.progressionRecords,
                playerStates: report.progressionPlayerStates,
                truncatedRuns: report.progressionTruncatedRuns,
                elapsedSeconds: report.elapsedSeconds
            )
        }
        return renderIdentityOrContrast(report)
    }

    private static func renderIdentityOrContrast(_ report: BalanceSweepReport) -> String {
        let tiers = BalanceStatsAggregator.summarize(report: report)
        var lines: [String] = []
        appendReportHeader(report, into: &lines)

        if !report.records.isEmpty {
            for tierStats in tiers where tierStats.battles > 0 {
                appendIdentityTier(tierStats, into: &lines)
            }
        }

        if !report.abilityContrasts.isEmpty {
            appendContrasts(
                title: "Ability Contrasts (paired lift vs sibling choice)",
                summaries: report.abilityContrasts,
                into: &lines
            )
        }

        if !report.affixContrasts.isEmpty {
            appendContrasts(
                title: "Affix Contrasts (paired lift vs same slot without affix)",
                summaries: report.affixContrasts,
                into: &lines
            )
        }

        appendReportNotes(policyID: report.policyID, into: &lines)
        return lines.joined(separator: "\n")
    }

    private static func appendReportHeader(_ report: BalanceSweepReport, into lines: inout [String]) {
        lines.append("# Balance Sweep Report")
        lines.append("")
        lines.append("- Mode: `\(report.config.mode.rawValue)`")
        lines.append("- Policy: `\(report.policyID)`")
        lines.append("- Seed: `\(report.config.seed)`")
        lines.append("- Battles per tier: `\(report.config.battlesPerTier)`")
        lines.append("- Jobs: `\(report.config.resolvedJobs)`")
        lines.append("- Tiers: \(report.config.tiers.map(\.rawValue).joined(separator: ", "))")
        lines.append("- Identity battles: `\(report.records.count)`")
        lines.append("- Ability contrast rows: `\(report.abilityContrasts.count)`")
        lines.append("- Affix contrast rows: `\(report.affixContrasts.count)`")
        lines.append(String(format: "- Elapsed: `%.2fs`", report.elapsedSeconds))
        if report.elapsedSeconds > 0, !report.records.isEmpty {
            lines.append(String(
                format: "- Identity throughput: `%.1f` battles/sec",
                Double(report.records.count) / report.elapsedSeconds
            ))
        }
        lines.append("- Peer Δ / lift flag threshold: `\(Int(report.config.peerDeltaFlagThreshold * 100)) pp`")
        lines.append(
            "- Duration goal bands: trash `\(BalanceDurationThresholds.trashGoalBand)` rounds, boss `\(BalanceDurationThresholds.bossGoalBand)` rounds (sim `turnCount` = player phase + enemy phase)."
        )
        lines.append("")
    }

    private static func appendReportNotes(policyID: String, into lines: inout [String]) {
        lines.append("## Notes")
        lines.append("")
        lines.append("- Win rates are under `\(policyID)` autoplay, not human play.")
        lines.append("- Identity party ability/affix rows are presence margins (entity appeared in loadout/gear).")
        lines.append(
            "- Enemy ability/trait rows are presence margins (opposing kit); ⚠ EASY / ⚠ HARD are player win rate vs tier peer."
        )
        lines.append("- Contrast lifts hold partner/enemy/gear fixed and swap only the focus entity.")
        lines.append("- Enemy power uses `EnemyPowerCurve` stat anchors (L1/L20/L40); the same multiplier scales enemy HP and stats.")
        lines.append("- Sweeps include hidden `FightPacing` comeback/clock scaling on authored combat magnitudes.")
        lines.append(
            "- Duration ⚠ SHORT / ⚠ LONG flag fights outside goal bands (trash \(BalanceDurationThresholds.trashGoalBand), boss \(BalanceDurationThresholds.bossGoalBand) rounds)."
        )
        lines.append("")
    }

    private static func appendIdentityTier(_ tierStats: BalanceTierStats, into lines: inout [String]) {
        lines.append("## \(tierStats.tier.displayName)")
        lines.append("")
        let winPct = tierStats.battles == 0
            ? 0
            : 100.0 * Double(tierStats.wins) / Double(tierStats.battles)
        lines.append(String(
            format: "Battles: %d · Wins: %d (%.1f%%) · Timeouts: %d · Avg rounds: %.1f · Avg party HP on win: %.0f%% · Avg enemy HP on loss: %.0f%%",
            tierStats.battles,
            tierStats.wins,
            winPct,
            tierStats.timeouts,
            tierStats.averageRounds,
            tierStats.averagePartyHPOnWin * 100,
            tierStats.averageEnemyHPOnLoss * 100
        ))
        lines.append("")
        appendDurationSection(tierStats, into: &lines)
        appendSection(title: "Heroes", summaries: tierStats.heroes, into: &lines)
        appendSection(title: "Companions", summaries: tierStats.companions, into: &lines)
        appendSection(title: "Enemies", summaries: tierStats.enemies, into: &lines)
        appendSection(title: "Party Abilities", summaries: tierStats.abilities, into: &lines, limit: 25)
        appendSection(title: "Enemy Abilities", summaries: tierStats.enemyAbilities, into: &lines, limit: 25)
        appendSection(title: "Enemy Traits", summaries: tierStats.enemyTraits, into: &lines)
        if tierStats.tier.includesGear {
            appendSection(title: "Item Affixes", summaries: tierStats.affixes, into: &lines, limit: 25)
        }
    }

    private static func appendDurationSection(_ tierStats: BalanceTierStats, into lines: inout [String]) {
        lines.append("### Duration")
        lines.append("")
        lines.append(
            "| Bucket | Goal | n | SHORT% | LONG% | Avg rounds | "
                + "Avg when SHORT | Avg when LONG | Max rounds | Worst enemy | Flag |"
        )
        lines.append(
            "|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---|"
        )
        appendDurationRow(
            label: "trash",
            goalBand: BalanceDurationThresholds.trashGoalBand,
            stats: tierStats.trashDuration,
            into: &lines
        )
        appendDurationRow(
            label: "boss",
            goalBand: BalanceDurationThresholds.bossGoalBand,
            stats: tierStats.bossDuration,
            into: &lines
        )
        lines.append("")
    }

    private static func appendDurationRow(
        label: String,
        goalBand: String,
        stats: BalanceDurationBucketStats,
        into lines: inout [String]
    ) {
        var flags: [String] = []
        if stats.shortBattles > 0 {
            flags.append("⚠ SHORT")
        }
        if stats.longBattles > 0 {
            flags.append("⚠ LONG")
        }
        let flag = flags.joined(separator: " ")
        let worst = stats.worstEnemyID.map { "`\($0)`" } ?? "—"
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
            flag
        ))
    }

    private static func appendContrasts(
        title: String,
        summaries: [PairedContrastSummary],
        into lines: inout [String]
    ) {
        lines.append("## \(title)")
        lines.append("")
        lines.append("| Entity | Baseline | Owner | Tier | Entity% | Baseline% | Lift | n | Flag |")
        lines.append("|---|---|---|---|---:|---:|---:|---:|---|")
        for row in summaries.prefix(40) {
            let flag = row.flagged ? "⚠ \(row.flagReason ?? "")" : ""
            lines.append(String(
                format: "| `%@` | `%@` | `%@` | %@ | %.1f%% | %.1f%% | %+.1f pp | %d | %@ |",
                row.entityID,
                row.baselineID,
                row.ownerID,
                row.tier.displayName,
                row.entityWinRate * 100,
                row.baselineWinRate * 100,
                row.lift * 100,
                row.pairs,
                flag
            ))
        }
        lines.append("")
    }

    private static func appendSection(
        title: String,
        summaries: [WinRateSummary],
        into lines: inout [String],
        limit: Int? = nil
    ) {
        lines.append("### \(title)")
        lines.append("")
        lines.append("| ID | Win% | Wilson 95% | n | Δ peer | Flag |")
        lines.append("|---|---:|---|---:|---:|---|")
        let rows = limit.map { Array(summaries.prefix($0)) } ?? summaries
        for row in rows {
            let flag = row.flagged ? "⚠ \(row.flagReason ?? "")" : ""
            lines.append(String(
                format: "| `%@` | %.1f%% | [%.1f–%.1f] | %d | %+.1f pp | %@ |",
                row.id,
                row.winRate * 100,
                row.wilsonLow * 100,
                row.wilsonHigh * 100,
                row.battles,
                row.deltaVsPeer * 100,
                flag
            ))
        }
        lines.append("")
    }
}
