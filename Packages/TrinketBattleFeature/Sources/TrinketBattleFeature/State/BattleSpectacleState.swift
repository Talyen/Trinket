import Observation
import TrinketContent

public enum BattleOutcomePresentation: Equatable {
    case battle
    case pendingVictory(BattleVictorySummary)
    case victory(BattleVictorySummary)
    case defeat(BattleRewardSettlement)

    var isOutcomePresented: Bool {
        switch self {
        case .victory, .defeat:
            true
        case .battle, .pendingVictory:
            false
        }
    }

    var isVictoryPresented: Bool {
        if case .victory = self {
            return true
        }
        return false
    }

    var victorySummaryIfAvailable: BattleVictorySummary? {
        switch self {
        case let .pendingVictory(summary), let .victory(summary): summary
        case .battle, .defeat: nil
        }
    }
}

@MainActor
@Observable
public final class BattleSpectacleState {
    public internal(set) var outcomePresentation: BattleOutcomePresentation = .battle
    var nextID = 0

    @ObservationIgnored
    var outcomeTask = CancellableGeneration()
    @ObservationIgnored
    var celebrateTask = CancellableGeneration()
}
