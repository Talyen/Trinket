import Foundation

public extension BalanceSweepReport {
    static func merged(
        _ slices: [BalanceSweepReport],
        config: BalanceSweepConfig,
        policyID: String,
        elapsedSeconds: Double
    ) -> BalanceSweepReport {
        let progressionRecords = slices.flatMap(\.progressionRecords)
        return BalanceSweepReport(
            config: config,
            policyID: policyID,
            records: slices.flatMap(\.records),
            abilityContrasts: BalanceContrastSupport.mergeSummaries(
                slices.flatMap(\.abilityContrasts),
                threshold: config.peerDeltaFlagThreshold
            ),
            affixContrasts: BalanceContrastSupport.mergeSummaries(
                slices.flatMap(\.affixContrasts),
                threshold: config.peerDeltaFlagThreshold
            ),
            talentContrasts: BalanceContrastSupport.mergeSummaries(
                slices.flatMap(\.talentContrasts),
                threshold: config.peerDeltaFlagThreshold
            ),
            talentKitContrasts: BalanceContrastSupport.mergeSummaries(
                slices.flatMap(\.talentKitContrasts),
                threshold: config.peerDeltaFlagThreshold
            ),
            progressionHotspots: HotspotAnalyzer.analyze(records: progressionRecords),
            progressionRecords: progressionRecords,
            progressionPlayerStates: slices.flatMap(\.progressionPlayerStates),
            progressionTruncatedRuns: slices.reduce(0) { $0 + $1.progressionTruncatedRuns },
            elapsedSeconds: elapsedSeconds
        )
    }
}
