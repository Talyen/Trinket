import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

/// Owns battle simulation state and UI-facing presentation: overlays, outcome screens,
/// feedback, spectacle (Skill callouts / Ultimate cinematics), and music preview.
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
    var activeSkillCallout: SkillCalloutPresentation?
    var activeCinematic: BattleCinematicPresentation?

    /// Optional Options store for Ultimate skip policy. Injected by AppState when available.
    @ObservationIgnored
    var options: OptionsStore?

    var activeBattle: ActiveBattleConfiguration? {
        didSet {
            if let activeBattle {
                resetRun(from: activeBattle)
                onBattleStateChange?(activeBattle.stageID)
            } else {
                clearRunState()
            }
        }
    }

    private(set) var state: BattleState?
    var onBattleStateChange: ((String?) -> Void)?

    private var feedbackEventsByTargetID: [String: [ActionEvent]] = [:]
    private var feedbackDisplayedAt: [Int: Date] = [:]
    /// Nested overlay + cinematic holds that force `isPaused` until the last hold ends.
    private var presentationHoldCount = 0
    private var pauseStateBeforeHold: Bool?
    private var softHoldUntil: Date?
    private var deferredFeedbackEvents: [ActionEvent] = []
    private var nextSpectacleID = 0
    /// Actor IDs (Hero/Pet) that already presented a full-screen Ultimate this battle.
    private var actorsWhoPresentedUltimateThisBattle: Set<String> = []

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
        if presentationHoldCount == 0 {
            pauseStateBeforeHold = isPaused
        }
        presentationHoldCount += 1
        isPaused = true
    }

    func restorePauseAfterOverlay() {
        guard presentationHoldCount > 0 else { return }
        presentationHoldCount -= 1
        guard presentationHoldCount == 0 else { return }
        guard activeBattle != nil else {
            pauseStateBeforeHold = nil
            return
        }
        isPaused = pauseStateBeforeHold ?? false
        pauseStateBeforeHold = nil
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

    func skillCallout(for actorID: String) -> SkillCalloutPresentation? {
        guard let activeSkillCallout, activeSkillCallout.actorID == actorID else { return nil }
        return activeSkillCallout
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
        pruneExpiredSkillCallout(at: date)
        pruneSoftHold(at: date)
    }

    func trimMemoryFootprint(releaseBattleLog: Bool) {
        pruneExpiredFeedback()
        guard releaseBattleLog, var state else { return }
        state.releaseLogProjection()
        self.state = state
    }

    func syncLogForDisplay() {
        guard var state else { return }
        state.syncLog()
        self.state = state
    }

    func canAutoAdvanceTick(at date: Date = .now) -> Bool {
        pruneSoftHold(at: date)
        pruneExpiredSkillCallout(at: date)
        guard let state, !state.isBattleOver, !isPaused else { return false }
        guard !isShowingVictory, !isShowingDefeat else { return false }
        guard activeCinematic == nil else { return false }
        if let softHoldUntil, date < softHoldUntil { return false }
        return true
    }

    /// Advances one battle tick when unpaused. Returns earned gold when an already-claimed stage
    /// victory should auto-complete without showing the victory screen.
    @discardableResult
    func advanceAutoTick(
        at date: Date = .now,
        journey: JourneyProgressState,
        homestead: PlayerHomesteadState
    ) -> Int? {
        pruneExpiredFeedback(at: date)
        guard canAutoAdvanceTick(at: date),
              let configuration = activeBattle else { return nil }

        advanceOneStep(at: date)

        switch outcome {
        case .victory:
            if Self.stageRewardsAlreadyClaimed(
                stageID: configuration.stageID,
                journey: journey
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
        journey: JourneyProgressState
    ) -> Bool {
        guard let stageID,
              let stage = GameContent.stage(id: stageID) else { return false }
        return journey.hasClaimedRewards(for: stage)
    }

    @discardableResult
    func advanceOneStep(at date: Date = .now) -> BattleStep? {
        guard var state else { return nil }
        let step = state.advanceOneStep(rebuildLog: false)
        self.state = state

        let nonMilestone = step.events.filter { $0.kind != .milestone }
        let heroID = state.hero.id
        let petID = state.pet.id

        if let ultimate = nonMilestone.first(where: {
            BattleSpectaclePolicy.shouldPresentUltimateCinematic(
                for: $0,
                heroID: heroID,
                petID: petID
            )
        }) {
            let autoSkip = options?.shouldAutoSkipUltimateCinematic(
                actorID: ultimate.actorID,
                actorsWhoPresentedThisBattle: actorsWhoPresentedUltimateThisBattle
            ) ?? false
            if autoSkip {
                recordFeedbackEvents(nonMilestone, at: date)
                return step
            }
            deferredFeedbackEvents = nonMilestone
            beginCinematic(from: ultimate, at: date)
            return step
        }

        recordFeedbackEvents(nonMilestone, at: date)
        presentCallouts(from: nonMilestone, heroID: heroID, petID: petID, at: date)
        return step
    }
}

extension BattleSession {
    func markCinematicPlaying() {
        guard var cinematic = activeCinematic, cinematic.phase == .expanding else { return }
        cinematic.phase = .playing
        activeCinematic = cinematic
    }

    func requestSkipCinematic(at date: Date = .now) {
        guard activeCinematic != nil else { return }
        guard date >= (activeCinematic?.skipArmedAt ?? .distantPast) else { return }
        guard options?.canSkipUltimateCinematic() ?? true else { return }
        beginCinematicCollapse()
    }

    func completeCinematicCollapse(at date: Date = .now) {
        guard let cinematic = activeCinematic else { return }
        actorsWhoPresentedUltimateThisBattle.insert(cinematic.actorID)
        activeCinematic = nil
        restorePauseAfterOverlay()
        let deferred = deferredFeedbackEvents
        deferredFeedbackEvents = []
        recordFeedbackEvents(deferred, at: date)
    }

    func beginCinematicCollapse() {
        guard var cinematic = activeCinematic, cinematic.phase != .collapsing else { return }
        cinematic.phase = .collapsing
        activeCinematic = cinematic
    }

    private func beginCinematic(from event: ActionEvent, at date: Date) {
        nextSpectacleID += 1
        pauseForOverlay()
        activeCinematic = BattleCinematicPresentation(
            id: nextSpectacleID,
            actorID: event.actorID,
            actorName: event.actorName,
            abilityID: event.abilityID,
            abilityName: event.abilityName,
            keyword: event.keyword,
            phase: .expanding,
            startedAt: date,
            skipArmedAt: date.addingTimeInterval(TrinketMotion.Battle.ultimateSkipLockout)
        )
        BattleCinematicPlayer.shared.warm(abilityID: event.abilityID)
    }

    private func presentCallouts(
        from events: [ActionEvent],
        heroID: String,
        petID: String,
        at date: Date
    ) {
        let calloutEvent = events.first {
            BattleSpectaclePolicy.shouldPresentSkillCallout(for: $0)
                || BattleSpectaclePolicy.shouldPresentEnemyUltimateAsCallout(
                    for: $0,
                    heroID: heroID,
                    petID: petID
                )
        }
        guard let calloutEvent else { return }
        nextSpectacleID += 1
        let hold = TrinketMotion.Battle.skillSoftHold
        softHoldUntil = date.addingTimeInterval(hold)
        activeSkillCallout = SkillCalloutPresentation(
            id: nextSpectacleID,
            actorID: calloutEvent.actorID,
            abilityID: calloutEvent.abilityID,
            abilityName: calloutEvent.abilityName,
            keyword: calloutEvent.keyword,
            expiresAt: date.addingTimeInterval(max(hold, TrinketMotion.Battle.skillCalloutTotal))
        )
    }

    private func clearAllPresentation() {
        isPaused = false
        clearOutcomePresentation()
        preview = nil
        overlayCombatantDetail = nil
        clearFeedback()
        clearSpectacle()
        presentationHoldCount = 0
        pauseStateBeforeHold = nil
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

    private func clearSpectacle() {
        activeSkillCallout = nil
        activeCinematic = nil
        deferredFeedbackEvents = []
        softHoldUntil = nil
        actorsWhoPresentedUltimateThisBattle = []
        BattleCinematicPlayer.shared.releaseAll()
    }

    private func pruneExpiredSkillCallout(at date: Date) {
        guard let activeSkillCallout, date >= activeSkillCallout.expiresAt else { return }
        self.activeSkillCallout = nil
    }

    private func pruneSoftHold(at date: Date) {
        guard let softHoldUntil, date >= softHoldUntil else { return }
        self.softHoldUntil = nil
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
        clearSpectacle()
        clearOutcomePresentation()
        isPaused = false
        overlayCombatantDetail = nil
        BattleCinematicPlayer.shared.warmLoadout(
            heroUltimateID: configuration.hero.combatant.abilityLoadout.ultimate?.id,
            petUltimateID: configuration.pet.combatant.abilityLoadout.ultimate?.id
        )
    }

    private func clearRunState() {
        state = nil
        clearFeedback()
        clearSpectacle()
        clearOutcomePresentation()
        overlayCombatantDetail = nil
        presentationHoldCount = 0
        pauseStateBeforeHold = nil
        isPaused = false
    }
}
