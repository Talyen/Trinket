import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketPersistence

/// Owns battle simulation state and UI-facing presentation: overlays, outcome screens,
/// feedback, and music preview.
@MainActor
@Observable
final class BattleSession {
    var isPaused = false
    var isShowingVictory = false
    var isShowingDefeat = false
    var victorySummary: BattleVictorySummary?
    var preview: BattleMusicPreview?
    var overlayCombatantDetail: CombatantCardDetail?
    var activeFeedbackEvents: [ActionEvent] = []

    var activeBattle: ActiveBattleConfiguration? {
        didSet {
            if let activeBattle {
                resetRun(from: activeBattle)
            } else {
                clearRunState()
            }
        }
    }

    private(set) var state: BattleState?
    var onBattleStateChange: ((String?) -> Void)?
    var onBattleEnded: (() -> Void)?

    private var feedbackEventsByTargetID: [String: [ActionEvent]] = [:]
    private var feedbackDisplayedAt: [Int: Date] = [:]
    private var overlayPauseDepth = 0
    private var pauseStateBeforeOverlay: Bool?

    var outcome: BattleSimulationOutcome? {
        guard let state else { return nil }
        return BattleSimulationOutcome.resolve(
            isPartyDefeated: state.isPartyDefeated,
            isEnemyDefeated: state.isEnemyDefeated
        )
    }

    func endBattle() {
        activeBattle = nil
        clearAllPresentation()
        onBattleStateChange?(nil)
        onBattleEnded?()
    }

    func notifyBattleStarted(stageID: String) {
        onBattleStateChange?(stageID)
    }

    func setMusicPreview(for stage: Stage?) {
        guard activeBattle == nil,
              let stage,
              let enemyID = stage.encounter.battleEnemyID
        else {
            preview = nil
            return
        }

        preview = BattleMusicPreview(stageID: stage.id, enemyID: enemyID)
    }

    func pauseForOverlay() {
        guard activeBattle != nil else { return }
        if overlayPauseDepth == 0 {
            pauseStateBeforeOverlay = isPaused
        }
        overlayPauseDepth += 1
        isPaused = true
    }

    func restorePauseAfterOverlay() {
        guard overlayPauseDepth > 0 else { return }
        overlayPauseDepth -= 1
        guard overlayPauseDepth == 0 else { return }
        guard activeBattle != nil else {
            pauseStateBeforeOverlay = nil
            return
        }
        isPaused = pauseStateBeforeOverlay ?? false
        pauseStateBeforeOverlay = nil
    }

    func presentCombatantDetail(_ detail: CombatantCardDetail) {
        if activeBattle != nil {
            pauseForOverlay()
        }
        overlayCombatantDetail = detail
    }

    func clearOutcomePresentation() {
        isShowingVictory = false
        isShowingDefeat = false
        victorySummary = nil
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

    func syncLogForDisplay() {
        guard var state else { return }
        state.syncLog()
        self.state = state
    }

    func canAutoAdvanceTick() -> Bool {
        guard let state, !state.isBattleOver, !isPaused else { return false }
        return !isShowingVictory && !isShowingDefeat
    }

    /// Advances one battle tick when unpaused. Returns earned gold when an already-claimed stage
    /// victory should auto-complete without showing the victory screen.
    @discardableResult
    func advanceAutoTick(
        at date: Date = .now,
        journey: JourneyProgressState,
        homestead: PlayerHomesteadState,
        contentCatalog: PlayerContentCatalog = GameContentPlayerCatalog()
    ) -> Int? {
        pruneExpiredFeedback(at: date)
        guard canAutoAdvanceTick(),
              let configuration = activeBattle else { return nil }

        advanceOneStep()

        switch outcome {
        case .victory:
            if Self.stageRewardsAlreadyClaimed(
                stageID: configuration.stageID,
                journey: journey,
                catalog: contentCatalog
            ) {
                return state?.earnedGold ?? 0
            }
            guard let battleState = state else { return nil }
            victorySummary = BattleVictorySummary.make(
                configuration: configuration,
                state: battleState,
                homestead: homestead
            )
            isShowingVictory = true
            return nil
        case .defeat:
            isShowingDefeat = true
            return nil
        case .none, .tickLimit:
            return nil
        }
    }

    static func stageRewardsAlreadyClaimed(
        stageID: String?,
        journey: JourneyProgressState,
        catalog: PlayerContentCatalog = GameContentPlayerCatalog()
    ) -> Bool {
        guard let stageID,
              let stage = catalog.stage(id: stageID) else { return false }
        return journey.hasClaimedRewards(for: stage)
    }

    @discardableResult
    func advanceOneStep() -> BattleStep? {
        guard var state else { return nil }
        let step = state.advanceOneStep(rebuildLog: false)
        self.state = state
        recordFeedbackEvents(
            step.events.filter { $0.kind != .milestone },
            at: .now
        )
        return step
    }

    private func clearAllPresentation() {
        isPaused = false
        clearOutcomePresentation()
        preview = nil
        overlayCombatantDetail = nil
        clearFeedback()
        overlayPauseDepth = 0
        pauseStateBeforeOverlay = nil
    }

    private func recordFeedbackEvents(_ events: [ActionEvent], at date: Date = .now) {
        for event in events {
            activeFeedbackEvents.append(event)
            feedbackDisplayedAt[event.id] = date
            feedbackEventsByTargetID[event.targetID, default: []].append(event)
        }
    }

    private func clearFeedback() {
        activeFeedbackEvents = []
        feedbackEventsByTargetID = [:]
        feedbackDisplayedAt = [:]
    }

    private func resetRun(from configuration: ActiveBattleConfiguration) {
        state = BattleState(
            hero: configuration.hero.combatant,
            pet: configuration.pet.combatant,
            enemy: configuration.enemy,
            heroModifiers: configuration.hero.modifiers,
            petModifiers: configuration.pet.modifiers,
            enemyModifiers: configuration.enemyModifiers,
            rngSeed: configuration.rngSeed,
            tracksLog: false
        )
        clearFeedback()
        clearOutcomePresentation()
        isPaused = false
        overlayCombatantDetail = nil
    }

    private func clearRunState() {
        state = nil
        clearFeedback()
        clearOutcomePresentation()
    }
}
