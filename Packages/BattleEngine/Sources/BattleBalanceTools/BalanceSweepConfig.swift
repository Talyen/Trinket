import BattleEngine
import Foundation

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
    public var jobs: Int
    public var workOffset: Int
    public var workLimit: Int?
    public var appliesFightPacing: Bool
    public var policyID: String
    public var comparePolicies: Bool
    public var heroIDs: [String]
    public var companionIDs: [String]
    public var enemyIDs: [String]
    public var focusIDs: [String]
    public var durationFlagRate: Double
    public var comfortHPThreshold: Double
    public var comfortRoundThreshold: Double

    public static let defaultBattlesPerTier = 32
    public static let defaultOutputDirectory = "BalanceSweepReports"
    public static let contrastFlagMinPairs = 8
    public static let identityFlagMinBattles = 8
    public static let durationFlagRateDefault = 0.15
    public static let comfortHPThresholdDefault = 0.10
    public static let comfortRoundThresholdDefault = 2.0

    public init(
        mode: BalanceSweepMode = .identity,
        battlesPerTier: Int = Self.defaultBattlesPerTier,
        seed: UInt64 = 1,
        tiers: [SimulationPowerTier] = SimulationPowerTier.allCases,
        maxRounds: Int = BattleSimulator.defaultMaxRounds,
        maxActions: Int = BattleSimulator.defaultMaxActions,
        peerDeltaFlagThreshold: Double = 0.10,
        outputDirectory: String = Self.defaultOutputDirectory,
        jobs: Int = 0,
        workOffset: Int = 0,
        workLimit: Int? = nil,
        appliesFightPacing: Bool = true,
        policyID: String = PlayPolicy.greedy.rawValue,
        comparePolicies: Bool = false,
        heroIDs: [String] = [],
        companionIDs: [String] = [],
        enemyIDs: [String] = [],
        focusIDs: [String] = [],
        durationFlagRate: Double = Self.durationFlagRateDefault,
        comfortHPThreshold: Double = Self.comfortHPThresholdDefault,
        comfortRoundThreshold: Double = Self.comfortRoundThresholdDefault,
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
        self.appliesFightPacing = appliesFightPacing
        self.policyID = policyID
        self.comparePolicies = comparePolicies
        self.heroIDs = heroIDs
        self.companionIDs = companionIDs
        self.enemyIDs = enemyIDs
        self.focusIDs = focusIDs
        self.durationFlagRate = durationFlagRate
        self.comfortHPThreshold = comfortHPThreshold
        self.comfortRoundThreshold = comfortRoundThreshold
    }

    public func sliceWork<Item>(_ items: [Item]) -> [Item] {
        Array(items[workIndices(count: items.count)])
    }

    /// Select global indices before constructing work so each worker only plans
    /// its assigned slice. Clamp the length before adding to avoid overflow.
    func workIndices(count: Int) -> Range<Int> {
        let offset = min(workOffset, count)
        let remaining = count - offset
        let length = min(workLimit ?? remaining, remaining)
        return offset ..< (offset + length)
    }

    public var resolvedJobs: Int {
        if jobs <= 0 {
            return max(1, ProcessInfo.processInfo.activeProcessorCount)
        }
        return jobs
    }

    public var resolvedRoster: BalanceSweepRoster {
        BalanceSweepRoster.resolve(config: self)
    }

    public var policy: PlayPolicy {
        PlayPolicy(rawValue: policyID) ?? .greedy
    }

    public var comparePolicy: PlayPolicy {
        policyID == PlayPolicy.setupAware.rawValue
            ? .greedy
            : .setupAware
    }
}
