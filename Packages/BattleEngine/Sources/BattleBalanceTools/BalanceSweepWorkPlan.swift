import Foundation
import TrinketContent

public struct BalanceSweepWorkerJob: Equatable, Sendable {
    public var mode: BalanceSweepMode
    public var offset: Int
    public var limit: Int

    public init(mode: BalanceSweepMode, offset: Int, limit: Int) {
        self.mode = mode
        self.offset = offset
        self.limit = limit
    }
}

public enum BalanceSweepWorkPlan {
    /// Per-mode chunk sizes: identity and contrast splits are balanced for
    /// worker-process waves, progression runs fewer, longer units.
    private static let modeChunks: [(mode: BalanceSweepMode, size: Int)] = [
        (.identity, 16),
        (.abilityContrast, 128),
        (.affixContrast, 128),
        (.talentContrast, 64),
        (.modeProgression, 4),
    ]

    public static let concreteModes: [BalanceSweepMode] = modeChunks.map(\.mode)

    static func workCount(for mode: BalanceSweepMode, config: BalanceSweepConfig) -> Int {
        switch mode {
        case .identity:
            config.tiers.count * config.resolvedRoster.enemies.count * config.battlesPerTier
        case .abilityContrast:
            BalanceAbilityContrastRunner.workCount(config: config)
        case .affixContrast:
            BalanceAffixContrastRunner.workCount(config: config)
        case .talentContrast:
            BalanceTalentContrastRunner.workCount(config: config)
        case .modeProgression:
            max(1, config.battlesPerTier)
        case .all:
            concreteModes.reduce(0) { $0 + workCount(for: $1, config: config) }
        }
    }

    public static func chunkRanges(workCount: Int, chunkSize: Int) -> [(offset: Int, limit: Int)] {
        guard workCount > 0 else { return [] }
        let size = max(1, chunkSize)
        var ranges: [(offset: Int, limit: Int)] = []
        var offset = 0
        while offset < workCount {
            let limit = min(size, workCount - offset)
            ranges.append((offset, limit))
            offset += limit
        }
        return ranges
    }

    public static func workerJobs(config: BalanceSweepConfig) -> [BalanceSweepWorkerJob] {
        let modes = config.mode == .all ? modeChunks : modeChunks.filter { $0.mode == config.mode }
        return modes.flatMap { mode, size in
            chunkRanges(
                workCount: workCount(for: mode, config: config),
                chunkSize: size,
            ).map { range in
                BalanceSweepWorkerJob(mode: mode, offset: range.offset, limit: range.limit)
            }
        }
    }
}
