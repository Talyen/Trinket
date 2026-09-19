import Foundation
import TrinketCore

struct PlaythroughScenario: Codable, Equatable {
    var version = 1
    var worldSeed: UInt64 = 0x504C_4159
    var combatSeed: UInt64 = 0x4241_5454
    var policySeed: UInt64 = 0x504F_4C49
    var heroID = "knight"
    var companionID = "wolf"
    var fullAccess = false
    var attempts = 2
    var maxActions = 2000
    var maxTurns = 100
    var maxSteps = 200
    var maxArtifactBytes = 32 * 1024 * 1024
    var startDate = Date(timeIntervalSince1970: 1800000000)
    var policy = "greedy-v1"
    var mode = "campaign"
    var invest = true
    var sessionSeconds = 3600.0
}

enum PlaythroughAction: Codable, Equatable {
    case starterHero(String)
    case starterCompanion(String)
    case campaign(String, UInt64)
    case card(Int)
    case endTurn
    case victory
    case defeat(retry: Bool)
    case retreat
    case talent(combatant: String, tree: String, node: String)
    case finishTalent
    case mystery(String?)
    case finishMystery
    case shop(String)
    case finishShop
    case reopen
    case collect(Date)
    case upgrade(String, Int)
    case equip(combatant: String, item: String)
    case party(hero: String, companion: String)
    case corrupt(String)
    case enterLabyrinth
    case labyrinth(String, UInt64)
    case contracts(refresh: Bool)
    case contract(String, UInt64)
    case spire(String, Int, UInt64)
}

enum PlaythroughFailure: Error, CustomStringConvertible {
    case rejected(String)
    case unsupported(String)
    case budget(String)
    case invariant(String)
    case divergence(Int)

    var termination: String {
        switch self {
        case .rejected: "commandRejected"
        case .unsupported: "unsupportedChoice"
        case .budget: "budgetExhaustion"
        case .invariant: "invariantFailure"
        case .divergence: "replayDivergence"
        }
    }

    var description: String {
        switch self {
        case let .rejected(detail): "commandRejected: \(detail)"
        case let .unsupported(detail): "unsupportedChoice: \(detail)"
        case let .budget(detail): "budgetExhaustion: \(detail)"
        case let .invariant(detail): "invariantFailure: \(detail)"
        case let .divergence(sequence): "replayDivergence: action \(sequence)"
        }
    }
}

struct PlaythroughSummary: Codable {
    var schemaVersion = 1
    var population = "fresh-save"
    var termination = "incomplete"
    var outcomes: [String] = []
    var actions = 0
    var turns = 0
    var bossAttempts = 0
    var bossVictories = 0
    var peakResidentBytes: Int64 = 0
    var reachedStages: [String] = []
    var reloads = 0
    var talents = 0
    var upgrades = 0
    var equipmentChanges = 0
    var goldEarned = 0
    var goldSpent = 0
    var cardsDrawn = 0
    var cardsObserved = 0
    var playableObservations = 0
    var cardsChosen = 0
    var simulatedSeconds = 0.0
    var wallSeconds = 0.0
    var diagnostic: String?
}
