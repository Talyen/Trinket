import Foundation
import TrinketContent
import TrinketCore

public enum BalanceProgressionReportFormatter {
    public static func render(
        config: BalanceSweepConfig,
        hotspots: [NodeHotspotSummary],
        records: [ProgressionBattleRecord],
        playerStates: [PlayerProgressionState],
        truncatedRuns: Int = 0,
        elapsedSeconds: Double,
    ) -> String {
        var lines: [String] = []
        appendHeader(
            config: config,
            records: records,
            playerStates: playerStates,
            truncatedRuns: truncatedRuns,
            elapsedSeconds: elapsedSeconds,
            into: &lines,
        )
        appendSummary(hotspots: hotspots, playerStates: playerStates, into: &lines)
        appendFlaggedHotspots(hotspots.filter(\.isFlagged), into: &lines)
        appendModeDetails(hotspots: hotspots, into: &lines)
        return lines.joined(separator: "\n")
    }

    private static func appendHeader(
        config: BalanceSweepConfig,
        records: [ProgressionBattleRecord],
        playerStates: [PlayerProgressionState],
        truncatedRuns: Int,
        elapsedSeconds: Double,
        into lines: inout [String],
    ) {
        lines.append("# Multi-Mode Progression & Hotspot Balance Report")
        lines.append("")
        lines.append("- **Mode**: Mode Progression Simulation")
        lines.append("- **Seed**: \(config.seed)")
        lines.append("- **Simulated Runs**: \(playerStates.count)")
        lines.append("- **Total Battles Simulated**: \(records.count)")
        lines.append("- **Decided Battles**: \(records.count { $0.result.isDecided })")
        lines.append("- **Unfinished Battles**: \(records.count { $0.result.timedOut }) (excluded from win rates; investigate stalls)")
        lines.append("- **Elapsed Time**: \(String(format: "%.2f", elapsedSeconds))s")
        if truncatedRuns > 0 {
            lines
                .append(
                    "- **Truncated Runs**: \(truncatedRuns) (hit \(BalanceProgressionRunner.maxBattlesPerRun)-battle safety cap before completion)",
                )
        }
        lines.append("")
    }

    private static func appendSummary(
        hotspots: [NodeHotspotSummary],
        playerStates: [PlayerProgressionState],
        into lines: inout [String],
    ) {
        let avgEndLevel = playerStates.isEmpty ? 0 : Double(playerStates.map(\.heroLevel).reduce(0, +)) / Double(playerStates.count)
        lines.append("## Progression Summary")
        lines.append("")
        lines.append("| Metric | Value |")
        lines.append("| :--- | :--- |")
        lines.append("| Avg End Hero Level | \(String(format: "%.1f", avgEndLevel)) |")
        lines.append("| Total Mode Bounces (Level Walls) | \(playerStates.map(\.modeBounces).reduce(0, +)) |")
        lines.append("| Total Nodes Evaluated | \(hotspots.count) |")
        lines.append("| Difficulty Hotspots Flagged | \(hotspots.filter(\.isFlagged).count) |")
        lines.append("")
    }

    private static func cells(_ hotspot: NodeHotspotSummary)
        -> (win: String, confidence: String, player: String, enemy: String, power: String) {
        guard hotspot.battles > 0 else { return ("n/a", "n/a", "n/a", "n/a", "n/a") }
        return (
            String(format: "%.1f%%", hotspot.winRate * 100),
            String(format: "%.1f-%.1f%%", hotspot.wilsonLow * 100, hotspot.wilsonHigh * 100),
            String(format: "%.1f", hotspot.averagePlayerLevel),
            String(format: "%.1f", hotspot.averageEnemyLevel),
            String(format: "%.0f", hotspot.averageEnemyPowerRating),
        )
    }

    private static func appendFlaggedHotspots(
        _ flaggedHotspots: [NodeHotspotSummary],
        into lines: inout [String],
    ) {
        if flaggedHotspots.isEmpty {
            lines.append("## Difficulty Hotspots")
            lines.append("")
            lines.append("No difficulty hotspots flagged from the decided samples.")
            lines.append("")
            return
        }
        lines.append("## Difficulty Hotspots (<80% or >95% Win Rate)")
        lines.append("")
        lines.append("| Mode | Location | Step | Enemy | Win Rate | Player Lvl | Enemy Lvl | Power | Status | Reason |")
        lines.append("| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |")
        for hotspot in flaggedHotspots {
            let c = cells(hotspot)
            lines
                .append(
                    "| \(hotspot.step.mode.displayName) | \(hotspot.step.containerTitle) | \(hotspot.step.displayTitle) | \(hotspot.step.enemyID) | \(c.win) | \(c.player) | \(c.enemy) | \(c.power) | **\(hotspot.status.displayName)** | \(hotspot.flagReason ?? "-") |",
                )
        }
        lines.append("")
    }

    private static func appendModeDetails(
        hotspots: [NodeHotspotSummary],
        into lines: inout [String],
    ) {
        for mode in SimulationGameMode.allCases {
            let modeHotspots = hotspots.filter { $0.step.mode == mode }
            guard !modeHotspots.isEmpty else { continue }
            lines.append("## \(mode.displayName) Progression Detail")
            lines.append("")
            lines.append("| Location | Step | Enemy | Decided Battles | Win Rate | CI (95%) | Player Lvl | Enemy Lvl | Power | Status |")
            lines.append("| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |")
            for hotspot in modeHotspots {
                let c = cells(hotspot)
                lines
                    .append(
                        "| \(hotspot.step.containerTitle) | \(hotspot.step.displayTitle) | \(hotspot.step.enemyID) | \(hotspot.battles) | \(c.win) | \(c.confidence) | \(c.player) | \(c.enemy) | \(c.power) | \(hotspot.battles == 0 ? "NO DECIDED SAMPLES" : hotspot.status.displayName) |",
                    )
            }
            lines.append("")
        }
    }
}
