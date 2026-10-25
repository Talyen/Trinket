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
        lines.append("- Win-rate goals: \(BalanceEncounterTargets.winGoalDescription)")
        lines.append("- Peer Δ / lift threshold: `\(Int(report.config.peerDeltaFlagThreshold * 100)) pp`")
        lines.append("- Material stall rate: `\(report.config.resolvedStallFlagRate * 100)%`")
        lines
            .append(
                "- Duration goals: regular `\(BalanceDurationThresholds.trashGoalBand)`, boss `\(BalanceDurationThresholds.bossGoalBand)` rounds",
            )
        lines.append("- Fight pacing: `\(report.config.appliesFightPacing ? "on" : "off")`")
        if !report.contrastSections.allSatisfy(\.rows.isEmpty) {
            lines.append("- Contrast builds: `\(report.config.usesTierTalents ? "tier-legal talents" : "minimal talents (diagnostic)")`")
        }
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
            lines
                .append(
                    "- Progression uses fixed parties, all Spires, seeded floor modifiers, and Easy Contract recovery. Equipment model: \(report.config.progressionEquipmentDescription). Labyrinth samples ten depths.",
                )
            lines.append("")
        }
    }

    private static func snapshotLine(_ tier: BalanceTierStats, report: BalanceSweepReport, comparedTiers: [BalanceTierStats]) -> String {
        let winPct = BalanceStatsAggregator.winPercent(wins: tier.wins, decided: tier.decidedBattles)
        var line = String(
            format: "- %@: %ld battles, %.1f%% win, %ld timeouts, avg %.1f rounds",
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
        var evidenceByTier: [SimulationPowerTier: EnemyEvidence] = [:]
        for record in report.records {
            evidenceByTier[record.tier, default: EnemyEvidence()].record(record)
        }
        for tier in snapshots.tiers where tier.battles > 0 {
            let evidence = evidenceByTier[tier.tier] ?? EnemyEvidence()
            findings.append(contentsOf: identityFindings(tier: tier, evidence: evidence))
            findings.append(contentsOf: stallFindings(tier: tier, evidence: evidence, threshold: report.config.resolvedStallFlagRate))
        }
        for section in report.contrastSections {
            findings.append(contentsOf: contrastFindings(section.rows, kind: section.kind))
        }
        findings.append(contentsOf: progressionFindings(report.progressionHotspots))
        let unfinished = report.progressionRecords.count { $0.result.timedOut }
        if unfinished > 0 {
            let label = Double(unfinished) / Double(report.progressionRecords.count) >= report.config.resolvedStallFlagRate
                ? "STALL" : "UNFINISHED"
            findings.append(Finding(
                score: 1,
                line: "Progression: ⚠ \(label) · \(unfinished)/\(report.progressionRecords.count) battles reached a simulation cap; win rates exclude these unfinished fights.",
            ))
        }
        if report.progressionTruncatedRuns > 0 {
            findings.append(Finding(
                score: 1,
                line: "Progression: ⚠ INCOMPLETE · \(report.progressionTruncatedRuns)/\(report.progressionPlayerStates.count) runs ended before advancing content completed.",
            ))
        }
        findings.append(contentsOf: crossTierFindings(tiers: snapshots.tiers))
        return findings.sorted {
            $0.score != $1.score ? $0.score > $1.score : $0.line < $1.line
        }
    }
}

extension BalanceFindingsReporter {
    private struct EnemyEvidence {
        struct Enemy {
            var battles = 0
            var stalls = 0
            var abilities: Set<String> = []
            let traits: [String]
        }

        var enemies: [String: Enemy] = [:]
        var abilityOwnerCounts: [String: Int] = [:]

        mutating func record(_ record: BalanceBattleRecord) {
            enemies[record.enemyID, default: Enemy(traits: record.enemyTraitIDs)].battles += 1
            if record.result.timedOut {
                enemies[record.enemyID]?.stalls += 1
            }
            for id in record.enemyAbilityIDs where enemies[record.enemyID]?.abilities.insert(id).inserted == true {
                abilityOwnerCounts[id, default: 0] += 1
            }
        }

        func explanation(for enemyID: String) -> String {
            guard let enemy = enemies[enemyID] else { return "identity vs \(enemyID)" }
            let unique = enemy.abilities.filter { abilityOwnerCounts[$0] == 1 }.sorted()
            if !unique.isEmpty {
                return "only enemy with " + unique.map { "`\($0)`" }.joined(separator: ", ")
            }
            if !enemy.traits.isEmpty {
                return "traits " + enemy.traits.map { "`\($0)`" }.joined(separator: ", ")
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
        findings += pairingFindings(tier.heroCompanionCells, labels: ("hero", "companion"), tier: tier.tier)
        findings += pairingFindings(tier.heroEnemyCells, labels: ("hero", "enemy"), tier: tier.tier)
        return findings
    }

    private static func stallFindings(tier: BalanceTierStats, evidence: EnemyEvidence, threshold: Double) -> [Finding] {
        evidence.enemies.sorted { $0.key < $1.key }.compactMap { enemyID, enemy in
            guard enemy.stalls > 0 else { return nil }
            let label = Double(enemy.stalls) / Double(enemy.battles) >= threshold ? "STALL" : "UNFINISHED"
            return Finding(
                score: Double(enemy.stalls) / Double(enemy.battles),
                line: "Enemy `\(enemyID)` (\(tier.tier.displayName)): ⚠ \(label) · "
                    + "\(enemy.stalls)/\(enemy.battles) battles reached a simulation cap; "
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
                    format: "%@ `%@` (%@): ⚠ %@ · %.1f%% win [%.1f–%.1f] · n=%ld · %+.1f pp · %@",
                    kind.capitalized,
                    row.id,
                    row.ownerID.map { "\(tier.displayName), on `\($0)`" } ?? tier.displayName,
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
        // Identity aggregation already emits only flagged cells, ranked by absolute delta.
        cells.prefix(pairingCap).map { cell in
            Finding(
                score: abs(cell.deltaVsPeer) * 0.5,
                line: String(
                    format: "%@ `%@` × %@ `%@` (%@): ⚠ %@ · %.1f%% win · n=%ld · %+.1f pp · pairing outlier",
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
                id: row.enemyID, kind: row.isBoss ? "Boss" : "Enemy",
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
                format: "%@ `%@` (%@ duration): ⚠ %@ · avg %.1f rounds · SHORT %.0f%% · LONG %.0f%% · n=%ld",
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
        var enemyFlags: [String: Set<SimulationPowerTier>] = [:]
        for tier in activeTiers {
            for enemy in tier.enemies where enemy.flagged {
                enemyFlags[enemy.id, default: []].insert(tier.tier)
            }
        }
        return enemyFlags.filter { $0.value.count >= 2 }.sorted { $0.key < $1.key }.map { id, tierList in
            let labels = SimulationPowerTier.allCases.filter(tierList.contains).map(\.displayName).joined(separator: ", ")
            return Finding(
                score: 100.0 + Double(tierList.count),
                line: "Cross-Tier Outlier `\(id)`: ⚠ flagged in \(tierList.count) tiers (\(labels)) — priority tuning candidate",
            )
        }
    }

    private static func contrastFindings(_ rows: [PairedContrastSummary], kind: String) -> [Finding] {
        let flagged = rows.filter(\.flagged).sorted(by: BalanceContrastFlags.summarySort)
        var findings = Array(flagged.prefix(contrastCap)).map { row -> Finding in
            Finding(
                score: max(abs(row.lift), abs(row.meanDeltaPartyHP), abs(row.meanDeltaRounds) / 10),
                line: String(
                    format: "%@ `%@` vs `%@` on `%@` (%@, %@): ⚠ %@ · lift %+.1f pp · ΔHP %+.2f · Δrounds %+.1f · n=%ld decided · timeouts %ld/%ld entity, %ld/%ld baseline",
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
            let band = BalanceEncounterTargets.winBand(isBoss: hotspot.step.isBoss)
            let envelope: Double = switch hotspot.status {
            case .overtuned, .levelGapWall:
                band.lower - hotspot.winRate
            case .undertuned:
                hotspot.winRate - band.upper
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
