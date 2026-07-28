import TrinketFeatureSupport

public enum BattlePerformanceScenario: String, CaseIterable, Sendable {
    case handDragCancel = "hand-drag-cancel"
    case realCardPlay = "real-card-play"
    case engineHand = "engine-hand"
    case engineFeedback = "engine-feedback"
    case turnTransition = "turn-transition"
    case combinedWorstCase = "combined-worst-case"
}

public enum BattlePerformanceFixture {
    public static let seed: UInt64 = 0x5452_494E
}
