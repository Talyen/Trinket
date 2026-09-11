public enum BattleTransitionCheckpoint: Equatable, Sendable {
    case turnActions
    case cardDrawn
    case bufferPromoted
    case cardsDrawn([BattleCard])
    case cardWillPlay(BattleCard)
    case cardPlayed(BattleCard)
    case cardActions(BattleCard)
    case ready
}
