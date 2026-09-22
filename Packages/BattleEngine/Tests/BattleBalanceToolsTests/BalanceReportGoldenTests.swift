import BattleEngine
import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import BattleBalanceTools

/// Pins dev-facing balance-sweep behavior for a fixed small sweep: the encoded
/// report (records, sampling seeds, contrast summaries), the findings brief,
/// and the full markdown. Fingerprints keep the guard compact while failing on
/// any drift. Late-tier sims need the main-actor stack, matching the
/// sweep-report suite.
@Suite(.serialized)
@MainActor
struct BalanceReportGoldenTests {
    private static func config(
        mode: BalanceSweepMode,
        tiers: [SimulationPowerTier] = [.early],
        samples: Int = 2,
        focus: [String] = [],
    ) -> BalanceSweepConfig {
        BalanceSweepConfig(
            mode: mode,
            battlesPerTier: samples,
            seed: 7,
            tiers: tiers,
            jobs: 1,
            heroIDs: ["knight"],
            companionIDs: ["bear"],
            enemyIDs: ["living_armor"],
            focusIDs: focus,
        )
    }

    /// Line-sorted before hashing: a few within-owner rows tie on delta, and raw
    /// text order for ties is not stable across processes. Content drift still
    /// fails the fingerprint.
    private static func fingerprint(_ config: BalanceSweepConfig) -> UInt64 {
        var report = BalanceSweepRunner.run(config: config)
        report.elapsedSeconds = 0
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(report)) ?? Data()
        let encoded = String(bytes: data, encoding: .utf8) ?? ""
        let combined = encoded
            + "\n=====FINDINGS=====\n" + BalanceFindingsReporter.render(report)
            + "\n=====FULL=====\n" + BalanceMarkdownReporter.render(report)
        let canonical = combined.split(separator: "\n", omittingEmptySubsequences: false)
            .sorted()
            .joined(separator: "\n")
        return BalanceContrastSupport.stableHash64(canonical)
    }

    @Test func `identity sweep is stable`() {
        #expect(Self.fingerprint(Self.config(mode: .identity)) == 16754792888666914513)
    }

    @Test func `ability contrast is stable`() {
        #expect(Self.fingerprint(Self.config(mode: .abilityContrast, focus: ["bash"])) == 3079539857308988172)
    }

    @Test func `affix contrast is stable`() {
        #expect(Self.fingerprint(Self.config(mode: .affixContrast, focus: ["keen"])) == 17055917146136054903)
    }

    @Test func `talent contrast is stable`() {
        let config = Self.config(
            mode: .talentContrast,
            tiers: [.middle, .lateGame],
            samples: 1,
            focus: ["knight_block_t1_1", "full-kit"],
        )
        #expect(Self.fingerprint(config) == 10121275086951025619)
    }
}
