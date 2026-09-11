import TrinketContent

public enum BattleCompletionResult: Equatable, Sendable {
    case completed
    case staleSettlement(BattleRewardSettlement)
    case unavailable
    case persistenceFailed

    public var didComplete: Bool {
        self == .completed
    }
}
