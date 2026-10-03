import BattleEngine
import Foundation

public enum BalanceFindingsReporter {
    public static let contrastCap = 12
    public static let pairingCap = 3

    public static func render(_ report: BalanceSweepReport) -> String {
        render(report, snapshots: BalanceTierSnapshots(report: report))
    }

    public static func render(_ report: BalanceSweepReport, snapshots: BalanceTierSnapshots) -> String {
        var lines: [String] = []
        appendHeader(report, into: &lines)
        appendSnapshot(report, snapshots: snapshots, into: &lines)
        appendFindings(collectFindings(report, snapshots: snapshots), into: &lines)
        lines.append(
            "Win rates are under `\(report.policyID)` autoplay; "
                + "see `Packages/BattleEngine/README.md`. "
                + "Drill-down: JSON sidecar or `--full-markdown`.",
        )
        lines.append("")
        return lines.joined(separator: "\n")
    }

    fileprivate struct Finding {
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

    private static func appendSnapshot(
        _ report: BalanceSweepReport,
        snapshots: BalanceTierSnapshots,
        into lines: inout [String],
    ) {
        let tiers = snapshots.tiers.filter { $0.battles > 0 }
        if !tiers.isEmpty {
            lines.append("## Snapshot")
            lines.append("")
            for tier in tiers {
                lines.append(snapshotLine(tier, report: report, comparedTiers: snapshots.comparedTiers))
            }
            lines.append("")
        }
        if !report.progressionPlayerStates.isEmpty {
            let flagged = report.progressionHotspots.filter(\.isFlagged).count
            lines.append(
                "- Progression nodes: `\(report.progressionHotspots.count)`, "
                    + "hotspots: `\(flagged)`, runs: `\(report.progressionPlayerStates.count)`",
            )
            lines.append("")
        }
    }

    private static func snapshotLine(_ tier: BalanceTierStats, report: BalanceSweepReport, comparedTiers: [BalanceTierStats]) -> String {
        let winPct = BalanceStatsAggregator.winPercent(wins: tier.wins, decided: tier.decidedBattles)
        var line = String(
            format: "- %@: %d battles, %.1f%% win, %d timeouts, avg %.1f rounds",
            tier.tier.displayName,
            tier.battles,
            winPct,
            tier.timeouts,
            tier.averageRounds,
        )
        if let comparedID = report.comparedPolicyID,
           let compared = comparedTiers.first(where: { $0.tier == tier.tier }) {
            let comparedPct = BalanceStatsAggregator.winPercent(wins: compared.wins, decided: compared.decidedBattles)
            line += String(format: " · `%@` %.1f%% win (Δ%+.1f)", comparedID, comparedPct, comparedPct - winPct)
        }
        return line
    }

    private static func appendFindings(_ findings: [Finding], into lines: inout [String]) {
        lines.append("## Findings")
        lines.append("")
        if findings.isEmpty {
            lines.append("No flags in the sampled content; this does not establish balance or complete coverage.")
            lines.append("")
            return
        }
        for (index, finding) in findings.enumerated() {
            lines.append("\(index + 1). \(finding.line)")
        }
        lines.append("")
    }

    private static func collectFindings(_ report: BalanceSweepReport, snapshots: BalanceTierSnapshots) -> [Finding] {
        var findings: [Finding] = []
        let recordsByTier = Dictionary(grouping: report.records, by: \.tier)
        for tier in snapshots.tiers where tier.battles > 0 {
            let evidence = EnemyEvidence(records: recordsByTier[tier.tier] ?? [])
            findings.append(contentsOf: identityFindings(tier: tier, evidence: evidence))
            findings.append(contentsOf: stallFindings(tier: tier, evidence: evidence))
        }
        for section in report.contrastSections {
            findings.append(contentsOf: contrastFindings(section.rows, kind: section.kind))
        }
        findings.append(contentsOf: progressionFindings(report.progressionHotspots))
        findings.append(contentsOf: crossTierFindings(tiers: snapshots.tiers))
        return findings.sorted {
            $0.score != $1.score ? $0.score > $1.score : $0.line < $1.line
        }
    }
}

extension BalanceFindingsReporter {
    private struct EnemyEvidence {
        let recordsByEnemy: [String: [BalanceBattleRecord]]
        let abilitiesByEnemy: [String: Set<String>]
        let abilityOwnerCounts: [String: Int]

        init(records: [BalanceBattleRecord]) {
            let grouped = Dictionary(grouping: records, by: \.enemyID)
            let abilities = grouped.mapValues { Set($0.flatMap(\.enemyAbilityIDs)) }
            var ownerCounts: [String: Int] = [:]
            for ids in abilities.values {
                for id in ids {
                    ownerCounts[id, default: 0] += 1
                }
            }
            recordsByEnemy = grouped
            abilitiesByEnemy = abilities
            abilityOwnerCounts = ownerCounts
        }

        func explanation(for enemyID: String) -> String {
            let unique = (abilitiesByEnemy[enemyID] ?? []).filter { abilityOwnerCounts[$0] == 1 }.sorted()
            if !unique.isEmpty {
                return "only enemy with " + unique.map { "`\($0)`" }.joined(separator: ", ")
            }
            if let traits = recordsByEnemy[enemyID]?.first?.enemyTraitIDs, !traits.isEmpty {
                return "traits " + traits.map { "`\($0)`" }.joined(separator: ", ")
            }
            return "identity vs \(enemyID)"
        }
    }

    private static func identityFindings(tier: BalanceTierStats, evidence: EnemyEvidence) -> [Finding] {
        var findings = durationFinding(tier.trashDuration, bucket: "trash", tier: tier.tier)
        findings += durationFinding(tier.bossDuration, bucket: "boss", tier: tier.tier)
        findings += enemyDurationFindings(tier.enemyDurations, tier: tier.tier)
        findings += combatantDurationFindings(tier.heroDurations, kind: "hero", tier: tier.tier)
        findings += combatantDurationFindings(tier.companionDurations, kind: "companion", tier: tier.tier)
        for (rows, kind) in [
            (tier.heroes, "hero"), (tier.companions, "companion"), (tier.items, "item"),
            (tier.abilities, "ability"), (tier.talents, "talent"), (tier.affixes, "affix"),
            (tier.enemyAbilities, "enemy ability"), (tier.enemyTraits, "enemy trait"),
        ] {
            findings += rosterFindings(rows, kind: kind, tier: tier.tier)
        }
        findings += rosterFindings(tier.enemies, kind: "enemy", tier: tier.tier, enemyEvidence: evidence)
        findings += collapsedSplit(split: tier.heroesBoss, kind: "hero", vs: "bosses", tier: tier.tier)
        findings += collapsedSplit(split: tier.companionsBoss, kind: "companion", vs: "bosses", tier: tier.tier)
        findings += pairingFindings(tier.heroCompanionCells, labels: ("hero", "companion"), tier: tier.tier)
        findings += pairingFindings(tier.heroEnemyCells, labels: ("hero", "enemy"), tier: tier.tier)
        return findings
    }

    private static func stallFindings(tier: BalanceTierStats, evidence: EnemyEvidence) -> [Finding] {
        let grouped = evidence.recordsByEnemy
        return grouped.keys.sorted().compactMap { enemyID in
            let samples = grouped[enemyID] ?? []
            let stalls = samples.count { $0.result.timedOut }
            guard stalls > 0 else { return nil }
            return Finding(
                score: Double(stalls) / Double(samples.count),
                line: "Enemy `\(enemyID)` (\(tier.tier.displayName)): ⚠ STALL · "
                    + "\(stalls)/\(samples.count) battles reached a simulation cap; "
                    + "win rates exclude these unfinished fights.",
            )
        }
    }

    private static func rosterFindings(
        _ rows: [WinRateSummary],
        kind: String,
        tier: SimulationPowerTier,
        enemyEvidence: EnemyEvidence? = nil,
    ) -> [Finding] {
        rows.filter(\.flagged).map { row in
            let why: String = if let enemyEvidence {
                enemyEvidence.explanation(for: row.id)
            } else if let targetDelta = row.targetBandDelta {
                String(format: "vs %@ peer (target Δ%+.1f pp)", tier.displayName, targetDelta * 100)
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
                    why,
                ),
            )
        }
    }

    private static func collapsedSplit(
        split: [WinRateSummary],
        kind: String,
        vs: String,
        tier: SimulationPowerTier,
    ) -> [Finding] {
        let flagged = split.filter(\.flagged)
        guard flagged.count >= 2, flagged.count == split.count else { return [] }
        let reasons = Set(flagged.compactMap(\.flagReason))
        guard reasons.count == 1, let reason = reasons.first else { return [] }
        let rates = flagged.map(\.winRate)
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
                    (rates.min() ?? 0) * 100,
                    (rates.max() ?? 0) * 100,
                    flagged.first?.battles ?? 0,
                ),
            ),
        ]
    }

    private static func durationFinding(
        _ bucket: BalanceDurationBucketStats,
        bucket name: String,
        tier: SimulationPowerTier,
    ) -> [Finding] {
        guard bucket.flagged else { return [] }
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
                    bucket.worstEnemyID.map { "`\($0)`" } ?? "-",
                ),
            ),
        ]
    }

    private static func pairingFindings(
        _ cells: [PairCellSummary],
        labels: (String, String),
        tier: SimulationPowerTier,
    ) -> [Finding] {
        Array(
            cells.filter(\.flagged)
                .sorted { abs($0.deltaVsPeer) > abs($1.deltaVsPeer) }
                .prefix(pairingCap),
        ).map { cell in
            Finding(
                score: abs(cell.deltaVsPeer) * 0.5,
                line: String(
                    format: "%@ `%@` × %@ `%@` (%@): ⚠ %@ · %.1f%% win · n=%d · %+.1f pp · pairing outlier",
                    labels.0,
                    cell.leftID,
                    labels.1,
                    cell.rightID,
                    tier.displayName,
                    cell.flagReason ?? "",
                    cell.winRate * 100,
                    cell.battles,
                    cell.deltaVsPeer * 100,
                ),
            )
        }
    }

    private static func enemyDurationFindings(
        _ rows: [BalanceEnemyDurationStats],
        tier: SimulationPowerTier,
    ) -> [Finding] {
        rows.filter(\.flagged).map { row in
            durationFinding(
                id: row.enemyID, kind: "Enemy",
                stats: (
                    averageRounds: row.averageRounds, shortRate: row.shortRate, longRate: row.longRate,
                    battles: row.battles, reason: row.flagReason,
                ),
                tier: tier,
            )
        }
    }

    private static func combatantDurationFindings(
        _ rows: [BalanceCombatantDurationStats],
        kind: String,
        tier: SimulationPowerTier,
    ) -> [Finding] {
        rows.filter(\.flagged).map { row in
            durationFinding(
                id: row.combatantID, kind: kind.capitalized,
                stats: (
                    averageRounds: row.averageRounds, shortRate: row.shortRate, longRate: row.longRate,
                    battles: row.battles, reason: row.flagReason,
                ),
                tier: tier,
            )
        }
    }

    private static func durationFinding(
        id: String, kind: String,
        stats: (averageRounds: Double, shortRate: Double, longRate: Double, battles: Int, reason: String?),
        tier: SimulationPowerTier,
    ) -> Finding {
        Finding(
            score: max(stats.shortRate, stats.longRate),
            line: String(
                format: "%@ `%@` (%@ duration): ⚠ %@ · avg %.1f rounds · SHORT %.0f%% · LONG %.0f%% · n=%d",
                kind,
                id,
                tier.displayName,
                stats.reason ?? "",
                stats.averageRounds,
                stats.shortRate * 100,
                stats.longRate * 100,
                stats.battles,
            ),
        )
    }

    private static func crossTierFindings(tiers: [BalanceTierStats]) -> [Finding] {
        let activeTiers = tiers.filter { $0.battles > 0 }
        guard activeTiers.count >= 2 else { return [] }
        var enemyFlags: [String: [String]] = [:]
        for tier in activeTiers {
            for enemy in tier.enemies where enemy.flagged {
                enemyFlags[enemy.id, default: []].append(tier.tier.displayName)
            }
        }
        return enemyFlags.filter { $0.value.count >= 2 }.sorted { $0.key < $1.key }.map { id, tierList in
            Finding(
                score: 100.0 + Double(tierList.count),
                line: "Cross-Tier Outlier `\(id)`: ⚠ flagged in \(tierList.count) tiers (\(tierList.joined(separator: ", "))) — priority tuning candidate",
            )
        }
    }

    private static func contrastFindings(_ rows: [PairedContrastSummary], kind: String) -> [Finding] {
        let flagged = rows.filter(\.flagged).sorted(by: BalanceContrastFlags.summarySort)
        var findings = Array(flagged.prefix(contrastCap)).map { row -> Finding in
            Finding(
                score: max(abs(row.lift), abs(row.meanDeltaPartyHP), abs(row.meanDeltaRounds) / 10),
                line: String(
                    format: "%@ `%@` vs `%@` on `%@` (%@, %@): ⚠ %@ · lift %+.1f pp · ΔHP %+.2f · Δrounds %+.1f · n=%d decided · timeouts %d/%d entity, %d/%d baseline",
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
                    row.decidedPairs,
                    row.entityTimeouts,
                    row.pairs,
                    row.baselineTimeouts,
                    row.pairs,
                ),
            )
        }
        let extra = max(0, flagged.count - contrastCap)
        if extra > 0 {
            findings.append(Finding(score: 0, line: "\(extra) more flagged \(kind) contrasts; see JSON."))
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
                    hotspot.flagReason ?? "",
                ),
            )
        }
    }
}
