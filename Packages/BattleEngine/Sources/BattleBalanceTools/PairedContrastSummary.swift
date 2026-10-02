import BattleEngine

public enum ContrastBaselineKind: String, Codable, Sendable {
    case sibling
    case emptySlot = "empty-slot"
    case replacementAffix = "replacement-affix"
    case none
    case fullKit = "full-kit"
}

public struct PairedContrastSummary: Equatable, Codable, Sendable {
    public var entityID: String
    public var baselineID: String
    public var ownerID: String
    public var tier: SimulationPowerTier
    public var baselineKind: ContrastBaselineKind = .sibling
    public var pairs: Int
    public var decidedPairs: Int
    public var winsWithEntity: Int
    public var winsWithBaseline: Int
    public var entityOnlyWins: Int = 0
    public var baselineOnlyWins: Int = 0
    public var entityTimeouts: Int = 0
    public var baselineTimeouts: Int = 0
    public var lift: Double
    public var meanDeltaPartyHP: Double = 0
    public var meanDeltaRounds: Double = 0
    public var flagged: Bool
    public var flagReason: String?
    public var nonCombat: Bool = false

    public var entityWinRate: Double {
        decidedPairs == 0 ? 0 : Double(winsWithEntity) / Double(decidedPairs)
    }

    public var baselineWinRate: Double {
        decidedPairs == 0 ? 0 : Double(winsWithBaseline) / Double(decidedPairs)
    }
}
