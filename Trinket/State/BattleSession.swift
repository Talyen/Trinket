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
    var isShowingVictory = false
    var isShowingDefeat = false
    var victorySummary: BattleVictorySummary?
    var preview: BattleMusicPreview?
    var overlayCombatantDetail: CombatantCardDetail?
    var overlayAbilityDetail: Ability?
    /// Presented from Play (not Options) so the log overlays the live battlefield.
    var isShowingBattleLog = false
    var activeFeedbackItems: [CombatFeedbackItem] = []
    /// Compatibility mirror of underlying events for tests that inspect event kinds.
    var activeFeedbackEvents: [ActionEvent] = []
    var activeSkillCallout: SkillCalloutPresentation?
    var activeCinematic: BattleCinematicPresentation?
    var hitReactionsByTargetID: [String: CombatantHitReaction] = [:]
    var keywordBurstsByTargetID: [String: [KeywordBurstRequest]] = [:]

    /// Optional Options store for Ultimate skip policy. Injected by AppState when available.
    @ObservationIgnored
    var options: OptionsStore?

    /// Optional SFX player for combat feedback and draw cues. Injected by AppState.
    @ObservationIgnored
    var sfxPlayer: SFXPlayer?

    /// Fired when a delayed auto-end resolves; carries earned gold for already-claimed stages.
    @ObservationIgnored
    var onTurnAutoEnded: ((Int?) -> Void)?

    var activeBattle: ActiveBattleConfiguration? {
        didSet {
            if let activeBattle {
                resetRun(from: activeBattle)
            } else {
                clearRunState()
            }
        }
    }

    var state: BattleState?

    var feedbackEventRecordedAt: [Int: Date] = [:]
    var presentedFeedbackIDs: Set<Int> = []
    var presentationHoldCount = 0
    var softHoldUntil: Date?
    var deferredFeedbackEvents: [ActionEvent] = []
    var nextSpectacleID = 0
    /// Actor IDs (Hero/Pet) that already presented a full-screen Ultimate this battle.
    var actorsWhoPresentedUltimateThisBattle: Set<String> = []
    @ObservationIgnored
    var pendingAutoEndTask: Task<Void, Never>?
    @ObservationIgnored
    var pendingFeedbackPruneTask: Task<Void, Never>?
    @ObservationIgnored
    var autoEndJourney: JourneyProgressState?
    @ObservationIgnored
    var autoEndHomestead: PlayerHomesteadState?

    /// Beat after the last playable card so feedback can show before the turn advances.
    static let autoEndTurnDelay: TimeInterval = 0.4

    var outcome: BattleSimulationOutcome? {
        guard let state else { return nil }
        return BattleSimulationOutcome.resolve(
            isPartyDefeated: state.isPartyDefeated,
            isEnemyDefeated: state.isEnemyDefeated
        )
    }

    var hand: [BattleCard] {
        state?.hand.cards ?? []
    }

    var canEndTurn: Bool {
        guard let state else { return false }
        return state.phase == .playerTurn && !state.isBattleOver
            && activeCinematic == nil
            && !isShowingVictory && !isShowingDefeat
    }

    var hasPlayableCard: Bool {
        hand.contains { isCardPlayable($0) }
    }

    func endBattle() {
        cancelPendingAutoEnd()
        activeBattle = nil
        clearAllPresentation()
    }

    /// Schedules a delayed end turn when nothing in hand is playable.
    func considerAutoEndTurn(
        journey: JourneyProgressState,
        homestead: PlayerHomesteadState
    ) {
        autoEndJourney = journey
        autoEndHomestead = homestead
        scheduleAutoEndIfNeeded()
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

    func presentCombatantDetail(_ detail: CombatantCardDetail) {
        overlayCombatantDetail = detail
    }

    func presentAbilityDetail(_ ability: Ability) {
        overlayAbilityDetail = ability
    }

    func clearAbilityDetail() {
        overlayAbilityDetail = nil
    }

    func presentBattleLog() {
        syncLogForDisplay()
        isShowingBattleLog = true
    }

    func clearBattleLog() {
        isShowingBattleLog = false
    }

    func clearOutcomePresentation() {
        isShowingVictory = false
        isShowingDefeat = false
        victorySummary = nil
    }

    func feedbackItems(for targetID: String, at date: Date = .now) -> [CombatFeedbackItem] {
        activeFeedbackItems.filter { item in
            item.targetID == targetID && date >= item.availableAt && date < item.expiresAt
        }
    }

    func keywordBursts(for targetID: String, at date: Date = .now) -> [KeywordBurstRequest] {
        (keywordBurstsByTargetID[targetID] ?? []).filter { burst in
            date >= burst.availableAt && date < burst.expiresAt
        }
    }

    func removeFeedbackEvent(_ id: Int) {
        if let item = activeFeedbackItems.first(where: { $0.id == id }) {
            keywordBurstsByTargetID[item.targetID]?.removeAll { $0.id == id }
        }
        activeFeedbackEvents.removeAll { $0.id == id }
        activeFeedbackItems.removeAll { $0.id == id }
        feedbackEventRecordedAt.removeValue(forKey: id)
        presentedFeedbackIDs.remove(id)
    }

    func pruneExpiredFeedback(at date: Date = .now) {
        applyImmediatePresentation(for: activeFeedbackItems, at: date)
        let expiredItemIDs = activeFeedbackItems.compactMap { item in
            date >= item.expiresAt ? item.id : nil
        }
        for eventID in expiredItemIDs {
            removeFeedbackEvent(eventID)
        }
        let maxRawLifetime = TrinketMotion.Battle.maxChipLifetime
        let expiredRawIDs = feedbackEventRecordedAt.compactMap { eventID, recordedAt in
            date.timeIntervalSince(recordedAt) >= maxRawLifetime ? eventID : nil
        }
        for eventID in expiredRawIDs where activeFeedbackEvents.contains(where: { $0.id == eventID }) {
            removeFeedbackEvent(eventID)
        }
        for (targetID, bursts) in keywordBurstsByTargetID {
            keywordBurstsByTargetID[targetID] = bursts.filter { date < $0.expiresAt }
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

    func isCardPlayable(_ card: BattleCard) -> Bool {
        state?.isCardPlayable(card) ?? false
    }

    /// Plays a card from hand. Returns earned gold when an already-claimed stage
    /// victory should auto-complete without showing the victory screen.
    @discardableResult
    func playCard(
        cardID: Int,
        at date: Date = .now,
        journey: JourneyProgressState,
        homestead: PlayerHomesteadState
    ) -> Int? {
        cancelPendingAutoEnd()
        pruneExpiredFeedback(at: date)
        autoEndJourney = journey
        autoEndHomestead = homestead
        guard activeCinematic == nil,
              !isShowingVictory,
              !isShowingDefeat,
              var battleState = state else { return nil }

        do {
            let events = try battleState.playCard(cardID: cardID, rebuildLog: false)
            state = battleState
            presentResolvedEvents(events, at: date)
            let earnedGold = handleOutcomeIfNeeded(at: date, journey: journey, homestead: homestead)
            if earnedGold == nil {
                scheduleAutoEndIfNeeded()
            }
            return earnedGold
        } catch {
            playSFX(SFXID.uiDeny)
            return nil
        }
    }

    /// Ends the player turn (enemy acts, effects tick, draw). Returns earned gold
    /// when an already-claimed stage victory should auto-complete.
    @discardableResult
    func endTurn(
        at date: Date = .now,
        journey: JourneyProgressState,
        homestead: PlayerHomesteadState
    ) -> Int? {
        cancelPendingAutoEnd()
        pruneExpiredFeedback(at: date)
        autoEndJourney = journey
        autoEndHomestead = homestead
        guard canEndTurn, var battleState = state else { return nil }

        let events = battleState.endTurn(rebuildLog: false)
        state = battleState
        // Draw SFX only when the round completed and cards were dealt for the next turn.
        if battleState.phase == .playerTurn {
            playSFX(SFXID.abilityDraw)
        }
        presentResolvedEvents(events, at: date)
        let earnedGold = handleOutcomeIfNeeded(at: date, journey: journey, homestead: homestead)
        if earnedGold == nil {
            scheduleAutoEndIfNeeded()
        }
        return earnedGold
    }

    static func stageRewardsAlreadyClaimed(
        stageID: String?,
        journey: JourneyProgressState
    ) -> Bool {
        guard let stageID,
              let stage = GameContent.stage(id: stageID) else { return false }
        return journey.hasClaimedRewards(for: stage)
    }
}
