import Foundation
import TrinketCore
import TrinketContent
import BattleEngine

public enum LoadoutSamplingMode: String, Codable, Sendable, CaseIterable {
    case optimistic
    case realistic
}

public struct BalanceSweepRequest: Equatable, Sendable {
    public let tiers: [SimulationPowerTier]
    public let runsPerMatchup: Int
    public let loadoutSamplesPerMatchup: Int
    public let baseSeed: UInt64
    public let includeAbilityAnalysis: Bool
    public let representativeHeroID: String
    public let representativePetID: String
    public let maxTicks: Int
    public let stageWeighted: Bool
    public let loadoutSamplingMode: LoadoutSamplingMode
    public let triples: [BalanceSweepTriple]?

    public init(
        tiers: [SimulationPowerTier] = SimulationPowerTier.allCases,
        runsPerMatchup: Int = BalanceSweepDefaults.runsPerMatchup,
        loadoutSamplesPerMatchup: Int = BalanceSweepDefaults.loadoutSamplesPerMatchup,
        baseSeed: UInt64 = BalanceSweepDefaults.baseSeed,
        includeAbilityAnalysis: Bool = false,
        representativeHeroID: String = BalanceSweepDefaults.representativeHeroID,
        representativePetID: String = BalanceSweepDefaults.representativePetID,
        maxTicks: Int = BalanceSweepDefaults.maxTicks,
        stageWeighted: Bool = false,
        loadoutSamplingMode: LoadoutSamplingMode = .realistic,
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
        self.stageWeighted = stageWeighted
        self.loadoutSamplingMode = loadoutSamplingMode
        self.triples = triples
    }

    public static let `default` = BalanceSweepRequest()

    var encodedTripleCount: Int {
        if let triples {
            return triples.count
        }
        if stageWeighted {
            return tiers.reduce(0) { partial, tier in
                partial + BalanceSweepCatalog.triples(for: tier, stageWeighted: true).count
            }
        }
        return BalanceSweepCatalog.allTriples().count
    }
}

public struct BalanceSweepRequestSnapshot: Codable, Equatable, Sendable {
    public let tiers: [String]
    public let runsPerMatchup: Int
    public let loadoutSamplesPerMatchup: Int
    public let baseSeed: UInt64
    public let includeAbilityAnalysis: Bool
    public let representativeHeroID: String
    public let representativePetID: String
    public let maxTicks: Int
    public let stageWeighted: Bool
    public let loadoutSamplingMode: String
    public let tripleCount: Int

    public init(request: BalanceSweepRequest) {
        tiers = request.tiers.map(\.rawValue)
        runsPerMatchup = request.runsPerMatchup
        loadoutSamplesPerMatchup = request.loadoutSamplesPerMatchup
        baseSeed = request.baseSeed
        includeAbilityAnalysis = request.includeAbilityAnalysis
        representativeHeroID = request.representativeHeroID
        representativePetID = request.representativePetID
        maxTicks = request.maxTicks
        stageWeighted = request.stageWeighted
        loadoutSamplingMode = request.loadoutSamplingMode.rawValue
        tripleCount = request.encodedTripleCount
    }
}

public struct MatchupSweepRow: Equatable, Sendable, Identifiable, Codable {
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

public struct AbilityComparisonRow: Equatable, Sendable, Identifiable, Codable {
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

public struct BalanceAnomaly: Equatable, Sendable, Identifiable, Codable {
    public enum Kind: String, Sendable, Codable {
        case hardCounter
        case belowTarget
        case aboveTarget
        case timeout
        case tooShort
        case prolongedFight
        case underpoweredAbility
        case overpoweredAbility
        case bossTuning
    }

    public enum Severity: String, Sendable, Codable {
        case critical
        case warning
    }

    public var id: String {
        if let subjectID {
            return "\(kind.rawValue)-\(subjectID)"
        }
        return "\(kind.rawValue)-\(detail)"
    }

    public let kind: Kind
    public let severity: Severity
    public let subjectID: String?
    public let detail: String
    public let value: Double

    public init(
        kind: Kind,
        severity: Severity,
        subjectID: String? = nil,
        detail: String,
        value: Double
    ) {
        self.kind = kind
        self.severity = severity
        self.subjectID = subjectID
        self.detail = detail
        self.value = value
    }
}

public struct BalanceSweepResult: Equatable, Sendable, Codable {
    public let request: BalanceSweepRequestSnapshot
    public let matchupRows: [MatchupSweepRow]
    public let abilityRows: [AbilityComparisonRow]
    public let anomalies: [BalanceAnomaly]
    public let kpis: BalanceSweepKPIs
    public let gateViolations: [BalanceGateViolation]
    public let generatedAt: Date

    public init(
        request: BalanceSweepRequest,
        matchupRows: [MatchupSweepRow],
        abilityRows: [AbilityComparisonRow],
        anomalies: [BalanceAnomaly],
        kpis: BalanceSweepKPIs,
        gateViolations: [BalanceGateViolation] = [],
        generatedAt: Date
    ) {
        self.request = BalanceSweepRequestSnapshot(request: request)
        self.matchupRows = matchupRows
        self.abilityRows = abilityRows
        self.anomalies = anomalies
        self.kpis = kpis
        self.gateViolations = gateViolations
        self.generatedAt = generatedAt
    }
}
