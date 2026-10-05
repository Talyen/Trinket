import BattleEngine
import Foundation

public enum BalanceMarkdownReporter {
    public static func render(_ report: BalanceSweepReport) -> String {
        render(report, snapshots: BalanceTierSnapshots(report: report))
    }

    public static func render(_ report: BalanceSweepReport, snapshots: BalanceTierSnapshots) -> String {
        if report.config.mode == .modeProgression {
            return progressionSection(report)
        }
        var body = renderIdentityOrContrast(report, snapshots: snapshots)
        if report.config.mode == .all, !report.progressionPlayerStates.isEmpty {
            body += "\n" + progressionSection(report)
        }
        return body
    }

    private static func progressionSection(_ report: BalanceSweepReport) -> String {
        BalanceProgressionReportFormatter.render(
            config: report.config,
            hotspots: report.progressionHotspots,
            records: report.progressionRecords,
            playerStates: report.progressionPlayerStates,
            truncatedRuns: report.progressionTruncatedRuns,
            elapsedSeconds: report.elapsedSeconds,
        )
    }

    private static func renderIdentityOrContrast(
        _ report: BalanceSweepReport,
        snapshots: BalanceTierSnapshots,
    ) -> String {
        var lines: [String] = []
        appendReportHeader(report, into: &lines)
        if !report.records.isEmpty {
            for tierStats in snapshots.tiers where tierStats.battles > 0 {
                BalanceMarkdownTables.appendIdentityTier(
                    tierStats,
                    compared: snapshots.comparedTiers.first { $0.tier == tierStats.tier },
                    into: &lines,
                )
            }
        }
        for section in report.contrastSections where !section.rows.isEmpty {
            BalanceMarkdownTables.appendContrasts(title: section.title, summaries: section.rows, into: &lines)
        }
        BalanceMarkdownTables.appendUnderNAppendix(tiers: snapshots.tiers, report: report, into: &lines)
        appendReportNotes(report: report, into: &lines)
        return lines.joined(separator: "\n")
    }

    private static func appendReportHeader(_ report: BalanceSweepReport, into lines: inout [String]) {
        let roster = report.config.resolvedRoster
        let samples = report.config.battlesPerTier
        let expectedHeroN = roster.enemies.isEmpty || roster.heroes.isEmpty ? 0 : samples * roster.enemies.count / roster.heroes.count
        let expectedCompanionN = roster.enemies.isEmpty || roster.companions.isEmpty ? 0 : samples * roster.enemies.count / roster
            .companions.count
        var header = [
            "# Balance Sweep Report",
            "",
            "- Mode: `\(report.config.mode.rawValue)`",
            "- Policy: `\(report.policyID)`",
            "- Seed: `\(report.config.seed)`",
            "- Samples per unit: `\(samples)`",
            "- Jobs: `\(report.config.resolvedJobs)`",
            "- Tiers: \(report.config.tiers.map(\.rawValue).joined(separator: ", "))",
            "- Fight pacing: `\(report.config.appliesFightPacing ? "on" : "off")`",
            "- Contrast builds: `\(report.config.usesTierTalents ? "tier-legal talents" : "minimal talents (diagnostic)")`",
            "- Identity battles: `\(report.records.count)`",
            "- Expected n/tier: enemies `\(samples)`, heroes ~`\(expectedHeroN)`, companions ~`\(expectedCompanionN)`, contrast pairs/focus `\(samples)`",
            "- Ability contrast rows: `\(report.abilityContrasts.count)`",
            "- Affix contrast rows: `\(report.affixContrasts.count)`",
            "- Talent contrast rows: `\(report.talentContrasts.count)`",
            "- Talent kit contrast rows: `\(report.talentKitContrasts.count)`",
            String(format: "- Elapsed: `%.2fs`", report.elapsedSeconds),
        ]
        if let compared = report.comparedPolicyID {
            header.insert("- Compared policy: `\(compared)`", at: 4)
        }
        if report.elapsedSeconds > 0, !report.records.isEmpty {
            header.append(String(format: "- Identity throughput: `%.1f` battles/sec", Double(report.records.count) / report.elapsedSeconds))
        }
        header.append("- Peer Δ / lift flag threshold: `\(Int(report.config.peerDeltaFlagThreshold * 100)) pp`")
        header
            .append(
                "- Duration goal bands: trash `\(BalanceDurationThresholds.trashGoalBand)` rounds, boss `\(BalanceDurationThresholds.bossGoalBand)` rounds; flag when SHORT% or LONG% ≥ \(Int(report.config.durationFlagRate * 100))%.",
            )
        if samples < BalanceSweepConfig.contrastFlagMinPairs {
            header.append("- Warning: samples < \(BalanceSweepConfig.contrastFlagMinPairs); contrast flags are disabled.")
        }
        header.append("")
        lines.append(contentsOf: header)
    }

    private static func appendReportNotes(report: BalanceSweepReport, into lines: inout [String]) {
        lines.append(contentsOf: [
            "## Notes",
            "",
            "- Win rates are under `\(report.policyID)` autoplay, not human play. Timeouts are excluded from win rate.",
            "- Identity party ability/affix/talent rows are within-owner presence margins; contrasts isolate a sibling swap.",
            "- Identity spends available talent points (1 per even level) on a legal kit: early a 1-node spend at L4 plus one basic aligned item, middle a partial spend, late the full 18-node kit. The early→middle cliff includes level, gear, and talents.",
            "- Enemy ability/trait rows are presence margins (opposing kit); ⚠ EASY / ⚠ HARD are player win rate vs tier peer.",
            "- Contrast lifts hold partner/enemy/gear/loadout fixed and swap only the focus entity.",
            "- Ability and affix contrasts keep talents empty so those lifts stay isolated.",
            "- Talent sibling contrasts swap one row choice (minimal legal prefix in that tree) only when the tier's talent points cover the prefix. Kit contrasts run only when points cover the full catalog (late).",
            "- Affix contrasts report empty-slot and replacement-affix baselines separately.",
            "- Gold and other economy talents are marked NONCOMBAT and never flagged LOW.",
            "- Enemy power uses `EnemyPowerCurve`: smoothstep between L1/L20/L40 anchors, then uncapped logarithmic HP growth and linear damage growth.",
            "- Fight pacing is \(report.config.appliesFightPacing ? "ON" : "OFF") for this sweep (`--pacing off` measures raw kit power).",
            "",
        ])
    }
}
