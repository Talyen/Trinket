public struct BalanceSweepReport: Codable, Sendable {
    public var config: BalanceSweepConfig
    public var policyID: String
    public var records: [BalanceBattleRecord] = []
    public var comparedPolicyID: String?
    public var comparedRecords: [BalanceBattleRecord] = []
    public var abilityContrasts: [PairedContrastSummary] = []
    public var affixContrasts: [PairedContrastSummary] = []
    public var talentContrasts: [PairedContrastSummary] = []
    public var talentKitContrasts: [PairedContrastSummary] = []
    public var progressionHotspots: [NodeHotspotSummary] = []
    public var progressionRecords: [ProgressionBattleRecord] = []
    public var progressionPlayerStates: [PlayerProgressionState] = []
    public var progressionTruncatedRuns = 0
    public var elapsedSeconds: Double

    /// The four contrast sections in canonical order. Both the markdown tables
    /// and the findings brief iterate this so a new contrast kind cannot be
    /// added to one and forgotten in the other.
    public var contrastSections: [(title: String, kind: String, rows: [PairedContrastSummary])] {
        [
            ("Ability Contrasts (paired lift vs sibling choice)", "ability", abilityContrasts),
            ("Affix Contrasts (empty-slot and replacement-affix baselines)", "affix", affixContrasts),
            ("Talent Contrasts (paired lift vs sibling in the same row)", "talent", talentContrasts),
            ("Talent Kit Contrasts (full kit vs none, legal point budget only)", "talent kit", talentKitContrasts),
        ]
    }

    /// Merges per-worker slice reports back into one report. Contrast
    /// summaries re-bucket through the parent config so worker-local flag
    /// thresholds cannot leak into the merged output.
    public static func merged(
        _ slices: [Self],
        config: BalanceSweepConfig,
        policyID: String,
        elapsedSeconds: Double,
    ) -> Self {
        let progressionRecords = slices.flatMap(\.progressionRecords)
        func merge(_ keyPath: KeyPath<Self, [PairedContrastSummary]>) -> [PairedContrastSummary] {
            BalanceContrastSupport.mergeSummaries(slices.flatMap { $0[keyPath: keyPath] }, config: config)
        }
        return Self(
            config: config,
            policyID: policyID,
            records: slices.flatMap(\.records),
            comparedPolicyID: slices.first(where: { $0.comparedPolicyID != nil })?.comparedPolicyID,
            comparedRecords: slices.flatMap(\.comparedRecords),
            abilityContrasts: merge(\.abilityContrasts),
            affixContrasts: merge(\.affixContrasts),
            talentContrasts: merge(\.talentContrasts),
            talentKitContrasts: merge(\.talentKitContrasts),
            progressionHotspots: HotspotAnalyzer.analyze(records: progressionRecords),
            progressionRecords: progressionRecords,
            progressionPlayerStates: slices.flatMap(\.progressionPlayerStates),
            progressionTruncatedRuns: slices.reduce(0) { $0 + $1.progressionTruncatedRuns },
            elapsedSeconds: elapsedSeconds,
        )
    }
}
