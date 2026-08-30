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

public enum ContrastBaselineKind: String, Codable, Sendable {
    case sibling
    case emptySlot = "empty-slot"
    case replacementAffix = "replacement-affix"
    case none
    case fullKit = "full-kit"
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
        let offset = min(workOffset, items.count)
        let remainder = items.dropFirst(offset)
        guard let workLimit else { return Array(remainder) }
        return Array(remainder.prefix(workLimit))
    }

    public func localSlice(regionStart: Int, regionCount: Int) -> (offset: Int, limit: Int)? {
        guard regionCount > 0 else { return nil }
        let globalStart = workOffset
        let globalEnd = workLimit.map { globalStart + $0 } ?? Int.max
        let regionEnd = regionStart + regionCount
        let start = max(globalStart, regionStart)
        let end = min(globalEnd, regionEnd)
        guard start < end else { return nil }
        return (start - regionStart, end - start)
    }

    public func withLocalSlice(regionStart: Int, regionCount: Int) -> Self? {
        guard let local = localSlice(regionStart: regionStart, regionCount: regionCount) else {
            return nil
        }
        var copy = self
        copy.workOffset = local.offset
        copy.workLimit = local.limit
        return copy
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
        SimulationPolicies.make(id: policyID) ?? .greedy
    }

    public var comparePolicy: PlayPolicy {
        policyID == PlayPolicy.setupAware.rawValue
            ? .greedy
            : .setupAware
    }
}

public struct BalanceSweepRoster: Equatable, Sendable {
    public var heroes: [Combatant]
    public var companions: [Combatant]
    public var enemies: [Enemy]

    public static func resolve(config: BalanceSweepConfig) -> Self {
        let heroes = filterCombatants(GameContent.heroes, ids: config.heroIDs)
        let companions = filterCombatants(GameContent.companions, ids: config.companionIDs)
        let enemies: [Enemy] = if config.enemyIDs.isEmpty {
            GameContent.enemies
        } else {
            GameContent.enemies.filter { Set(config.enemyIDs).contains($0.id) }
        }
        return Self(heroes: heroes, companions: companions, enemies: enemies)
    }

    private static func filterCombatants(_ all: [Combatant], ids: [String]) -> [Combatant] {
        guard !ids.isEmpty else { return all }
        let wanted = Set(ids)
        return all.filter { wanted.contains($0.id) }
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
    public var heroAffixIDs: [String]
    public var companionAffixIDs: [String]
    public var heroTalentIDs: [String]
    public var companionTalentIDs: [String]
    public var seed: UInt64
    public var policyID: String
    public var result: BattleSimResult

    public init(
        tier: SimulationPowerTier,
        heroID: String,
        companionID: String,
        enemyID: String,
        isBoss: Bool,
        heroAbilityIDs: [String],
        companionAbilityIDs: [String],
        enemyAbilityIDs: [String],
        enemyTraitID: String,
        affixIDs: [String],
        heroAffixIDs: [String] = [],
        companionAffixIDs: [String] = [],
        heroTalentIDs: [String],
        companionTalentIDs: [String],
        seed: UInt64,
        policyID: String,
        result: BattleSimResult,
    ) {
        self.tier = tier
        self.heroID = heroID
        self.companionID = companionID
        self.enemyID = enemyID
        self.isBoss = isBoss
        self.heroAbilityIDs = heroAbilityIDs
        self.companionAbilityIDs = companionAbilityIDs
        self.enemyAbilityIDs = enemyAbilityIDs
        self.enemyTraitID = enemyTraitID
        self.affixIDs = affixIDs
        self.heroAffixIDs = heroAffixIDs
        self.companionAffixIDs = companionAffixIDs
        self.heroTalentIDs = heroTalentIDs
        self.companionTalentIDs = companionTalentIDs
        self.seed = seed
        self.policyID = policyID
        self.result = result
    }
}

public struct PairedContrastSummary: Equatable, Codable, Sendable {
    public var entityID: String
    public var baselineID: String
    public var ownerID: String
    public var tier: SimulationPowerTier
    public var baselineKind: ContrastBaselineKind
    public var pairs: Int
    public var decidedPairs: Int
    public var winsWithEntity: Int
    public var winsWithBaseline: Int
    public var entityOnlyWins: Int
    public var baselineOnlyWins: Int
    public var entityTimeouts: Int
    public var baselineTimeouts: Int
    public var lift: Double
    public var meanDeltaPartyHP: Double
    public var meanDeltaEnemyHP: Double
    public var meanDeltaRounds: Double
    public var flagged: Bool
    public var flagReason: String?
    public var nonCombat: Bool

    public var entityWinRate: Double {
        decidedPairs == 0 ? 0 : Double(winsWithEntity) / Double(decidedPairs)
    }

    public var baselineWinRate: Double {
        decidedPairs == 0 ? 0 : Double(winsWithBaseline) / Double(decidedPairs)
    }

    public init(
        entityID: String,
        baselineID: String,
        ownerID: String,
        tier: SimulationPowerTier,
        baselineKind: ContrastBaselineKind = .sibling,
        pairs: Int,
        decidedPairs: Int,
        winsWithEntity: Int,
        winsWithBaseline: Int,
        entityOnlyWins: Int = 0,
        baselineOnlyWins: Int = 0,
        entityTimeouts: Int = 0,
        baselineTimeouts: Int = 0,
        lift: Double,
        meanDeltaPartyHP: Double = 0,
        meanDeltaEnemyHP: Double = 0,
        meanDeltaRounds: Double = 0,
        flagged: Bool,
        flagReason: String? = nil,
        nonCombat: Bool = false,
    ) {
        self.entityID = entityID
        self.baselineID = baselineID
        self.ownerID = ownerID
        self.tier = tier
        self.baselineKind = baselineKind
        self.pairs = pairs
        self.decidedPairs = decidedPairs
        self.winsWithEntity = winsWithEntity
        self.winsWithBaseline = winsWithBaseline
        self.entityOnlyWins = entityOnlyWins
        self.baselineOnlyWins = baselineOnlyWins
        self.entityTimeouts = entityTimeouts
        self.baselineTimeouts = baselineTimeouts
        self.lift = lift
        self.meanDeltaPartyHP = meanDeltaPartyHP
        self.meanDeltaEnemyHP = meanDeltaEnemyHP
        self.meanDeltaRounds = meanDeltaRounds
        self.flagged = flagged
        self.flagReason = flagReason
        self.nonCombat = nonCombat
    }
}

public struct BalanceSweepReport: Codable, Sendable {
    public var config: BalanceSweepConfig
    public var policyID: String
    public var records: [BalanceBattleRecord]
    public var comparedPolicyID: String?
    public var comparedRecords: [BalanceBattleRecord]
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
        comparedPolicyID: String? = nil,
        comparedRecords: [BalanceBattleRecord] = [],
        abilityContrasts: [PairedContrastSummary] = [],
        affixContrasts: [PairedContrastSummary] = [],
        talentContrasts: [PairedContrastSummary] = [],
        talentKitContrasts: [PairedContrastSummary] = [],
        progressionHotspots: [NodeHotspotSummary] = [],
        progressionRecords: [ProgressionBattleRecord] = [],
        progressionPlayerStates: [PlayerProgressionState] = [],
        progressionTruncatedRuns: Int = 0,
        elapsedSeconds: Double,
    ) {
        self.config = config
        self.policyID = policyID
        self.records = records
        self.comparedPolicyID = comparedPolicyID
        self.comparedRecords = comparedRecords
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
