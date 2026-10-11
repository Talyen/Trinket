/// Owns the pending draws and their once-only turn-start settlement together.
/// An empty draw queue still needs settlement; it is never a ready player turn.
enum BattleTurnState {
    case opening([BattleParticipant])
    case playerTurn
    case resolving
    case drawing([BattleParticipant])
    case ended

    var phase: BattlePhase {
        switch self {
        // Deferred opening also supports callers that install their own hand.
        case .opening, .playerTurn: .playerTurn
        case .resolving, .drawing: .preparingTurn
        case .ended: .ended
        }
    }

    mutating func nextDraw(opening: Bool) -> BattleParticipant? {
        var draws: [BattleParticipant]
        switch self {
        case let .opening(pending) where opening: draws = pending
        case let .drawing(pending) where !opening: draws = pending
        default: return nil
        }
        guard !draws.isEmpty else { return nil }
        let owner = draws.removeFirst()
        self = opening ? .opening(draws) : .drawing(draws)
        return owner
    }

    mutating func beginTurnStart(opening: Bool) -> Bool {
        switch self {
        case .opening where opening, .drawing where !opening:
            self = .resolving
            return true
        default:
            return false
        }
    }
}
