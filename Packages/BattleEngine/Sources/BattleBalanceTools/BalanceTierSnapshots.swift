import Foundation

/// Tier aggregation computed once per rendered report and shared by the brief
/// and full markdown views. Previously each view (and each section within the
/// brief) re-ran `summarize` over the same records, aggregating up to four
/// times per CLI invocation.
public struct BalanceTierSnapshots: Sendable {
    public let tiers: [BalanceTierStats]
    public let comparedTiers: [BalanceTierStats]

    public init(report: BalanceSweepReport) {
        tiers = BalanceStatsAggregator.summarize(report: report)
        comparedTiers = report.comparedPolicyID != nil && !report.comparedRecords.isEmpty
            ? BalanceStatsAggregator.summarize(report: report, records: report.comparedRecords)
            : []
    }
}
