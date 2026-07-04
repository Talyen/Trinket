import Foundation

enum BalanceReportStyles {
    static let inlineBlock = """
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
