import BattleBalanceTools
import Foundation
import Testing
@testable import BalanceSweepCLI

struct BalanceSweepCLITests {
    @Test func `CLI flags use the canonical configuration`() throws {
        #expect(try BalanceSweepCLI.parseInvocation([]).config == BalanceSweepConfig())
        #expect(try BalanceSweepCLI.parseInvocation(["--tiers", ""]).config.tiers == BalanceSweepConfig().tiers)
        let parsed = try BalanceSweepCLI.parseInvocation([
            "--mode", "affix-contrast", "--samples", "7", "--seed", "42", "--tiers", "mid,late",
            "--jobs", "3", "--max-rounds", "9", "--max-actions", "11", "--pacing", "off",
            "--policy", "setup-v1", "--policy-compare", "--work-offset", "0", "--work-limit", "2",
            "--hero", "knight", "--companion", "bear", "--enemy", "living_armor", "--focus", "keen",
            "--peer-delta", "0.21", "--duration-flag-rate", "0.31", "--comfort-hp", "0.41",
            "--comfort-rounds", "3.5", "--output-dir", "reports with spaces", "--full-markdown",
        ])
        #expect(parsed.config == BalanceSweepConfig(
            mode: .affixContrast, battlesPerTier: 7, seed: 42, tiers: [.middle, .lateGame],
            maxRounds: 9, maxActions: 11, peerDeltaFlagThreshold: 0.21, outputDirectory: "reports with spaces",
            jobs: 3, workOffset: 0, workLimit: 2, appliesFightPacing: false, policyID: "setup-v1",
            comparePolicies: true, heroIDs: ["knight"], companionIDs: ["bear"], enemyIDs: ["living_armor"],
            focusIDs: ["keen"], durationFlagRate: 0.31, comfortHPThreshold: 0.41, comfortRoundThreshold: 3.5,
        ))
        #expect(parsed.writeFullMarkdown)
    }

    @Test(arguments: [
        ["--samples", "0"], ["--jobs", "-1"], ["--work-offset", "-1"], ["--max-rounds", "oops"],
        ["--mode", "unknown"], ["--policy", "unknown"], ["--hero", "missing"], ["--seed"],
        ["--peer-delta", "nan"], ["--comfort-rounds", "1e999"],
    ])
    func `invalid CLI input remains rejected`(_ arguments: [String]) {
        #expect(throws: (any Error).self) { try BalanceSweepCLI.parseInvocation(arguments) }
    }

    @Test func `invalid pacing explains how to correct the argument`() {
        do {
            _ = try BalanceSweepCLI.parseInvocation(["--pacing", "2"])
            Issue.record("Unsupported pacing was accepted")
        } catch {
            #expect(String(describing: error) == "--pacing invalid value 2; use on or off")
        }
    }

    @Test func `worker preserves configuration and deterministic results`() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("worker config.json")
        let output = directory.appendingPathComponent("worker report.json")
        let config = BalanceSweepConfig(
            battlesPerTier: 3, seed: UInt64.max, tiers: [.early], maxRounds: 2, maxActions: 7,
            peerDeltaFlagThreshold: 0.23, outputDirectory: "reports with spaces", jobs: 1,
            workOffset: 1, workLimit: 1, appliesFightPacing: false, policyID: "setup-v1",
            comparePolicies: true, heroIDs: ["knight"], companionIDs: ["bear"], enemyIDs: ["living_armor"],
            focusIDs: ["ignored,by,identity"], durationFlagRate: 0.37, comfortHPThreshold: 0.43,
            comfortRoundThreshold: 4.5,
        )
        try JSONEncoder().encode(config).write(to: input)
        try BalanceSweepCLI.runWorker(configFile: input.path, outputFile: output.path)
        let report = try JSONDecoder().decode(BalanceSweepReport.self, from: Data(contentsOf: output))
        let direct = BalanceSweepRunner.run(config: config)
        #expect(report.config == config)
        #expect(report.records.count == 1)
        #expect(report.records == direct.records)
        #expect(report.comparedPolicyID == direct.comparedPolicyID)
        #expect(report.comparedRecords == direct.comparedRecords)

        var invalid = config
        invalid.mode = .all
        try JSONEncoder().encode(invalid).write(to: input)
        #expect(throws: (any Error).self) {
            try BalanceSweepCLI.runWorker(configFile: input.path, outputFile: output.path)
        }
        try Data("{}".utf8).write(to: input)
        #expect(throws: (any Error).self) {
            try BalanceSweepCLI.runWorker(configFile: input.path, outputFile: output.path)
        }
    }
}
