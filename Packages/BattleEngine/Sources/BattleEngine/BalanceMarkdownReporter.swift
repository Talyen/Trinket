import Foundation

public enum BalanceMarkdownReporter {
    public static func render(_ report: BalanceSweepReport) -> String {
        let tiers = BalanceStatsAggregator.summarize(report: report)
        var lines: [String] = []
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
        lines.append("")

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

        lines.append("## Notes")
        lines.append("")
        lines.append("- Win rates are under `\(report.policyID)` autoplay, not human play.")
        lines.append("- Identity ability/affix rows are presence margins (entity appeared in loadout/gear).")
        lines.append("- Contrast lifts hold partner/enemy/gear fixed and swap only the focus entity.")
        lines.append("- Enemy ⚠ flags compare against `StatGrowth.enemyGearCompensation` target bands.")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    public static func write(
        _ report: BalanceSweepReport,
        toDirectory directoryPath: String,
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = URL(fileURLWithPath: directoryPath, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let filename = "\(stamp)-\(report.config.mode.rawValue)-seed\(report.config.seed).md"
        let fileURL = directory.appendingPathComponent(filename)
        try render(report).write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
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
        appendSection(title: "Heroes", summaries: tierStats.heroes, into: &lines)
        appendSection(title: "Pets", summaries: tierStats.pets, into: &lines)
        appendSection(title: "Enemies", summaries: tierStats.enemies, into: &lines)
        appendSection(title: "Abilities", summaries: tierStats.abilities, into: &lines, limit: 25)
        if tierStats.tier.includesGear {
            appendSection(title: "Item Affixes", summaries: tierStats.affixes, into: &lines, limit: 25)
        }
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
