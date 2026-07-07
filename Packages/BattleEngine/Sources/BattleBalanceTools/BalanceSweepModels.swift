import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

enum LoadoutSamplingMode: String, Codable, CaseIterable {
    case optimistic
    case realistic
}

struct BalanceSweepRequest: Equatable {
    let tiers: [SimulationPowerTier]
    let runsPerMatchup: Int
    let loadoutSamplesPerMatchup: Int
    let baseSeed: UInt64
    let includeAbilityAnalysis: Bool
    let representativeHeroID: String
    let representativePetID: String
    let maxTicks: Int
    let stageWeighted: Bool
    let loadoutSamplingMode: LoadoutSamplingMode
    let triples: [BalanceSweepTriple]?

    init(
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

    static let `default` = BalanceSweepRequest()

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

struct BalanceSweepRequestSnapshot: Codable, Equatable {
    let tiers: [String]
    let runsPerMatchup: Int
    let loadoutSamplesPerMatchup: Int
    let baseSeed: UInt64
    let includeAbilityAnalysis: Bool
    let representativeHeroID: String
    let representativePetID: String
    let maxTicks: Int
    let stageWeighted: Bool
    let loadoutSamplingMode: String
    let tripleCount: Int

    init(request: BalanceSweepRequest) {
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

struct MatchupSweepRow: Equatable, Identifiable, Codable {
    var id: String {
        "\(tier.rawValue)-\(heroID)-\(petID)-\(enemyID)-sample\(loadoutSampleIndex)"
    }

    let tier: SimulationPowerTier
    let heroID: String
    let petID: String
    let enemyID: String
    let isBoss: Bool
    let isElite: Bool
    let loadoutSampleIndex: Int
    let winCount: Int
    let tickLimitCount: Int
    let runCount: Int
    let averageTickCount: Double
    let averageActionCount: Double

    init(
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

    var winRate: Double {
        guard runCount > 0 else { return 0 }
        return Double(winCount) / Double(runCount)
    }

    var tickLimitRate: Double {
        guard runCount > 0 else { return 0 }
        return Double(tickLimitCount) / Double(runCount)
    }
}

struct AbilityComparisonRow: Equatable, Identifiable, Codable {
    var id: String {
        "\(tier.rawValue)-\(combatantID)-\(tierName)-\(abilityID)-vs-\(siblingAbilityID)"
    }

    let tier: SimulationPowerTier
    let combatantID: String
    let combatantName: String
    let abilityTier: AbilityTier
    let abilityID: String
    let abilityName: String
    let siblingAbilityID: String
    let siblingAbilityName: String
    let winCount: Int
    let lossCount: Int

    var tierName: String {
        abilityTier.rawValue
    }

    var sampleCount: Int {
        winCount + lossCount
    }

    var winRate: Double {
        guard sampleCount > 0 else { return 0 }
        return Double(winCount) / Double(sampleCount)
    }

    var deltaVsSibling: Double {
        winRate - 0.5
    }
}

struct BalanceAnomaly: Equatable, Identifiable, Codable {
    enum Kind: String, Codable {
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

    enum Severity: String, Codable {
        case critical
        case warning
    }

    var id: String {
        if let subjectID {
            return "\(kind.rawValue)-\(subjectID)"
        }
        return "\(kind.rawValue)-\(detail)"
    }

    let kind: Kind
    let severity: Severity
    let subjectID: String?
    let detail: String
    let value: Double

    init(
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

struct BalanceSweepResult: Equatable, Codable {
    let request: BalanceSweepRequestSnapshot
    let matchupRows: [MatchupSweepRow]
    let abilityRows: [AbilityComparisonRow]
    let anomalies: [BalanceAnomaly]
    let kpis: BalanceSweepKPIs
    let gateViolations: [BalanceGateViolation]
    let generatedAt: Date

    init(
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
