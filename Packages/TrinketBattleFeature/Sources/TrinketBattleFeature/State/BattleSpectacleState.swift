import BattleEngine
import Foundation
import Observation
import TrinketFeatureSupport

public enum BattleOutcomePresentation: Equatable {
    case battle
    case pendingVictory(BattleVictorySummary)
    case victory(BattleVictorySummary)
    case defeat

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
    var ultimateHighlightsByActorID: [String: BattleUltimateInFramePresentation] = [:]
    var nextID = 0
    var actorsWhoPresentedUltimateThisBattle: Set<String> = []

    @ObservationIgnored
    var pendingOutcomePresentationTask: Task<Void, Never>?
    @ObservationIgnored
    var pendingPartyCelebrateTask: Task<Void, Never>?
    @ObservationIgnored
    var pendingUltimateHighlightTasksByActorID: [String: Task<Void, Never>] = [:]
}
