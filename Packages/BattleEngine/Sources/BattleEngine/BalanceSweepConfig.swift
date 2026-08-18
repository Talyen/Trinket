import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

public enum BalanceSweepMode: String, CaseIterable, Codable, Sendable {
    case identity
    case abilityContrast = "ability-contrast"
    case affixContrast = "affix-contrast"
    case talentContrast = "talent-contrast"
    case modeProgression = "mode-progression"
    case all
}

public struct BalanceSweepConfig: Equatable, Codable, Sendable {
    public var mode: BalanceSweepMode
    public var battlesPerTier: Int
    public var seed: UInt64
    public var tiers: [SimulationPowerTier]
    public var maxRounds: Int
    public var maxActions: Int
    public var peerDeltaFlagThreshold: Double
    public var outputDirectory: String
    /// CLI process-pool size. `1` = one worker process; `0` = use active processor count.
    /// In-process `BalanceSweepRunner` always maps work sequentially.
    public var jobs: Int
    /// Inclusive start into flattened identity/contrast/progression work. CLI workers only.
    public var workOffset: Int
    /// Max work items from `workOffset`. `nil` runs the remainder.
    public var workLimit: Int?

    public static let defaultBattlesPerTier = 100
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
        jobs: Int = 0,
        workOffset: Int = 0,
        workLimit: Int? = nil
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
        self.workOffset = max(0, workOffset)
        self.workLimit = workLimit.map { max(0, $0) }
    }

    public func sliceWork<Item>(_ items: [Item]) -> [Item] {
        let offset = min(workOffset, items.count)
        let remainder = items.dropFirst(offset)
        guard let workLimit else { return Array(remainder) }
        return Array(remainder.prefix(workLimit))
    }

    public var resolvedJobs: Int {
        if jobs <= 0 {
            return max(1, ProcessInfo.processInfo.activeProcessorCount)
        }
        return jobs
    }
}

public struct BalanceBattleRecord: Equatable, Codable, Sendable {
    public var tier: SimulationPowerTier
    public var heroID: String
    public var companionID: String
    public var enemyID: String
    public var isBoss: Bool
    public var heroAbilityIDs: [String]
    public var companionAbilityIDs: [String]
    public var enemyAbilityIDs: [String]
    public var enemyTraitID: String
    public var affixIDs: [String]
    public var heroTalentIDs: [String]
    public var companionTalentIDs: [String]
    public var seed: UInt64
    public var result: BattleSimResult
}

public struct PairedContrastSummary: Equatable, Codable, Sendable {
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

    public init(
        entityID: String,
        baselineID: String,
        ownerID: String,
        tier: SimulationPowerTier,
        pairs: Int,
        winsWithEntity: Int,
        winsWithBaseline: Int,
        lift: Double,
        flagged: Bool,
        flagReason: String? = nil
    ) {
        self.entityID = entityID
        self.baselineID = baselineID
        self.ownerID = ownerID
        self.tier = tier
        self.pairs = pairs
        self.winsWithEntity = winsWithEntity
        self.winsWithBaseline = winsWithBaseline
        self.lift = lift
        self.flagged = flagged
        self.flagReason = flagReason
    }
}

public struct BalanceSweepReport: Codable, Sendable {
    public var config: BalanceSweepConfig
    public var policyID: String
    public var records: [BalanceBattleRecord]
    public var abilityContrasts: [PairedContrastSummary]
    public var affixContrasts: [PairedContrastSummary]
    public var talentContrasts: [PairedContrastSummary]
    public var talentKitContrasts: [PairedContrastSummary]
    public var progressionHotspots: [NodeHotspotSummary]
    public var progressionRecords: [ProgressionBattleRecord]
    public var progressionPlayerStates: [PlayerProgressionState]
    public var progressionTruncatedRuns: Int
    public var elapsedSeconds: Double

    public init(
        config: BalanceSweepConfig,
        policyID: String,
        records: [BalanceBattleRecord] = [],
        abilityContrasts: [PairedContrastSummary] = [],
        affixContrasts: [PairedContrastSummary] = [],
        talentContrasts: [PairedContrastSummary] = [],
        talentKitContrasts: [PairedContrastSummary] = [],
        progressionHotspots: [NodeHotspotSummary] = [],
        progressionRecords: [ProgressionBattleRecord] = [],
        progressionPlayerStates: [PlayerProgressionState] = [],
        progressionTruncatedRuns: Int = 0,
        elapsedSeconds: Double
    ) {
        self.config = config
        self.policyID = policyID
        self.records = records
        self.abilityContrasts = abilityContrasts
        self.affixContrasts = affixContrasts
        self.talentContrasts = talentContrasts
        self.talentKitContrasts = talentKitContrasts
        self.progressionHotspots = progressionHotspots
        self.progressionRecords = progressionRecords
        self.progressionPlayerStates = progressionPlayerStates
        self.progressionTruncatedRuns = max(0, progressionTruncatedRuns)
        self.elapsedSeconds = elapsedSeconds
    }
}
