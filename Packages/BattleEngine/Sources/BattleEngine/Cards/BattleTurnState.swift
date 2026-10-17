/// Deferred opening is consumed by its command or by a caller-supplied hand.
/// Commands reserve resolution before any turn-start work can run.
enum BattleTurnState {
    case opening([BattleParticipant])
    case playerTurn
    case resolving
    case ended

    var phase: BattlePhase {
        switch self {
        case .opening, .playerTurn: .playerTurn
        case .resolving: .preparingTurn
        case .ended: .ended
        }
    }
}
