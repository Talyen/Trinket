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
        var body = renderIdentityOrContrast(report)
        if report.config.mode == .all, !report.progressionPlayerStates.isEmpty {
            body += "\n"
            body += BalanceProgressionReportFormatter.render(
                config: report.config,
                hotspots: report.progressionHotspots,
                records: report.progressionRecords,
                playerStates: report.progressionPlayerStates,
                truncatedRuns: report.progressionTruncatedRuns,
                elapsedSeconds: report.elapsedSeconds
            )
        }
        return body
    }

    private static func renderIdentityOrContrast(_ report: BalanceSweepReport) -> String {
        let tiers = BalanceStatsAggregator.summarize(report: report)
        var lines: [String] = []
        appendReportHeader(report, into: &lines)

        if !report.records.isEmpty {
            for tierStats in tiers where tierStats.battles > 0 {
                BalanceMarkdownTables.appendIdentityTier(
                    tierStats,
                    compared: comparedStats(report, tier: tierStats.tier),
                    into: &lines
                )
            }
        }

        if !report.abilityContrasts.isEmpty {
            BalanceMarkdownTables.appendContrasts(
                title: "Ability Contrasts (paired lift vs sibling choice)",
                summaries: report.abilityContrasts,
                into: &lines
            )
        }

        if !report.affixContrasts.isEmpty {
            BalanceMarkdownTables.appendContrasts(
                title: "Affix Contrasts (empty-slot and replacement-affix baselines)",
                summaries: report.affixContrasts,
                into: &lines
            )
        }

        if !report.talentContrasts.isEmpty {
            BalanceMarkdownTables.appendContrasts(
                title: "Talent Contrasts (paired lift vs sibling in the same row)",
                summaries: report.talentContrasts,
                into: &lines
            )
        }

        if !report.talentKitContrasts.isEmpty {
            BalanceMarkdownTables.appendContrasts(
                title: "Talent Kit Contrasts (full kit vs none, legal point budget only)",
                summaries: report.talentKitContrasts,
                into: &lines
            )
        }

        BalanceMarkdownTables.appendUnderNAppendix(tiers: tiers, report: report, into: &lines)
        appendReportNotes(report: report, into: &lines)
        return lines.joined(separator: "\n")
    }

    private static func comparedStats(_ report: BalanceSweepReport, tier: SimulationPowerTier) -> BalanceTierStats? {
        guard !report.comparedRecords.isEmpty else { return nil }
        return BalanceStatsAggregator.summarize(report: report, records: report.comparedRecords)
            .first { $0.tier == tier }
    }

    private static func appendReportHeader(_ report: BalanceSweepReport, into lines: inout [String]) {
        let roster = report.config.resolvedRoster
        let samples = report.config.battlesPerTier
        let expectedEnemyN = samples
        let expectedHeroN = roster.enemies.isEmpty || roster.heroes.isEmpty
            ? 0
            : samples * roster.enemies.count / roster.heroes.count
        let expectedCompanionN = roster.enemies.isEmpty || roster.companions.isEmpty
            ? 0
            : samples * roster.enemies.count / roster.companions.count
        lines.append("# Balance Sweep Report")
        lines.append("")
        lines.append("- Mode: `\(report.config.mode.rawValue)`")
        lines.append("- Policy: `\(report.policyID)`")
        if let compared = report.comparedPolicyID {
            lines.append("- Compared policy: `\(compared)`")
        }
        lines.append("- Seed: `\(report.config.seed)`")
        lines.append("- Samples per unit: `\(samples)`")
        lines.append("- Jobs: `\(report.config.resolvedJobs)`")
        lines.append("- Tiers: \(report.config.tiers.map(\.rawValue).joined(separator: ", "))")
        lines.append("- Fight pacing: `\(report.config.appliesFightPacing ? "on" : "off")`")
        lines.append("- Identity battles: `\(report.records.count)`")
        lines.append(
            "- Expected n/tier: enemies `\(expectedEnemyN)`, heroes ~`\(expectedHeroN)`, companions ~`\(expectedCompanionN)`, contrast pairs/focus `\(samples)`"
        )
        lines.append("- Ability contrast rows: `\(report.abilityContrasts.count)`")
        lines.append("- Affix contrast rows: `\(report.affixContrasts.count)`")
        lines.append("- Talent contrast rows: `\(report.talentContrasts.count)`")
        lines.append("- Talent kit contrast rows: `\(report.talentKitContrasts.count)`")
        lines.append(String(format: "- Elapsed: `%.2fs`", report.elapsedSeconds))
        if report.elapsedSeconds > 0, !report.records.isEmpty {
            lines.append(String(
                format: "- Identity throughput: `%.1f` battles/sec",
                Double(report.records.count) / report.elapsedSeconds
            ))
        }
        lines.append("- Peer Δ / lift flag threshold: `\(Int(report.config.peerDeltaFlagThreshold * 100)) pp`")
        lines.append(
            "- Duration goal bands: trash `\(BalanceDurationThresholds.trashGoalBand)` rounds, boss `\(BalanceDurationThresholds.bossGoalBand)` rounds; flag when SHORT% or LONG% ≥ \(Int(report.config.durationFlagRate * 100))%."
        )
        if samples < BalanceSweepConfig.contrastFlagMinPairs {
            lines.append(
                "- Warning: samples < \(BalanceSweepConfig.contrastFlagMinPairs); contrast flags are disabled."
            )
        }
        lines.append("")
    }

    private static func appendReportNotes(report: BalanceSweepReport, into lines: inout [String]) {
        lines.append("## Notes")
        lines.append("")
        lines.append("- Win rates are under `\(report.policyID)` autoplay, not human play. Timeouts are excluded from win rate.")
        lines.append("- Identity party ability/affix/talent rows are within-owner presence margins; contrasts isolate a sibling swap.")
        lines.append(
            "- Identity spends available talent points (1 per even level) on a legal kit: "
                + "early a 1-node spend at L4 plus one basic aligned item, middle a partial spend, late the full 18-node kit. "
                + "The early→middle cliff includes level, gear, and talents."
        )
        lines.append(
            "- Enemy ability/trait rows are presence margins (opposing kit); ⚠ EASY / ⚠ HARD are player win rate vs tier peer."
        )
        lines.append("- Contrast lifts hold partner/enemy/gear/loadout fixed and swap only the focus entity.")
        lines.append("- Ability and affix contrasts keep talents empty so those lifts stay isolated.")
        lines.append(
            "- Talent sibling contrasts swap one row choice (minimal legal prefix in that tree) only when the tier's talent points cover the prefix. "
                + "Kit contrasts run only when points cover the full catalog (late)."
        )
        lines.append("- Affix contrasts report empty-slot and replacement-affix baselines separately.")
        lines.append("- Gold and other economy talents are marked NONCOMBAT and never flagged LOW.")
        lines.append(
            "- Enemy power uses `EnemyPowerCurve` (L1/L20/L40): trash shares HP/stat multipliers; "
                + "boss HP is 50% above trash; L1 boss stats are 5.2 (L20/L40 10.77/18.90)."
        )
        lines.append(
            "- Fight pacing is \(report.config.appliesFightPacing ? "ON" : "OFF") "
                + "for this sweep (`--pacing off` measures raw kit power)."
        )
        lines.append("")
    }
}
