public enum BattleTransitionCheckpoint: Equatable, Sendable {
    case turnActions
    case cardDrawn
    case bufferPromoted
    case ready
}
