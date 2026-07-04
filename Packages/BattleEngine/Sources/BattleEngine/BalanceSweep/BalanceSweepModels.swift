import Foundation
import TrinketCore
import TrinketContent

public struct BalanceSweepRequest: Equatable, Sendable {
    public let tiers: [SimulationPowerTier]
    public let runsPerMatchup: Int
    public let loadoutSamplesPerMatchup: Int
    public let baseSeed: UInt64
    public let includeAbilityAnalysis: Bool
    public let representativeHeroID: String
    public let representativePetID: String
    public let maxTicks: Int
    public let triples: [BalanceSweepTriple]?

    public init(
        tiers: [SimulationPowerTier] = SimulationPowerTier.allCases,
        runsPerMatchup: Int = BalanceSweepDefaults.runsPerMatchup,
        loadoutSamplesPerMatchup: Int = BalanceSweepDefaults.loadoutSamplesPerMatchup,
        baseSeed: UInt64 = BalanceSweepDefaults.baseSeed,
        includeAbilityAnalysis: Bool = true,
        representativeHeroID: String = BalanceSweepDefaults.representativeHeroID,
        representativePetID: String = BalanceSweepDefaults.representativePetID,
        maxTicks: Int = BalanceSweepDefaults.maxTicks,
        triples: [BalanceSweepTriple]? = nil
    ) {
        self.tiers = tiers
        self.runsPerMatchup = max(1, runsPerMatchup)
        self.loadoutSamplesPerMatchup = max(1, loadoutSamplesPerMatchup)
        self.baseSeed = baseSeed
        self.includeAbilityAnalysis = includeAbilityAnalysis
        self.representativeHeroID = representativeHeroID
        self.representativePetID = representativePetID
        self.maxTicks = max(1, maxTicks)
        self.triples = triples
    }

    public static let `default` = BalanceSweepRequest()
}

public struct MatchupSweepRow: Equatable, Sendable, Identifiable {
    public var id: String {
        "\(tier.rawValue)-\(heroID)-\(petID)-\(enemyID)-sample\(loadoutSampleIndex)"
    }

    public let tier: SimulationPowerTier
    public let heroID: String
    public let petID: String
    public let enemyID: String
    public let isBoss: Bool
    public let isElite: Bool
    public let loadoutSampleIndex: Int
    public let winCount: Int
    public let tickLimitCount: Int
    public let runCount: Int
    public let averageTickCount: Double
    public let averageActionCount: Double

    public init(
        tier: SimulationPowerTier,
        heroID: String,
        petID: String,
        enemyID: String,
        isBoss: Bool,
        isElite: Bool = false,
        loadoutSampleIndex: Int,
        winCount: Int,
        tickLimitCount: Int = 0,
        runCount: Int,
        averageTickCount: Double,
        averageActionCount: Double
    ) {
        self.tier = tier
        self.heroID = heroID
        self.petID = petID
        self.enemyID = enemyID
        self.isBoss = isBoss
        self.isElite = isElite
        self.loadoutSampleIndex = loadoutSampleIndex
        self.winCount = winCount
        self.tickLimitCount = tickLimitCount
        self.runCount = runCount
        self.averageTickCount = averageTickCount
        self.averageActionCount = averageActionCount
    }

    public var winRate: Double {
        guard runCount > 0 else { return 0 }
        return Double(winCount) / Double(runCount)
    }

    public var tickLimitRate: Double {
        guard runCount > 0 else { return 0 }
        return Double(tickLimitCount) / Double(runCount)
    }
}

public struct AbilityComparisonRow: Equatable, Sendable, Identifiable {
    public var id: String {
        "\(tier.rawValue)-\(combatantID)-\(tierName)-\(abilityID)-vs-\(siblingAbilityID)"
    }

    public let tier: SimulationPowerTier
    public let combatantID: String
    public let combatantName: String
    public let abilityTier: AbilityTier
    public let abilityID: String
    public let abilityName: String
    public let siblingAbilityID: String
    public let siblingAbilityName: String
    public let winCount: Int
    public let lossCount: Int

    public init(
        tier: SimulationPowerTier,
        combatantID: String,
        combatantName: String,
        abilityTier: AbilityTier,
        abilityID: String,
        abilityName: String,
        siblingAbilityID: String,
        siblingAbilityName: String,
        winCount: Int,
        lossCount: Int
    ) {
        self.tier = tier
        self.combatantID = combatantID
        self.combatantName = combatantName
        self.abilityTier = abilityTier
        self.abilityID = abilityID
        self.abilityName = abilityName
        self.siblingAbilityID = siblingAbilityID
        self.siblingAbilityName = siblingAbilityName
        self.winCount = winCount
        self.lossCount = lossCount
    }

    public var tierName: String {
        abilityTier.rawValue
    }

    public var sampleCount: Int {
        winCount + lossCount
    }

    public var winRate: Double {
        guard sampleCount > 0 else { return 0 }
        return Double(winCount) / Double(sampleCount)
    }

    public var deltaVsSibling: Double {
        winRate - 0.5
    }
}

public struct BalanceAnomaly: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable {
        case hardCounter
        case belowTarget
        case aboveTarget
        case timeout
        case prolongedFight
        case underpoweredAbility
        case overpoweredAbility
        case bossTuning
    }

    public enum Severity: String, Sendable {
        case critical
        case warning
    }

    public var id: String { "\(kind.rawValue)-\(detail)" }

    public let kind: Kind
    public let severity: Severity
    public let detail: String
    public let value: Double
}

public struct BalanceSweepResult: Equatable, Sendable {
    public let request: BalanceSweepRequest
    public let matchupRows: [MatchupSweepRow]
    public let abilityRows: [AbilityComparisonRow]
    public let anomalies: [BalanceAnomaly]
    public let generatedAt: Date
}
