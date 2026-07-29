import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

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

/// Presentation controller for an active battle: overlays, outcome screens, feedback,
/// spectacle, and timing. Simulation mutations go through `BattleSimBridge`.
@MainActor
@Observable
public final class BattleSession {
    let feedback = BattleFeedbackLane()
    public let spectacle = BattleSpectacleState()
    @ObservationIgnored
    let presentationEnvironment: BattlePresentationEnvironment
    public var overlayCombatantDetail: CombatantCardDetail?
    public var overlayAbilityDetail: Ability?
    /// Presented from Play (not Options) so the log overlays the live battlefield.
    public var isShowingBattleLog = false
    /// Fired when a delayed auto-end resolves; carries earned gold for already-claimed stages.
    @ObservationIgnored
    var onTurnAutoEnded: ((Int?) -> Void)?

    public var activeBattle: ActiveBattleConfiguration? {
        didSet {
            if let activeBattle {
                resetRun(from: activeBattle)
            } else {
                clearRunState()
            }
        }
    }

    /// Authoritative simulation value. UI observes `presentation` instead, avoiding
    /// app-wide invalidation when log/event internals change. Mutations go through
    /// `BattleSimBridge` helpers so presentation timing stays off the engine surface.
    @ObservationIgnored
    public var state: BattleState?
    let presentation = BattlePresentationState()

    @ObservationIgnored
    var pendingAutoEndTask: Task<Void, Never>?
    /// When true, delayed auto-end (and its enemy telegraph) must not advance combat.
    /// Owned by AppState scene-phase reconciliation; independent of battle lifecycle.
    @ObservationIgnored
    public private(set) var isSuspendedForScenePhase = false
    @ObservationIgnored
    var preparedBattleRunsByKey: [BattleRunKey: PreparedBattleRun] = [:]
    @ObservationIgnored
    var pendingPreparedRun: PreparedBattleRun?

    var preparedBattleRun: PreparedBattleRun? {
        preparedBattleRunsByKey.values.first
    }

    /// Test seam for outcome timing. Production derives the delay from active spectacle.
    @ObservationIgnored
    var outcomePresentationDelayOverride: TimeInterval?

    /// Test seam for the one-frame party celebration beat.
    @ObservationIgnored
    var partyCelebrateDelayOverride: TimeInterval?

    /// Beat after the last playable card so feedback can show before the turn advances.
    public static let autoEndTurnDelay: TimeInterval = 0.4

    /// Injectable for deterministic tests; production uses the presentation delay above.
    @ObservationIgnored
    var autoEndTurnDelay: TimeInterval

    /// Gap between paced opening-hand draws. `<= 0` deals the hand synchronously in `resetRun`
    /// (unit tests). Production uses `TrinketMotion.Battle.cardDrawStagger`.
    @ObservationIgnored
    public var openingHandDrawStagger: TimeInterval

    /// True while the opening hand is still being drawn into presentation.
    var isDealingOpeningHand = false

    @ObservationIgnored
    var pendingOpeningHandDealTask: Task<Void, Never>?

    /// Test seam for attack telegraph impact timing. Production uses the attack recipe.
    @ObservationIgnored
    var enemyAttackImpactDelayOverride: TimeInterval?

    public init(
        autoEndTurnDelay: TimeInterval = BattleSession.autoEndTurnDelay,
        openingHandDrawStagger: TimeInterval = TrinketMotion.Battle.cardDrawStagger,
        enemyAttackImpactDelayOverride: TimeInterval? = nil,
        outcomePresentationDelayOverride: TimeInterval? = nil,
        presentationEnvironment: BattlePresentationEnvironment = .silent
    ) {
        self.autoEndTurnDelay = autoEndTurnDelay
        self.openingHandDrawStagger = openingHandDrawStagger
        self.enemyAttackImpactDelayOverride = enemyAttackImpactDelayOverride
        self.outcomePresentationDelayOverride = outcomePresentationDelayOverride
        self.presentationEnvironment = presentationEnvironment
    }

    var outcome: BattleSimulationOutcome? {
        BattleSimBridge.outcome(for: state)
    }

    var hand: [BattleCard] {
        presentation.hand
    }

    var canEndTurn: Bool {
        guard let state else { return false }
        return state.phase == .playerTurn && !state.isBattleOver
            && !isDealingOpeningHand
            && spectacle.activeCinematic == nil
            && !spectacle.isShowingVictory && !spectacle.isShowingDefeat
    }

    /// Retreat is closed once the fight is decided, including the spectacle hold
    /// before victory/defeat chrome appears.
    var canRetreat: Bool {
        activeBattle != nil && !presentation.isBattleOver && !spectacle.isShowingVictory && !spectacle.isShowingDefeat
    }

    var hapticsEnabled: Bool {
        presentationEnvironment.hapticsEnabled()
    }

    var effectsVolume: Double {
        presentationEnvironment.effectsVolume()
    }

    func playPresentationSFX(_ id: String) {
        presentationEnvironment.playSFX([id])
    }

    var hasPlayableCard: Bool {
        hand.contains { isCardPlayable($0) }
    }

    public func endBattle() {
        cancelPendingAutoEnd()
        cancelOpeningHandDeal()
        activeBattle = nil
        clearAllPresentation()
    }

    /// Schedules a delayed end turn when nothing in hand is playable.
    func considerAutoEndTurn() {
        scheduleAutoEndIfNeeded()
    }

    /// Pauses or resumes delayed auto-end around app background / inactive.
    /// Suspend cancels any in-flight auto-end; resume reschedules when still eligible.
    public func setSuspendedForScenePhase(_ suspended: Bool) {
        guard isSuspendedForScenePhase != suspended else { return }
        isSuspendedForScenePhase = suspended
        if suspended {
            cancelPendingAutoEnd()
        } else {
            scheduleAutoEndIfNeeded()
        }
    }

    public func presentBattleLog() {
        syncLogForDisplay()
        isShowingBattleLog = true
    }

    func clearBattleLog() {
        isShowingBattleLog = false
    }

    func clearOutcomePresentation() {
        spectacle.pendingOutcomePresentationTask?.cancel()
        spectacle.pendingOutcomePresentationTask = nil
        if spectacle.isShowingVictory {
            spectacle.isShowingVictory = false
        }
        if spectacle.isShowingDefeat {
            spectacle.isShowingDefeat = false
        }
        if spectacle.victorySummary != nil {
            spectacle.victorySummary = nil
        }
    }

    public func trimMemoryFootprint(releaseBattleLog: Bool) {
        let date = Date.now
        feedback.pruneExpired(at: date)
        pruneExpiredSkillCallout(at: date)
        pruneSoftHold(at: date)
        guard releaseBattleLog else { return }
        BattleSimBridge.releaseLogProjection(state: &state)
    }

    /// Eagerly prepares battle audio before activation. Repeated calls are cheap
    /// because both caches skip already-prepared resources.
    public func prepareBattlePresentation(heroUltimateID: String?, companionUltimateID: String?) {
        presentationEnvironment.warmSFX(SFXID.battlePrewarmIDs, 2)
        BattleCinematicPlayer.shared.warmLoadout(
            heroUltimateID: heroUltimateID,
            companionUltimateID: companionUltimateID
        )
    }

    public func prepareAllBattleCinematics() {
        for abilityID in UltimateCinematicCatalog.referencesByAbilityID.keys {
            BattleCinematicPlayer.shared.warm(abilityID: abilityID)
        }
    }

    func syncLogForDisplay() {
        BattleSimBridge.syncLog(state: &state)
    }

    func isCardPlayable(_ card: BattleCard) -> Bool {
        BattleSimBridge.isCardPlayable(card, in: state)
    }

    /// Ends the player turn (enemy acts, effects tick, draw). Returns earned gold
    /// when an already-claimed stage victory should auto-complete.
    @discardableResult
    func endTurn(
        at date: Date = .now
    ) -> Int? {
        cancelPendingAutoEnd()
        feedback.pruneExpired(at: date, notifyPresentation: false)
        pruneExpiredSkillCallout(at: date)
        pruneSoftHold(at: date)
        guard canEndTurn, state != nil else {
            feedback.noteItemsChanged()
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
        let events = BattleSimBridge.endTurn(state: &state)
        if let battleState = state {
            installBattleState(battleState)
            // Draw SFX only when the round completed and cards were dealt for the next turn.
            if battleState.phase == .playerTurn {
                presentationEnvironment.playSFX([SFXID.abilityDraw])
            }
        }
        presentResolvedEvents(events, at: date)
        let earnedGold = handleOutcomeIfNeeded(at: date)
        if earnedGold == nil {
            scheduleAutoEndIfNeeded()
        }
        return earnedGold
    }
}
