import Foundation
import TrinketContent
import TrinketCore

public enum BalanceSweepMode: String, CaseIterable, Codable, Sendable {
    case identity
    case abilityContrast = "ability-contrast"
    case affixContrast = "affix-contrast"
    case all
}

public struct BalanceSweepConfig: Equatable, Sendable {
    public var mode: BalanceSweepMode
    public var battlesPerTier: Int
    public var seed: UInt64
    public var tiers: [SimulationPowerTier]
    public var maxRounds: Int
    public var maxActions: Int
    public var peerDeltaFlagThreshold: Double
    public var outputDirectory: String
    /// Concurrent battle workers. `1` = sequential; `0` = use active processor count.
    public var jobs: Int

    public static let defaultBattlesPerTier = 1000
    public static let defaultOutputDirectory = "BalanceSweepReports"

    public init(
        mode: BalanceSweepMode = .identity,
        battlesPerTier: Int = defaultBattlesPerTier,
        seed: UInt64 = 1,
        tiers: [SimulationPowerTier] = SimulationPowerTier.allCases,
        maxRounds: Int = BattleSimulator.defaultMaxRounds,
        maxActions: Int = BattleSimulator.defaultMaxActions,
        peerDeltaFlagThreshold: Double = 0.10,
        outputDirectory: String = defaultOutputDirectory,
        jobs: Int = 0
    ) {
        self.mode = mode
        self.battlesPerTier = max(1, battlesPerTier)
        self.seed = seed
        self.tiers = tiers.isEmpty ? SimulationPowerTier.allCases : tiers
        self.maxRounds = maxRounds
        self.maxActions = maxActions
        self.peerDeltaFlagThreshold = peerDeltaFlagThreshold
        self.outputDirectory = outputDirectory
        self.jobs = max(0, jobs)
    }

    public var resolvedJobs: Int {
        if jobs <= 0 {
            return max(1, ProcessInfo.processInfo.activeProcessorCount)
        }
        return jobs
    }
}

public struct BalanceBattleRecord: Equatable, Sendable {
    public var tier: SimulationPowerTier
    public var heroID: String
    public var petID: String
    public var enemyID: String
    public var isBossOrElite: Bool
    public var heroAbilityIDs: [String]
    public var petAbilityIDs: [String]
    public var affixIDs: [String]
    public var seed: UInt64
    public var result: BattleSimResult
}

public struct PairedContrastSummary: Equatable, Sendable {
    public var entityID: String
    public var baselineID: String
    public var ownerID: String
    public var tier: SimulationPowerTier
    public var pairs: Int
    public var winsWithEntity: Int
    public var winsWithBaseline: Int
    public var lift: Double
    public var flagged: Bool
    public var flagReason: String?

    public var entityWinRate: Double {
        pairs == 0 ? 0 : Double(winsWithEntity) / Double(pairs)
    }

    public var baselineWinRate: Double {
        pairs == 0 ? 0 : Double(winsWithBaseline) / Double(pairs)
    }
}

public struct BalanceSweepReport: Sendable {
    public var config: BalanceSweepConfig
    public var policyID: String
    public var records: [BalanceBattleRecord]
    public var abilityContrasts: [PairedContrastSummary]
    public var affixContrasts: [PairedContrastSummary]
    public var elapsedSeconds: Double

    public init(
        config: BalanceSweepConfig,
        policyID: String,
        records: [BalanceBattleRecord] = [],
        abilityContrasts: [PairedContrastSummary] = [],
        affixContrasts: [PairedContrastSummary] = [],
        elapsedSeconds: Double
    ) {
        self.config = config
        self.policyID = policyID
        self.records = records
        self.abilityContrasts = abilityContrasts
        self.affixContrasts = affixContrasts
        self.elapsedSeconds = elapsedSeconds
    }
}
