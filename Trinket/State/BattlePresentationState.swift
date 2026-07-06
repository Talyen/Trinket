import BattleEngine
import Foundation
import Observation
import TrinketContent

/// UI-facing battle presentation: overlays, outcome screens, feedback, and music preview.
/// Simulation state lives on `BattleSession.state`.
@MainActor
@Observable
final class BattlePresentationState {
    var isPaused = false
    var isShowingVictory = false
    var isShowingDefeat = false
    var victorySummary: BattleVictorySummary?
    var preview: BattleMusicPreview?
    var overlayCombatantDetail: CombatantDetailContext?
    var activeFeedbackEvents: [ActionEvent] = []
    private var feedbackEventsByTargetID: [String: [ActionEvent]] = [:]
    private var feedbackDisplayedAt: [Int: Date] = [:]
    private var overlayPauseDepth = 0
    private var pauseStateBeforeOverlay: Bool?

    func clearOutcomePresentation() {
        isShowingVictory = false
        isShowingDefeat = false
        victorySummary = nil
    }

    func clearAll() {
        isPaused = false
        clearOutcomePresentation()
        preview = nil
        overlayCombatantDetail = nil
        clearFeedback()
        overlayPauseDepth = 0
        pauseStateBeforeOverlay = nil
    }

    func setMusicPreview(for stage: Stage?, battleIsActive: Bool) {
        guard !battleIsActive,
              let stage,
              let enemyID = stage.encounter.battleEnemyID
        else {
            preview = nil
            return
        }

        preview = BattleMusicPreview(stageID: stage.id, enemyID: enemyID)
    }

    func pauseForOverlay(battleIsActive: Bool) {
        guard battleIsActive else { return }
        if overlayPauseDepth == 0 {
            pauseStateBeforeOverlay = isPaused
        }
        overlayPauseDepth += 1
        isPaused = true
    }

    func restorePauseAfterOverlay(battleIsActive: Bool) {
        guard overlayPauseDepth > 0 else { return }
        overlayPauseDepth -= 1
        guard overlayPauseDepth == 0 else { return }
        guard battleIsActive else {
            pauseStateBeforeOverlay = nil
            return
        }
        isPaused = pauseStateBeforeOverlay ?? false
        pauseStateBeforeOverlay = nil
    }

    func presentCombatantDetail(_ detail: CombatantCardDetail, battleIsActive: Bool) {
        if battleIsActive {
            pauseForOverlay(battleIsActive: true)
        }
        overlayCombatantDetail = CombatantDetailContext(snapshot: detail)
    }

    func feedbackEvents(for targetID: String) -> [ActionEvent] {
        feedbackEventsByTargetID[targetID] ?? []
    }

    func removeFeedbackEvent(_ id: Int) {
        if let event = activeFeedbackEvents.first(where: { $0.id == id }) {
            feedbackEventsByTargetID[event.targetID]?.removeAll { $0.id == id }
        }
        activeFeedbackEvents.removeAll { $0.id == id }
        feedbackDisplayedAt.removeValue(forKey: id)
    }

    func pruneExpiredFeedback(at date: Date = .now) {
        let expiredIDs = feedbackDisplayedAt.compactMap { eventID, displayedAt in
            date.timeIntervalSince(displayedAt) >= CombatFeedbackTiming.displayDuration ? eventID : nil
        }
        for eventID in expiredIDs {
            removeFeedbackEvent(eventID)
        }
    }

    func recordFeedbackEvents(_ events: [ActionEvent], at date: Date = .now) {
        for event in events {
            activeFeedbackEvents.append(event)
            feedbackDisplayedAt[event.id] = date
            feedbackEventsByTargetID[event.targetID, default: []].append(event)
        }
    }

    func clearFeedback() {
        activeFeedbackEvents = []
        feedbackEventsByTargetID = [:]
        feedbackDisplayedAt = [:]
    }
}
