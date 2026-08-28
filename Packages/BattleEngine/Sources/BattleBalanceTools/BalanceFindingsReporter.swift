import BattleEngine
import Foundation

public enum BalanceFindingsReporter {
    public static let contrastCap = 12
    public static let pairingCap = 3

    public static func render(_ report: BalanceSweepReport) -> String {
        var lines: [String] = []
        appendHeader(report, into: &lines)
        appendSnapshot(report, into: &lines)
        let findings = collectFindings(report)
        appendFindings(findings, into: &lines)
        lines.append(
            "Win rates are under `\(report.policyID)` autoplay; "
                + "see `Packages/BattleEngine/README.md`. "
                + "Drill-down: JSON sidecar or `--full-markdown`."
        )
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private struct Finding {
        var score: Double
        var line: String
    }

    private static func appendHeader(_ report: BalanceSweepReport, into lines: inout [String]) {
        lines.append("# Balance Sweep Findings")
        lines.append("")
        lines.append("- Mode: `\(report.config.mode.rawValue)`")
        lines.append("- Policy: `\(report.policyID)`")
        if let compared = report.comparedPolicyID {
            lines.append("- Compared policy: `\(compared)`")
        }
        lines.append("- Seed: `\(report.config.seed)`")
        lines.append("- Samples: `\(report.config.battlesPerTier)` per identity enemy / contrast focus")
        if !report.records.isEmpty {
            lines.append("- Identity battles: `\(report.records.count)`")
        }
        lines.append("- Tiers: \(report.config.tiers.map(\.rawValue).joined(separator: ", "))")
        lines.append("- Fight pacing: `\(report.config.appliesFightPacing ? "on" : "off")`")
        lines.append(String(format: "- Elapsed: `%.2fs`", report.elapsedSeconds))
        lines.append("")
    }

    private static func appendSnapshot(_ report: BalanceSweepReport, into lines: inout [String]) {
        let tiers = BalanceStatsAggregator.summarize(report: report)
        let identityTiers = tiers.filter { $0.battles > 0 }
        if !identityTiers.isEmpty {
            lines.append("## Snapshot")
            lines.append("")
            for tier in identityTiers {
                let winPct = tier.decidedBattles == 0
                    ? 0
                    : 100.0 * Double(tier.wins) / Double(tier.decidedBattles)
                var line = String(
                    format: "- %@: %d battles, %.1f%% win, %d timeouts, avg %.1f rounds",
                    tier.tier.displayName,
                    tier.battles,
                    winPct,
                    tier.timeouts,
                    tier.averageRounds
                )
                if let comparedID = report.comparedPolicyID, !report.comparedRecords.isEmpty {
                    let comparedTiers = BalanceStatsAggregator.summarize(
                        report: report,
                        records: report.comparedRecords
                    )
                    if let compared = comparedTiers.first(where: { $0.tier == tier.tier }) {
                        let comparedPct = compared.decidedBattles == 0
                            ? 0
                            : 100.0 * Double(compared.wins) / Double(compared.decidedBattles)
                        line += String(
                            format: " · `%@` %.1f%% win (Δ%+.1f)",
                            comparedID,
                            comparedPct,
                            comparedPct - winPct
                        )
                    }
                }
                lines.append(line)
            }
            lines.append("")
        }
        if !report.progressionPlayerStates.isEmpty {
            let flagged = report.progressionHotspots.filter(\.isFlagged).count
            lines.append(
                "- Progression nodes: `\(report.progressionHotspots.count)`, "
                    + "hotspots: `\(flagged)`, runs: `\(report.progressionPlayerStates.count)`"
            )
            lines.append("")
        }
    }

    private static func appendFindings(_ findings: [Finding], into lines: inout [String]) {
        lines.append("## Findings")
        lines.append("")
        if findings.isEmpty {
            lines.append("No serious findings under the flag bars.")
            lines.append("")
            return
        }
        for (index, finding) in findings.enumerated() {
            lines.append("\(index + 1). \(finding.line)")
        }
        lines.append("")
    }

    private static func collectFindings(_ report: BalanceSweepReport) -> [Finding] {
        var findings: [Finding] = []
        let tiers = BalanceStatsAggregator.summarize(report: report)
        for tier in tiers where tier.battles > 0 {
            findings.append(contentsOf: identityFindings(tier: tier, records: report.records))
        }
        findings.append(contentsOf: contrastFindings(report.abilityContrasts, kind: "ability"))
        findings.append(contentsOf: contrastFindings(report.affixContrasts, kind: "affix"))
        findings.append(contentsOf: contrastFindings(report.talentContrasts, kind: "talent"))
        findings.append(contentsOf: contrastFindings(report.talentKitContrasts, kind: "talent kit"))
        findings.append(contentsOf: progressionFindings(report.progressionHotspots))
        return findings.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            return lhs.line < rhs.line
        }
    }

    private static func identityFindings(tier: BalanceTierStats, records: [BalanceBattleRecord]) -> [Finding] {
        var findings: [Finding] = []
        findings.append(contentsOf: durationFinding(tier.trashDuration, bucket: "trash", tier: tier.tier))
        findings.append(contentsOf: durationFinding(tier.bossDuration, bucket: "boss", tier: tier.tier))
        findings.append(contentsOf: rosterFindings(tier.heroes, kind: "hero", tier: tier.tier))
        findings.append(contentsOf: rosterFindings(tier.companions, kind: "companion", tier: tier.tier))
        findings.append(contentsOf: rosterFindings(tier.enemies, kind: "enemy", tier: tier.tier, records: records))
        findings.append(contentsOf: rosterFindings(tier.abilities, kind: "ability", tier: tier.tier))
        findings.append(contentsOf: rosterFindings(tier.talents, kind: "talent", tier: tier.tier))
        findings.append(contentsOf: rosterFindings(tier.affixes, kind: "affix", tier: tier.tier))
        findings.append(contentsOf: rosterFindings(tier.enemyAbilities, kind: "enemy ability", tier: tier.tier))
        findings.append(contentsOf: rosterFindings(tier.enemyTraits, kind: "enemy trait", tier: tier.tier))
        findings.append(contentsOf: collapsedSplit(
            split: tier.heroesBoss,
            kind: "hero",
            vs: "bosses",
            tier: tier.tier
        ))
        findings.append(contentsOf: collapsedSplit(
            split: tier.companionsBoss,
            kind: "companion",
            vs: "bosses",
            tier: tier.tier
        ))
        let flaggedIDs = Set(
            (tier.heroes + tier.companions + tier.enemies).filter(\.flagged).map(\.id)
        )
        findings.append(contentsOf: pairingFindings(
            tier.heroCompanionCells,
            flaggedIDs: flaggedIDs,
            labels: ("hero", "companion"),
            tier: tier.tier
        ))
        findings.append(contentsOf: pairingFindings(
            tier.heroEnemyCells,
            flaggedIDs: flaggedIDs,
            labels: ("hero", "enemy"),
            tier: tier.tier
        ))
        return findings
    }

    private static func rosterFindings(
        _ rows: [WinRateSummary],
        kind: String,
        tier: SimulationPowerTier,
        records: [BalanceBattleRecord] = []
    ) -> [Finding] {
        rows.filter(\.flagged).map { row in
            let why = if kind == "enemy" {
                enemyWhy(row.id, records: records.filter { $0.tier == tier })
            } else {
                "vs \(tier.displayName) peer"
            }
            return Finding(
                score: abs(row.deltaVsPeer),
                line: String(
                    format: "%@ `%@` (%@): ⚠ %@ · %.1f%% win [%.1f–%.1f] · n=%d · %+.1f pp · %@",
                    kind.capitalized,
                    row.id,
                    tier.displayName,
                    row.flagReason ?? "",
                    row.winRate * 100,
                    row.wilsonLow * 100,
                    row.wilsonHigh * 100,
                    row.battles,
                    row.deltaVsPeer * 100,
                    why
                )
            )
        }
    }

    private static func collapsedSplit(
        split: [WinRateSummary],
        kind: String,
        vs: String,
        tier: SimulationPowerTier
    ) -> [Finding] {
        let flagged = split.filter(\.flagged)
        guard flagged.count >= 2, flagged.count == split.count else { return [] }
        let reasons = Set(flagged.compactMap(\.flagReason))
        guard reasons.count == 1, let reason = reasons.first else { return [] }
        let rates = flagged.map(\.winRate)
        let minRate = (rates.min() ?? 0) * 100
        let maxRate = (rates.max() ?? 0) * 100
        let meanDelta = flagged.map(\.deltaVsPeer).reduce(0, +) / Double(flagged.count)
        return [
            Finding(
                score: abs(meanDelta),
                line: String(
                    format: "All %@s vs %@ (%@): ⚠ %@ · %.1f–%.1f%% win · n=%d each · same story, not listed per id",
                    kind,
                    vs,
                    tier.displayName,
                    reason,
                    minRate,
                    maxRate,
                    flagged.first?.battles ?? 0
                )
            ),
        ]
    }

    private static func durationFinding(
        _ bucket: BalanceDurationBucketStats,
        bucket name: String,
        tier: SimulationPowerTier
    ) -> [Finding] {
        guard bucket.flagged else { return [] }
        let worst = bucket.worstEnemyID.map { "`\($0)`" } ?? "—"
        return [
            Finding(
                score: max(bucket.shortRate, bucket.longRate),
                line: String(
                    format: "Duration %@ (%@): ⚠ %@ · SHORT %.0f%% · LONG %.0f%% · avg %.1f rounds · worst %@",
                    name,
                    tier.displayName,
                    bucket.flagReason ?? "",
                    bucket.shortRate * 100,
                    bucket.longRate * 100,
                    bucket.averageRounds,
                    worst
                )
            ),
        ]
    }

    private static func pairingFindings(
        _ cells: [PairCellSummary],
        flaggedIDs: Set<String>,
        labels: (String, String),
        tier: SimulationPowerTier
    ) -> [Finding] {
        let explained = cells.filter { flaggedIDs.contains($0.leftID) || flaggedIDs.contains($0.rightID) }
            .sorted { abs($0.deltaVsPeer) > abs($1.deltaVsPeer) }
        return Array(explained.prefix(pairingCap)).map { cell in
            Finding(
                score: abs(cell.deltaVsPeer) * 0.5,
                line: String(
                    format: "%@ `%@` × %@ `%@` (%@): ⚠ %@ · %.1f%% win · n=%d · %+.1f pp · explains roster flag",
                    labels.0,
                    cell.leftID,
                    labels.1,
                    cell.rightID,
                    tier.displayName,
                    cell.flagReason ?? "",
                    cell.winRate * 100,
                    cell.battles,
                    cell.deltaVsPeer * 100
                )
            )
        }
    }

    private static func contrastFindings(_ rows: [PairedContrastSummary], kind: String) -> [Finding] {
        let flagged = rows.filter(\.flagged).sorted(by: BalanceContrastFlags.summarySort)
        let extra = max(0, flagged.count - contrastCap)
        var findings = Array(flagged.prefix(contrastCap)).map { row -> Finding in
            Finding(
                score: max(abs(row.lift), abs(row.meanDeltaPartyHP), abs(row.meanDeltaRounds) / 10),
                line: String(
                    format: "%@ `%@` vs `%@` on `%@` (%@, %@): ⚠ %@ · lift %+.1f pp · ΔHP %+.2f · Δrounds %+.1f · n=%d decided · sibling swap",
                    kind.capitalized,
                    row.entityID,
                    row.baselineID,
                    row.ownerID,
                    row.tier.displayName,
                    row.baselineKind.rawValue,
                    row.flagReason ?? "",
                    row.lift * 100,
                    row.meanDeltaPartyHP,
                    row.meanDeltaRounds,
                    row.decidedPairs
                )
            )
        }
        if extra > 0 {
            findings.append(
                Finding(score: 0, line: "\(extra) more flagged \(kind) contrasts; see JSON.")
            )
        }
        return findings
    }

    private static func progressionFindings(_ hotspots: [NodeHotspotSummary]) -> [Finding] {
        hotspots.filter(\.isFlagged).map { hotspot in
            let envelope: Double = switch hotspot.status {
            case .overtuned, .levelGapWall:
                HotspotAnalyzer.targetLowerBound - hotspot.winRate
            case .undertuned:
                hotspot.winRate - HotspotAnalyzer.targetUpperBound
            case .smooth:
                0
            }
            return Finding(
                score: max(0.15, envelope),
                line: String(
                    format: "Progression `%@` / `%@` vs `%@`: **%@** · %.1f%% win [%.1f–%.1f] · player L%.1f vs enemy L%.1f · %@",
                    hotspot.step.containerTitle,
                    hotspot.step.displayTitle,
                    hotspot.step.enemyID,
                    hotspot.status.displayName,
                    hotspot.winRate * 100,
                    hotspot.wilsonLow * 100,
                    hotspot.wilsonHigh * 100,
                    hotspot.averagePlayerLevel,
                    hotspot.averageEnemyLevel,
                    hotspot.flagReason ?? ""
                )
            )
        }
    }

    private static func enemyWhy(_ enemyID: String, records: [BalanceBattleRecord]) -> String {
        let mine = records.filter { $0.enemyID == enemyID }
        let others = records.filter { $0.enemyID != enemyID }
        let mineAbilities = Set(mine.flatMap(\.enemyAbilityIDs))
        let otherAbilities = Set(others.flatMap(\.enemyAbilityIDs))
        let unique = mineAbilities.subtracting(otherAbilities).sorted()
        if !unique.isEmpty {
            let listed = unique.map { "`\($0)`" }.joined(separator: ", ")
            return "only enemy with \(listed)"
        }
        if let trait = mine.first?.enemyTraitID, !trait.isEmpty {
            return "trait `\(trait)`"
        }
        return "identity vs \(enemyID)"
    }
}
