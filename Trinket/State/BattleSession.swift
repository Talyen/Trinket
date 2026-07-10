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
    private(set) var hitReactionsByTargetID: [String: CombatantHitReaction] = [:]
    private(set) var keywordBurstsByTargetID: [String: [KeywordBurstRequest]] = [:]

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

    private(set) var state: BattleState?

    private var feedbackEventRecordedAt: [Int: Date] = [:]
    private var presentedFeedbackIDs: Set<Int> = []
    private var presentationHoldCount = 0
    private var softHoldUntil: Date?
    private var deferredFeedbackEvents: [ActionEvent] = []
    private var nextSpectacleID = 0
    /// Actor IDs (Hero/Pet) that already presented a full-screen Ultimate this battle.
    private var actorsWhoPresentedUltimateThisBattle: Set<String> = []
    @ObservationIgnored
    private var pendingAutoEndTask: Task<Void, Never>?
    @ObservationIgnored
    private var pendingFeedbackPruneTask: Task<Void, Never>?
    @ObservationIgnored
    private var autoEndJourney: JourneyProgressState?
    @ObservationIgnored
    private var autoEndHomestead: PlayerHomesteadState?

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
        presentationHoldCount = max(0, presentationHoldCount - 1)
        let deferred = deferredFeedbackEvents
        deferredFeedbackEvents = []
        recordFeedbackEvents(deferred, at: date, stagger: CombatFeedbackTiming.ultimateChipStagger)
        scheduleAutoEndIfNeeded()
    }

    func beginCinematicCollapse() {
        guard var cinematic = activeCinematic, cinematic.phase != .collapsing else { return }
        cinematic.phase = .collapsing
        activeCinematic = cinematic
    }

    private func handleOutcomeIfNeeded(
        at _: Date,
        journey: JourneyProgressState,
        homestead: PlayerHomesteadState
    ) -> Int? {
        guard let configuration = activeBattle else { return nil }
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
            playSFX(SFXID.victory)
            return nil
        case .defeat:
            isShowingDefeat = true
            playSFX(SFXID.defeat)
            return nil
        case .none:
            return nil
        }
    }

    private func presentResolvedEvents(_ events: [ActionEvent], at date: Date) {
        let nonMilestone = events.filter { $0.kind != .milestone }
        guard let state else {
            recordFeedbackEvents(nonMilestone, at: date, stagger: 0)
            return
        }
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
                recordFeedbackEvents(nonMilestone, at: date, stagger: 0)
                return
            }
            deferredFeedbackEvents = nonMilestone
            beginCinematic(from: ultimate, at: date)
            return
        }

        recordFeedbackEvents(nonMilestone, at: date, stagger: 0)
        presentCallouts(from: nonMilestone, heroID: heroID, petID: petID, at: date)
    }

    private func beginCinematic(from event: ActionEvent, at date: Date) {
        nextSpectacleID += 1
        presentationHoldCount += 1
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
        clearOutcomePresentation()
        preview = nil
        overlayCombatantDetail = nil
        overlayAbilityDetail = nil
        isShowingBattleLog = false
        clearFeedback()
        clearSpectacle()
        presentationHoldCount = 0
    }

    private func recordFeedbackEvents(
        _ events: [ActionEvent],
        at date: Date = .now,
        stagger: TimeInterval
    ) {
        for event in events {
            activeFeedbackEvents.append(event)
            feedbackEventRecordedAt[event.id] = date
        }

        let items = CombatFeedbackPresenter.makeItems(from: events, at: date, stagger: stagger)
        activeFeedbackItems.append(contentsOf: items)
        applyImmediatePresentation(for: items, at: date)
        scheduleFeedbackPruneIfNeeded(at: date)
    }

    private func scheduleFeedbackPruneIfNeeded(at date: Date) {
        pendingFeedbackPruneTask?.cancel()
        guard let latestExpiry = activeFeedbackItems.map(\.expiresAt).max() else { return }
        let delay = max(0, latestExpiry.timeIntervalSince(date)) + 0.02
        pendingFeedbackPruneTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            self.pruneExpiredFeedback()
        }
    }

    private func applyImmediatePresentation(for items: [CombatFeedbackItem], at date: Date) {
        let due = items.filter { $0.availableAt <= date && !presentedFeedbackIDs.contains($0.id) }
        guard !due.isEmpty else { return }

        for clipID in CombatSFXMapper.uniqueClipIDs(for: due) {
            playSFX(clipID)
        }

        for item in due {
            presentedFeedbackIDs.insert(item.id)
            if let reaction = CombatFeedbackPresenter.reaction(for: [item]) {
                hitReactionsByTargetID[item.targetID] = reaction
            }
        }

        let bursts = CombatFeedbackPresenter.bursts(for: due)
        for burst in bursts {
            guard let targetID = due.first(where: { $0.id == burst.id })?.targetID else { continue }
            var existing = keywordBurstsByTargetID[targetID, default: []]
            existing.append(burst)
            if existing.count > TrinketMotion.Battle.maxKeywordBurstsPerPane {
                existing = Array(existing.suffix(TrinketMotion.Battle.maxKeywordBurstsPerPane))
            }
            keywordBurstsByTargetID[targetID] = existing
        }
    }

    private func playSFX(_ id: String) {
        guard let sfxPlayer else { return }
        sfxPlayer.play(id, volume: options?.effectsVolume ?? 0)
    }

    private func clearFeedback() {
        pendingFeedbackPruneTask?.cancel()
        pendingFeedbackPruneTask = nil
        activeFeedbackEvents = []
        activeFeedbackItems = []
        feedbackEventRecordedAt = [:]
        hitReactionsByTargetID = [:]
        keywordBurstsByTargetID = [:]
        presentedFeedbackIDs = []
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

    private func scheduleAutoEndIfNeeded() {
        cancelPendingAutoEnd()
        guard canEndTurn, !hasPlayableCard,
              let journey = autoEndJourney,
              let homestead = autoEndHomestead else { return }

        let delay = Self.autoEndTurnDelay
        pendingAutoEndTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            guard self.canEndTurn, !self.hasPlayableCard else { return }
            let earnedGold = self.endTurn(journey: journey, homestead: homestead)
            self.onTurnAutoEnded?(earnedGold)
        }
    }

    private func cancelPendingAutoEnd() {
        pendingAutoEndTask?.cancel()
        pendingAutoEndTask = nil
    }

    func resetRun(from configuration: ActiveBattleConfiguration) {
        cancelPendingAutoEnd()
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
        overlayCombatantDetail = nil
        overlayAbilityDetail = nil
        isShowingBattleLog = false
        playSFX(SFXID.abilityDraw) // opening hand
        BattleCinematicPlayer.shared.warmLoadout(
            heroUltimateID: configuration.hero.combatant.abilityLoadout.ultimate?.id,
            petUltimateID: configuration.pet.combatant.abilityLoadout.ultimate?.id
        )
    }

    func clearRunState() {
        cancelPendingAutoEnd()
        autoEndJourney = nil
        autoEndHomestead = nil
        state = nil
        clearFeedback()
        clearSpectacle()
        clearOutcomePresentation()
        overlayCombatantDetail = nil
        overlayAbilityDetail = nil
        isShowingBattleLog = false
        presentationHoldCount = 0
    }
}
