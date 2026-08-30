import Foundation

public extension BalanceSweepReport {
    static func merged(
        _ slices: [BalanceSweepReport],
        config: BalanceSweepConfig,
        policyID: String,
        elapsedSeconds: Double,
    ) -> BalanceSweepReport {
        let progressionRecords = slices.flatMap(\.progressionRecords)
        return BalanceSweepReport(
            config: config,
            policyID: policyID,
            records: slices.flatMap(\.records),
            comparedPolicyID: slices.first(where: { $0.comparedPolicyID != nil })?.comparedPolicyID,
            comparedRecords: slices.flatMap(\.comparedRecords),
            abilityContrasts: BalanceContrastSupport.mergeSummaries(
                slices.flatMap(\.abilityContrasts),
                config: config,
            ),
            affixContrasts: BalanceContrastSupport.mergeSummaries(
                slices.flatMap(\.affixContrasts),
                config: config,
            ),
            talentContrasts: BalanceContrastSupport.mergeSummaries(
                slices.flatMap(\.talentContrasts),
                config: config,
            ),
            talentKitContrasts: BalanceContrastSupport.mergeSummaries(
                slices.flatMap(\.talentKitContrasts),
                config: config,
            ),
            progressionHotspots: HotspotAnalyzer.analyze(records: progressionRecords),
            progressionRecords: progressionRecords,
            progressionPlayerStates: slices.flatMap(\.progressionPlayerStates),
            progressionTruncatedRuns: slices.reduce(0) { $0 + $1.progressionTruncatedRuns },
            elapsedSeconds: elapsedSeconds,
        )
    }
}
