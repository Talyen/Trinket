import BattleEngine
import Foundation
import Observation
import TrinketFeatureSupport

@MainActor
@Observable
public final class BattleSpectacleState {
    public var isShowingVictory = false
    public var isShowingDefeat = false
    public var victorySummary: BattleVictorySummary?
    var activeCinematic: BattleCinematicPresentation?
    var deferredFeedbackEvents: [ActionEvent] = []
    var nextID = 0
    var actorsWhoPresentedUltimateThisBattle: Set<String> = []

    @ObservationIgnored
    var pendingOutcomePresentationTask: Task<Void, Never>?
    @ObservationIgnored
    var pendingPartyCelebrateTask: Task<Void, Never>?
    @ObservationIgnored
    var pendingCinematicWatchdogTask: Task<Void, Never>?
}
