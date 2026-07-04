import Foundation

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
        html.append(styleBlock)
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
        html.append(anomalySection(result))
        html.append(matchupSection(result))
        html.append(bossSection(result))
        html.append(abilitySection(result))

        html.append("</body>")
        html.append("</html>")
        return html.joined(separator: "\n")
    }

    public static func renderJSON(_ result: BalanceSweepResult) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(BalanceSweepReportExport(result: result))
    }

    private static var styleBlock: String {
        """
        <style>
          :root { color-scheme: light dark; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
          body { margin: 2rem auto; max-width: 1200px; line-height: 1.45; padding: 0 1rem; }
          h1, h2 { line-height: 1.2; }
          .meta { color: #666; }
          table { border-collapse: collapse; width: 100%; margin: 1rem 0 2rem; font-size: 0.92rem; }
          th, td { border: 1px solid #ccc; padding: 0.4rem 0.55rem; text-align: left; }
          th { background: #f4f4f4; position: sticky; top: 0; }
          tr.anomaly td { color: #c00; font-weight: 600; }
          tr.warning td { color: #b35c00; font-weight: 600; }
          .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 0.75rem; }
          .card { border: 1px solid #ccc; border-radius: 8px; padding: 0.75rem 1rem; background: #fafafa; }
          .card strong { display: block; font-size: 1.35rem; }
          ul.anomalies { padding-left: 1.2rem; }
          ul.anomalies li.anomaly { color: #c00; font-weight: 600; }
          ul.anomalies li.warning { color: #b35c00; font-weight: 600; }
        </style>
        """
    }

    private static func summarySection(_ result: BalanceSweepResult) -> String {
        var cards: [String] = []
        for tier in result.request.tiers {
            let rows = result.matchupRows.filter { $0.tier == tier }
            guard !rows.isEmpty else { continue }
            let averageWinRate = rows.map(\.winRate).reduce(0, +) / Double(rows.count)
            let inTargetBand = rows.filter { $0.winRate >= 0.90 && $0.winRate <= 0.99 }.count
            let timeoutRows = rows.filter { $0.tickLimitCount > 0 }.count
            cards.append("""
            <div class="card">
              <span>\(escape(tier.displayName))</span>
              <strong>\(percent(averageWinRate))</strong>
              <span>avg win rate · \(rows.count) rows</span>
              <span>\(inTargetBand) in 90–99% band · \(timeoutRows) timeout rows</span>
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
        let rows = result.matchupRows.filter { !$0.isBoss }
        return tableSection(
            title: "Matchups (Non-Boss)",
            headers: ["Tier", "Hero", "Pet", "Enemy", "Sample", "Win Rate", "Timeouts", "Avg Ticks"],
            bodyRows: rows.map { row in
                let rowClass = anomalyClass(for: row, anomalies: result.anomalies)
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
        let rows = result.matchupRows.filter(\.isBoss)
        guard !rows.isEmpty else { return "" }

        return tableSection(
            title: "Boss Matchups",
            headers: ["Tier", "Hero", "Pet", "Boss", "Sample", "Win Rate", "Timeouts", "Avg Ticks"],
            bodyRows: rows.map { row in
                let rowClass = anomalyClass(for: row, anomalies: result.anomalies)
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

    private static func abilitySection(_ result: BalanceSweepResult) -> String {
        tableSection(
            title: "Ability Comparisons",
            headers: ["Tier", "Combatant", "Slot", "Ability", "Sibling", "Win Rate", "Samples"],
            bodyRows: result.abilityRows.map { row in
                let rowClass = abilityAnomalyClass(for: row, anomalies: result.anomalies)
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

    private static func anomalyClass(for row: MatchupSweepRow, anomalies: [BalanceAnomaly]) -> String {
        let key = "\(row.tier.displayName): \(row.heroID)+\(row.petID) vs \(row.enemyID)"
        if anomalies.contains(where: { $0.severity == .critical && $0.detail.contains(key) }) {
            return "anomaly"
        }
        return ""
    }

    private static func abilityAnomalyClass(for row: AbilityComparisonRow, anomalies: [BalanceAnomaly]) -> String {
        let needle = "\(row.combatantName) \(row.abilityTier.rawValue) \(row.abilityName)"
        if anomalies.contains(where: { $0.kind == .underpoweredAbility && $0.detail.contains(needle) }) {
            return "anomaly"
        }
        if anomalies.contains(where: { $0.kind == .overpoweredAbility && $0.detail.contains(needle) }) {
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

private struct BalanceSweepReportExport: Codable {
    let request: BalanceSweepRequestExport
    let matchupRows: [MatchupSweepRowExport]
    let abilityRows: [AbilityComparisonRowExport]
    let anomalies: [BalanceAnomalyExport]
    let generatedAt: Date

    init(result: BalanceSweepResult) {
        request = BalanceSweepRequestExport(request: result.request)
        matchupRows = result.matchupRows.map(MatchupSweepRowExport.init)
        abilityRows = result.abilityRows.map(AbilityComparisonRowExport.init)
        anomalies = result.anomalies.map(BalanceAnomalyExport.init)
        generatedAt = result.generatedAt
    }
}

private struct MatchupSweepRowExport: Codable {
    let tier: String
    let heroID: String
    let petID: String
    let enemyID: String
    let isBoss: Bool
    let loadoutSampleIndex: Int
    let winCount: Int
    let tickLimitCount: Int
    let runCount: Int
    let winRate: Double
    let tickLimitRate: Double
    let averageTickCount: Double
    let averageActionCount: Double

    init(_ row: MatchupSweepRow) {
        tier = row.tier.rawValue
        heroID = row.heroID
        petID = row.petID
        enemyID = row.enemyID
        isBoss = row.isBoss
        loadoutSampleIndex = row.loadoutSampleIndex
        winCount = row.winCount
        tickLimitCount = row.tickLimitCount
        runCount = row.runCount
        winRate = row.winRate
        tickLimitRate = row.tickLimitRate
        averageTickCount = row.averageTickCount
        averageActionCount = row.averageActionCount
    }
}

private struct AbilityComparisonRowExport: Codable {
    let tier: String
    let combatantID: String
    let combatantName: String
    let abilityTier: String
    let abilityID: String
    let abilityName: String
    let siblingAbilityID: String
    let siblingAbilityName: String
    let winCount: Int
    let lossCount: Int
    let winRate: Double

    init(_ row: AbilityComparisonRow) {
        tier = row.tier.rawValue
        combatantID = row.combatantID
        combatantName = row.combatantName
        abilityTier = row.abilityTier.rawValue
        abilityID = row.abilityID
        abilityName = row.abilityName
        siblingAbilityID = row.siblingAbilityID
        siblingAbilityName = row.siblingAbilityName
        winCount = row.winCount
        lossCount = row.lossCount
        winRate = row.winRate
    }
}

private struct BalanceSweepRequestExport: Codable {
    let tiers: [String]
    let runsPerMatchup: Int
    let loadoutSamplesPerMatchup: Int
    let baseSeed: UInt64
    let includeAbilityAnalysis: Bool
    let representativeHeroID: String
    let representativePetID: String
    let maxTicks: Int
    let tripleCount: Int

    init(request: BalanceSweepRequest) {
        tiers = request.tiers.map(\.rawValue)
        runsPerMatchup = request.runsPerMatchup
        loadoutSamplesPerMatchup = request.loadoutSamplesPerMatchup
        baseSeed = request.baseSeed
        includeAbilityAnalysis = request.includeAbilityAnalysis
        representativeHeroID = request.representativeHeroID
        representativePetID = request.representativePetID
        maxTicks = request.maxTicks
        tripleCount = request.triples?.count ?? BalanceSweepCatalog.allTriples().count
    }
}

private struct BalanceAnomalyExport: Codable {
    let kind: String
    let severity: String
    let detail: String
    let value: Double

    init(_ anomaly: BalanceAnomaly) {
        kind = anomaly.kind.rawValue
        severity = anomaly.severity.rawValue
        detail = anomaly.detail
        value = anomaly.value
    }
}
