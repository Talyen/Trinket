import Foundation
import TrinketContent
import TrinketCore

public struct BalanceSweepConfig: Equatable, Sendable {
    public var battlesPerTier: Int
    public var seed: UInt64
    public var tiers: [SimulationPowerTier]
    public var maxRounds: Int
    public var maxActions: Int
    public var peerDeltaFlagThreshold: Double
    public var outputDirectory: String

    public static let defaultBattlesPerTier = 1000
    public static let defaultOutputDirectory = "BalanceSweepReports"

    public init(
        battlesPerTier: Int = defaultBattlesPerTier,
        seed: UInt64 = 1,
        tiers: [SimulationPowerTier] = SimulationPowerTier.allCases,
        maxRounds: Int = BattleSimulator.defaultMaxRounds,
        maxActions: Int = BattleSimulator.defaultMaxActions,
        peerDeltaFlagThreshold: Double = 0.10,
        outputDirectory: String = defaultOutputDirectory
    ) {
        self.battlesPerTier = max(1, battlesPerTier)
        self.seed = seed
        self.tiers = tiers.isEmpty ? SimulationPowerTier.allCases : tiers
        self.maxRounds = maxRounds
        self.maxActions = maxActions
        self.peerDeltaFlagThreshold = peerDeltaFlagThreshold
        self.outputDirectory = outputDirectory
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

public struct BalanceSweepReport: Sendable {
    public var config: BalanceSweepConfig
    public var policyID: String
    public var records: [BalanceBattleRecord]
    public var elapsedSeconds: Double
}
