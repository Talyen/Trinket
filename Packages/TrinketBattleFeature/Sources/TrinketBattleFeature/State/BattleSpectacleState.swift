import BattleEngine
import Foundation
import Observation
import TrinketFeatureSupport

/// Observable cinematic, callout, and outcome lane for the active battle.
@MainActor
@Observable
public final class BattleSpectacleState {
    public var isShowingVictory = false
    public var isShowingDefeat = false
    public var victorySummary: BattleVictorySummary?
    var activeSkillCallout: SkillCalloutPresentation?
    var activeCinematic: BattleCinematicPresentation?
    var deferredFeedbackEvents: [ActionEvent] = []
    var nextID = 0
    var actorsWhoPresentedUltimateThisBattle: Set<String> = []

    @ObservationIgnored
    var pendingOutcomePresentationTask: Task<Void, Never>?
    @ObservationIgnored
    var pendingPartyCelebrateTask: Task<Void, Never>?
}
