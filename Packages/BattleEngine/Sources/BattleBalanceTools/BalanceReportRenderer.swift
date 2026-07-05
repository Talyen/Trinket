import Foundation
import BattleEngine

public enum BalanceReportRenderer {
    public struct Options: Equatable, Sendable {
        public let title: String
        public let gitSHA: String?

        public init(title: String = "Trinket Balance Sweep Report", gitSHA: String? = nil) {
            self.title = title
            self.gitSHA = gitSHA
        }
    }

    public static func renderHTML(
        _ result: BalanceSweepResult,
        options: Options = Options()
    ) -> String {
        var html: [String] = []
        html.append("<!DOCTYPE html>")
        html.append("<html lang=\"en\">")
        html.append("<head>")
        html.append("<meta charset=\"utf-8\">")
        html.append("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">")
        html.append("<title>\(escape(options.title))</title>")
        html.append(BalanceReportStyles.inlineBlock)
        html.append("</head>")
        html.append("<body>")
        html.append("<header>")
        html.append("<h1>\(escape(options.title))</h1>")
        html.append("<p class=\"meta\">Generated \(escape(iso8601(result.generatedAt)))")
        if let gitSHA = options.gitSHA {
            html.append(" · Git \(escape(gitSHA))")
        }
        html.append(" · \(result.matchupRows.count) matchup rows · \(result.abilityRows.count) ability comparisons")
        html.append(" · \(result.anomalies.count) anomalies")
        html.append("</p>")
        html.append("</header>")

        html.append(summarySection(result))
        html.append(kpiSection(result))
        html.append(gateSection(result))
        html.append(anomalySection(result))
        html.append(matchupSection(result))
        html.append(bossSection(result))
        html.append(abilitySection(result))

        html.append("</body>")
        html.append("</html>")
        return html.joined(separator: "\n")
    }

    public static func renderJSON(_ result: BalanceSweepResult) throws -> Data {
        try BalanceReportJSONExporter.render(result)
    }

    private static func summarySection(_ result: BalanceSweepResult) -> String {
        var cards: [String] = []
        for tierRaw in result.request.tiers {
            guard let tier = SimulationPowerTier(rawValue: tierRaw) else { continue }
            let rows = result.matchupRows.filter { $0.tier == tier }
            guard !rows.isEmpty else { continue }
            let averageWinRate = rows.map(\.winRate).reduce(0, +) / Double(rows.count)
            let inTargetBand = rows.filter { row in
                let band = AnomalyDetector.targetBand(for: row)
                return row.winRate >= band.min && row.winRate <= band.max
            }.count
            let timeoutRows = rows.filter { $0.tickLimitCount > 0 }.count
            let targetLabel = roleTargetSummary(for: tier)
            cards.append("""
            <div class="card">
              <span>\(escape(tier.displayName))</span>
              <strong>\(percent(averageWinRate))</strong>
              <span>avg win rate · \(rows.count) rows</span>
              <span>\(inTargetBand) in target band (\(escape(targetLabel))) · \(timeoutRows) timeout rows</span>
            </div>
            """)
        }

        return """
        <section>
          <h2>Summary</h2>
          <div class="summary-grid">\(cards.joined())</div>
        </section>
        """
    }

    private static func kpiSection(_ result: BalanceSweepResult) -> String {
        let kpis = result.kpis
        var cards: [String] = []
        cards.append("""
        <div class="card">
          <span>Overall</span>
          <strong>\(percent(kpis.inBandRate))</strong>
          <span>in band · \(percent(kpis.perfectWinRate)) perfect wins</span>
          <span>\(percent(kpis.durationInBandRate)) duration in 10–100 ticks</span>
        </div>
        """)

        for tierRaw in result.request.tiers {
            guard let tierKPI = kpis.byTier[tierRaw] else { continue }
            let tierName = SimulationPowerTier(rawValue: tierRaw)?.displayName ?? tierRaw
            cards.append("""
            <div class="card">
              <span>\(escape(tierName))</span>
              <strong>\(percent(tierKPI.inBandRate))</strong>
              <span>in band · \(percent(tierKPI.perfectWinRate)) perfect wins</span>
              <span>\(percent(tierKPI.durationInBandRate)) duration in band</span>
            </div>
            """)
        }

        return """
        <section>
          <h2>KPIs</h2>
          <div class="summary-grid">\(cards.joined())</div>
        </section>
        """
    }

    private static func gateSection(_ result: BalanceSweepResult) -> String {
        guard !result.gateViolations.isEmpty else {
            return "<section><h2>Balance Gate</h2><p>All CI gate thresholds passed.</p></section>"
        }

        let items = result.gateViolations.map { violation in
            "<li class=\"anomaly\">\(escape(violation.detail))</li>"
        }.joined()

        return """
        <section>
          <h2>Balance Gate</h2>
          <ul class="anomalies">\(items)</ul>
        </section>
        """
    }

    private static func roleTargetSummary(for tier: SimulationPowerTier) -> String {
        let fodder = AnomalyDetector.targetBand(tier: tier, role: .fodder)
        let elite = AnomalyDetector.targetBand(tier: tier, role: .elite)
        let boss = AnomalyDetector.targetBand(tier: tier, role: .boss)
        return "fodder \(percent(fodder.min))–\(percent(fodder.max)), elite \(percent(elite.min))–\(percent(elite.max)), boss \(percent(boss.min))–\(percent(boss.max))"
    }

    private static func anomalySection(_ result: BalanceSweepResult) -> String {
        guard !result.anomalies.isEmpty else {
            return "<section><h2>Anomalies</h2><p>No anomalies detected.</p></section>"
        }

        let items = result.anomalies.map { anomaly in
            let className = anomaly.severity == .critical ? "anomaly" : "warning"
            return "<li class=\"\(className)\">[\(escape(anomaly.kind.rawValue))] \(escape(anomaly.detail))</li>"
        }.joined()

        return """
        <section>
          <h2>Anomalies</h2>
          <ul class="anomalies">\(items)</ul>
        </section>
        """
    }

    private static func matchupSection(_ result: BalanceSweepResult) -> String {
        let rows = result.matchupRows.filter { !$0.isBoss && !$0.isElite }
        return tableSection(
            title: "Matchups (Non-Boss)",
            headers: ["Tier", "Hero", "Pet", "Enemy", "Sample", "Win Rate", "Timeouts", "Avg Ticks"],
            bodyRows: rows.map { row in
                let rowClass = anomalyClass(for: row.id, anomalies: result.anomalies, criticalOnly: true)
                return """
                <tr class=\"\(rowClass)\">
                  <td>\(escape(row.tier.displayName))</td>
                  <td>\(escape(row.heroID))</td>
                  <td>\(escape(row.petID))</td>
                  <td>\(escape(row.enemyID))</td>
                  <td>\(row.loadoutSampleIndex)</td>
                  <td>\(percent(row.winRate))</td>
                  <td>\(row.tickLimitCount)/\(row.runCount)</td>
                  <td>\(String(format: "%.1f", row.averageTickCount))</td>
                </tr>
                """
            }
        )
    }

    private static func bossSection(_ result: BalanceSweepResult) -> String {
        let rows = result.matchupRows.filter { $0.isBoss || $0.isElite }
        guard !rows.isEmpty else { return "" }

        return tableSection(
            title: "Boss & Elite Matchups",
            headers: ["Tier", "Hero", "Pet", "Enemy", "Kind", "Sample", "Win Rate", "Timeouts", "Avg Ticks"],
            bodyRows: rows.map { row in
                let rowClass = anomalyClass(for: row.id, anomalies: result.anomalies, criticalOnly: true)
                let kind = row.isBoss ? "Boss" : "Elite"
                return """
                <tr class=\"\(rowClass)\">
                  <td>\(escape(row.tier.displayName))</td>
                  <td>\(escape(row.heroID))</td>
                  <td>\(escape(row.petID))</td>
                  <td>\(escape(row.enemyID))</td>
                  <td>\(kind)</td>
                  <td>\(row.loadoutSampleIndex)</td>
                  <td>\(percent(row.winRate))</td>
                  <td>\(row.tickLimitCount)/\(row.runCount)</td>
                  <td>\(String(format: "%.1f", row.averageTickCount))</td>
                </tr>
                """
            }
        )
    }

    private static func abilitySection(_ result: BalanceSweepResult) -> String {
        tableSection(
            title: "Ability Comparisons",
            headers: ["Tier", "Combatant", "Slot", "Ability", "Sibling", "Win Rate", "Samples"],
            bodyRows: result.abilityRows.map { row in
                let rowClass = abilityAnomalyClass(for: row.id, anomalies: result.anomalies)
                return """
                <tr class=\"\(rowClass)\">
                  <td>\(escape(row.tier.displayName))</td>
                  <td>\(escape(row.combatantName))</td>
                  <td>\(escape(row.abilityTier.rawValue))</td>
                  <td>\(escape(row.abilityName))</td>
                  <td>\(escape(row.siblingAbilityName))</td>
                  <td>\(percent(row.winRate))</td>
                  <td>\(row.sampleCount)</td>
                </tr>
                """
            }
        )
    }

    private static func tableSection(title: String, headers: [String], bodyRows: [String]) -> String {
        let headerHTML = headers.map { "<th>\(escape($0))</th>" }.joined()
        return """
        <section>
          <h2>\(escape(title))</h2>
          <table>
            <thead><tr>\(headerHTML)</tr></thead>
            <tbody>\(bodyRows.joined())</tbody>
          </table>
        </section>
        """
    }

    private static func anomalyClass(
        for subjectID: String,
        anomalies: [BalanceAnomaly],
        criticalOnly: Bool
    ) -> String {
        if anomalies.contains(where: { $0.subjectID == subjectID && $0.severity == .critical }) {
            return "anomaly"
        }
        if !criticalOnly,
           anomalies.contains(where: { $0.subjectID == subjectID && $0.severity == .warning }) {
            return "warning"
        }
        return ""
    }

    private static func abilityAnomalyClass(for subjectID: String, anomalies: [BalanceAnomaly]) -> String {
        if anomalies.contains(where: { $0.subjectID == subjectID && $0.kind == .underpoweredAbility }) {
            return "anomaly"
        }
        if anomalies.contains(where: { $0.subjectID == subjectID && $0.kind == .overpoweredAbility }) {
            return "warning"
        }
        return ""
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private static func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
