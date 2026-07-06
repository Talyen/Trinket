import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketPersistence

@MainActor
@Observable
final class BattleSession {
    let presentation = BattlePresentationState()

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

    var outcome: BattleSimulationOutcome? {
        guard let state else { return nil }
        return BattleSimulationOutcome.resolve(
            isPartyDefeated: state.isPartyDefeated,
            isEnemyDefeated: state.isEnemyDefeated
        )
    }

    func endBattle() {
        activeBattle = nil
        presentation.clearAll()
        onBattleStateChange?(nil)
        onBattleEnded?()
    }

    func notifyBattleStarted(stageID: String) {
        onBattleStateChange?(stageID)
    }

    var isPaused: Bool {
        get { presentation.isPaused }
        set { presentation.isPaused = newValue }
    }

    var isShowingVictory: Bool {
        get { presentation.isShowingVictory }
        set { presentation.isShowingVictory = newValue }
    }

    var isShowingDefeat: Bool {
        get { presentation.isShowingDefeat }
        set { presentation.isShowingDefeat = newValue }
    }

    var victorySummary: BattleVictorySummary? {
        get { presentation.victorySummary }
        set { presentation.victorySummary = newValue }
    }

    var preview: BattleMusicPreview? {
        get { presentation.preview }
        set { presentation.preview = newValue }
    }

    var overlayCombatantDetail: CombatantDetailContext? {
        get { presentation.overlayCombatantDetail }
        set { presentation.overlayCombatantDetail = newValue }
    }

    var activeFeedbackEvents: [ActionEvent] {
        get { presentation.activeFeedbackEvents }
        set { presentation.activeFeedbackEvents = newValue }
    }

    func setMusicPreview(for stage: Stage?) {
        presentation.setMusicPreview(for: stage, battleIsActive: activeBattle != nil)
    }

    func pauseForOverlay() {
        presentation.pauseForOverlay(battleIsActive: activeBattle != nil)
    }

    func restorePauseAfterOverlay() {
        presentation.restorePauseAfterOverlay(battleIsActive: activeBattle != nil)
    }

    func presentCombatantDetail(_ detail: CombatantCardDetail) {
        presentation.presentCombatantDetail(detail, battleIsActive: activeBattle != nil)
    }

    func clearOutcomePresentation() {
        presentation.clearOutcomePresentation()
    }

    func feedbackEvents(for targetID: String) -> [ActionEvent] {
        presentation.feedbackEvents(for: targetID)
    }

    func syncLogForDisplay() {
        guard var state else { return }
        state.syncLog()
        self.state = state
    }

    func canAutoAdvanceTick() -> Bool {
        guard let state, !state.isBattleOver, !presentation.isPaused else { return false }
        return !presentation.isShowingVictory && !presentation.isShowingDefeat
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
        presentation.pruneExpiredFeedback(at: date)
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
            presentation.victorySummary = BattleVictorySummary.make(
                configuration: configuration,
                state: battleState,
                homestead: homestead
            )
            presentation.isShowingVictory = true
            return nil
        case .defeat:
            presentation.isShowingDefeat = true
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
        presentation.recordFeedbackEvents(
            step.events.filter { $0.kind != .milestone },
            at: .now
        )
        return step
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
        presentation.clearFeedback()
        presentation.clearOutcomePresentation()
        presentation.isPaused = false
        presentation.overlayCombatantDetail = nil
    }

    private func clearRunState() {
        state = nil
        presentation.clearFeedback()
        presentation.clearOutcomePresentation()
    }
}
