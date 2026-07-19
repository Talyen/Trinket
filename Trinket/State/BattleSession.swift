import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

enum BattleCardPlayResolution: Equatable, Sendable {
    case rejected
    case committed(earnedGold: Int?)

    var earnedGold: Int? {
        guard case let .committed(earnedGold) = self else { return nil }
        return earnedGold
    }

    var didCommit: Bool {
        guard case .committed = self else { return false }
        return true
    }
}

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
    /// Observation fences for combat presentation lanes. Burst / hit-reaction / attack
    /// storage is ignored; lanes subscribe to the epochs so publishes invalidate SwiftUI.
    private(set) var burstEpoch = 0
    private(set) var hitReactionEpoch = 0
    private(set) var attackReactionEpoch = 0
    @ObservationIgnored
    var activeFeedbackItems: [CombatFeedbackItem] = []
    /// Optional UIKit chip-bridge hook. Feature chrome installs this so chip publishes
    /// update always-mounted hosts without invalidating SwiftUI battle chrome.
    @ObservationIgnored
    var onFeedbackItemsChanged: ((CombatFeedbackUpdate) -> Void)?
    var activeSkillCallout: SkillCalloutPresentation?
    var activeCinematic: BattleCinematicPresentation?
    @ObservationIgnored
    var hitReactionsByTargetID: [String: CombatantHitReaction] = [:]
    @ObservationIgnored
    var attackReactionsByCombatantID: [String: CombatantAttackReaction] = [:]
    @ObservationIgnored
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

    /// Authoritative simulation value. UI observes `presentation` instead, avoiding
    /// app-wide invalidation when log/event internals change.
    @ObservationIgnored
    var state: BattleState?
    let presentation = BattlePresentationState()

    @ObservationIgnored
    var feedbackEventRecordedAt: [Int: Date] = [:]
    @ObservationIgnored
    var presentedFeedbackIDs: Set<Int> = []
    var presentationHoldCount = 0
    var softHoldUntil: Date?
    var deferredFeedbackEvents: [ActionEvent] = []
    var nextSpectacleID = 0
    /// Actor IDs (Hero/Companion) that already presented a full-screen Ultimate this battle.
    var actorsWhoPresentedUltimateThisBattle: Set<String> = []
    @ObservationIgnored
    var pendingAutoEndTask: Task<Void, Never>?
    @ObservationIgnored
    var feedbackScheduler: BattleFeedbackScheduler?
    /// Next prune fire time for the long-lived prune loop (no per-publish Task alloc).
    @ObservationIgnored
    var nextFeedbackPruneAt: Date?
    /// Next visual start per combatant lane (left / middle / right).
    @ObservationIgnored
    var nextFeedbackVisualStartByTargetLane: [String: [Date]] = [:]
    @ObservationIgnored
    var pendingOutcomePresentationTask: Task<Void, Never>?
    @ObservationIgnored
    var pendingPartyCelebrateTask: Task<Void, Never>?
    @ObservationIgnored
    var preparedBattleRunsByToken: [ActiveBattleResumeToken: PreparedBattleRun] = [:]
    @ObservationIgnored
    var pendingPreparedRun: PreparedBattleRun?

    var preparedBattleRun: PreparedBattleRun? {
        preparedBattleRunsByToken.values.first
    }

    @ObservationIgnored
    var autoEndJourney: JourneyProgressState?
    @ObservationIgnored
    var autoEndHomestead: PlayerHomesteadState?

    /// Test seam for outcome timing. Production derives the delay from active spectacle.
    @ObservationIgnored
    var outcomePresentationDelayOverride: TimeInterval?

    /// Beat after the last playable card so feedback can show before the turn advances.
    static let autoEndTurnDelay: TimeInterval = 0.4

    /// Injectable for deterministic tests; production uses the presentation delay above.
    @ObservationIgnored
    var autoEndTurnDelay: TimeInterval

    /// Gap between paced opening-hand draws. `<= 0` deals the hand synchronously in `resetRun`
    /// (unit tests). Production uses `TrinketMotion.Battle.cardDrawStagger`.
    @ObservationIgnored
    var openingHandDrawStagger: TimeInterval

    /// True while the opening hand is still being drawn into presentation.
    var isDealingOpeningHand = false

    @ObservationIgnored
    var pendingOpeningHandDealTask: Task<Void, Never>?

    /// Test seam for attack telegraph impact timing. Production uses the attack recipe.
    @ObservationIgnored
    var enemyAttackImpactDelayOverride: TimeInterval?

    init(
        autoEndTurnDelay: TimeInterval = BattleSession.autoEndTurnDelay,
        openingHandDrawStagger: TimeInterval = TrinketMotion.Battle.cardDrawStagger,
        enemyAttackImpactDelayOverride: TimeInterval? = nil,
        outcomePresentationDelayOverride: TimeInterval? = nil
    ) {
        self.autoEndTurnDelay = autoEndTurnDelay
        self.openingHandDrawStagger = openingHandDrawStagger
        self.enemyAttackImpactDelayOverride = enemyAttackImpactDelayOverride
        self.outcomePresentationDelayOverride = outcomePresentationDelayOverride
    }

    var outcome: BattleSimulationOutcome? {
        guard let state else { return nil }
        return BattleSimulationOutcome.resolve(
            isPartyDefeated: state.isPartyDefeated,
            isEnemyDefeated: state.isEnemyDefeated
        )
    }

    var hand: [BattleCard] {
        presentation.hand
    }

    var canEndTurn: Bool {
        guard let state else { return false }
        return state.phase == .playerTurn && !state.isBattleOver
            && !isDealingOpeningHand
            && activeCinematic == nil
            && !isShowingVictory && !isShowingDefeat
    }

    /// Retreat is closed once the fight is decided, including the spectacle hold
    /// before victory/defeat chrome appears.
    var canRetreat: Bool {
        activeBattle != nil && !presentation.isBattleOver && !isShowingVictory && !isShowingDefeat
    }

    var hasPlayableCard: Bool {
        hand.contains { isCardPlayable($0) }
    }

    func endBattle() {
        cancelPendingAutoEnd()
        cancelOpeningHandDeal()
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

    func presentBattleLog() {
        syncLogForDisplay()
        isShowingBattleLog = true
    }

    func clearBattleLog() {
        isShowingBattleLog = false
    }

    func clearOutcomePresentation() {
        pendingOutcomePresentationTask?.cancel()
        pendingOutcomePresentationTask = nil
        if isShowingVictory {
            isShowingVictory = false
        }
        if isShowingDefeat {
            isShowingDefeat = false
        }
        if victorySummary != nil {
            victorySummary = nil
        }
    }

    func keywordBursts(for targetID: String, at date: Date = .now) -> [KeywordBurstRequest] {
        (keywordBurstsByTargetID[targetID] ?? []).filter { burst in
            date >= burst.availableAt && date < burst.expiresAt
        }
    }

    func noteFeedbackPresentationChanged() {
        onFeedbackItemsChanged?(.replace(activeFeedbackItems))
    }

    func noteBurstPresentationChanged() {
        burstEpoch &+= 1
    }

    func noteHitReactionPresentationChanged() {
        hitReactionEpoch &+= 1
    }

    func noteAttackReactionPresentationChanged() {
        attackReactionEpoch &+= 1
    }

    func resetFeedbackPresentation() {
        burstEpoch &+= 1
        hitReactionEpoch &+= 1
        attackReactionEpoch &+= 1
        onFeedbackItemsChanged?(.reset)
    }

    func removeFeedbackEvent(_ id: Int, noteChange: Bool = true) {
        if let item = activeFeedbackItems.first(where: { $0.sourceEventIDs.contains(id) }) {
            let sourceEventIDs = Set(item.sourceEventIDs)
            keywordBurstsByTargetID[item.targetID]?.removeAll { $0.id == item.id }
            var clearedReaction = false
            if hitReactionsByTargetID[item.targetID]?.id == item.id {
                hitReactionsByTargetID.removeValue(forKey: item.targetID)
                clearedReaction = true
            }
            activeFeedbackItems.removeAll { $0.id == item.id }
            for sourceEventID in sourceEventIDs {
                feedbackEventRecordedAt.removeValue(forKey: sourceEventID)
                presentedFeedbackIDs.remove(sourceEventID)
            }
            if clearedReaction {
                noteHitReactionPresentationChanged()
            }
            if noteChange {
                onFeedbackItemsChanged?(.remove([item.id]))
            }
            return
        }
        feedbackEventRecordedAt.removeValue(forKey: id)
        presentedFeedbackIDs.remove(id)
    }

    func pruneExpiredFeedback(at date: Date = .now, notifyPresentation: Bool = true) {
        let expiredItemIDs = activeFeedbackItems.compactMap { item in
            date >= item.expiresAt ? item.id : nil
        }
        var removedItemIDs: Set<Int> = []
        for eventID in expiredItemIDs {
            let beforeCount = activeFeedbackItems.count
            removeFeedbackEvent(eventID, noteChange: false)
            if activeFeedbackItems.count != beforeCount {
                removedItemIDs.insert(eventID)
            }
        }
        let maxRawLifetime = TrinketMotion.Battle.maxChipLifetime
        let expiredRawIDs: [Int] = feedbackEventRecordedAt.compactMap { entry -> Int? in
            let (eventID, recordedAt) = entry
            guard date.timeIntervalSince(recordedAt) >= maxRawLifetime else { return nil }
            let hasScheduledItem = activeFeedbackItems.contains { $0.sourceEventIDs.contains(eventID) }
            return hasScheduledItem ? nil : eventID
        }
        for eventID in expiredRawIDs {
            removeFeedbackEvent(eventID, noteChange: false)
        }
        var prunedBursts = false
        for (targetID, bursts) in keywordBurstsByTargetID {
            let kept = bursts.filter { date < $0.expiresAt }
            if kept.count != bursts.count {
                keywordBurstsByTargetID[targetID] = kept
                prunedBursts = true
            }
        }
        if !removedItemIDs.isEmpty, notifyPresentation {
            onFeedbackItemsChanged?(.remove(removedItemIDs))
        }
        if prunedBursts {
            noteBurstPresentationChanged()
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

    /// Eagerly prepares battle audio before activation. Repeated calls are cheap
    /// because both caches skip already-prepared resources.
    func prepareBattlePresentation(heroUltimateID: String?, companionUltimateID: String?) {
        sfxPlayer?.warm(SFXID.battlePrewarmIDs, concurrentPlayerCount: 2)
        BattleCinematicPlayer.shared.warmLoadout(
            heroUltimateID: heroUltimateID,
            companionUltimateID: companionUltimateID
        )
    }

    func syncLogForDisplay() {
        guard var state else { return }
        state.syncLog()
        self.state = state
    }

    func isCardPlayable(_ card: BattleCard) -> Bool {
        state?.isCardPlayable(card) ?? false
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
        pruneExpiredFeedback(at: date, notifyPresentation: false)
        autoEndJourney = journey
        autoEndHomestead = homestead
        guard canEndTurn, var battleState = state else {
            noteFeedbackPresentationChanged()
            return nil
        }

        let transitionInterval = BattleFramePacingSignposts.signposter.beginInterval(
            BattleFramePacingSignposts.Name.turnTransition
        )
        defer {
            BattleFramePacingSignposts.signposter.endInterval(
                BattleFramePacingSignposts.Name.turnTransition,
                transitionInterval
            )
        }
        let events = battleState.endTurn(rebuildLog: false)
        installBattleState(battleState)
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
