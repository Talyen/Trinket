import Foundation

public enum BalanceMarkdownReporter {
    public static func render(_ report: BalanceSweepReport) -> String {
        let tiers = BalanceStatsAggregator.summarize(report: report)
        var lines: [String] = []
        lines.append("# Balance Sweep Report")
        lines.append("")
        lines.append("- Policy: `\(report.policyID)`")
        lines.append("- Seed: `\(report.config.seed)`")
        lines.append("- Battles per tier: `\(report.config.battlesPerTier)`")
        lines.append("- Tiers: \(report.config.tiers.map(\.rawValue).joined(separator: ", "))")
        lines.append("- Total battles: `\(report.records.count)`")
        lines.append(String(format: "- Elapsed: `%.2fs` (%.1f battles/sec)",
                            report.elapsedSeconds,
                            report.elapsedSeconds > 0
                                ? Double(report.records.count) / report.elapsedSeconds
                                : 0))
        lines.append("- Peer Δ flag threshold: `\(Int(report.config.peerDeltaFlagThreshold * 100)) pp`")
        lines.append("")

        for tierStats in tiers {
            lines.append("## \(tierStats.tier.displayName)")
            lines.append("")
            let winPct = tierStats.battles == 0
                ? 0
                : 100.0 * Double(tierStats.wins) / Double(tierStats.battles)
            lines.append(String(
                format: "Battles: %d · Wins: %d (%.1f%%) · Timeouts: %d",
                tierStats.battles,
                tierStats.wins,
                winPct,
                tierStats.timeouts
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

        lines.append("## Notes")
        lines.append("")
        lines.append("- Win rates are under `\(report.policyID)` autoplay, not human play.")
        lines.append("- Ability/affix rows are presence margins (battles where the entity appeared in the loadout/gear).")
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
        let filename = "\(stamp)-seed\(report.config.seed).md"
        let fileURL = directory.appendingPathComponent(filename)
        try render(report).write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
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
