import BattleEngine
import Foundation
import Observation
import TrinketBattleRuntime
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
/// spectacle, and timing. The mutable engine value is owned by `simulation` and is
/// never exposed to app or view callers.
@MainActor
@Observable
public final class BattleSession: BattleRuntime {
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

    public private(set) var activeBattle: BattleRunConfiguration?
    public internal(set) var presentationContext: BattlePresentationContext?
    public internal(set) var lifecyclePhase: BattleLifecyclePhase = .idle

    @ObservationIgnored
    let simulation = BattleSimulationStore()
    let presentation = BattlePresentationState()

    @ObservationIgnored
    var pendingAutoEndTask: Task<Void, Never>?
    /// When true, delayed auto-end (and its enemy telegraph) must not advance combat.
    /// Owned by AppState scene-phase reconciliation; independent of battle lifecycle.
    @ObservationIgnored
    public private(set) var isSuspendedForScenePhase = false
    @ObservationIgnored
    var preparedBattleRunsByKey: [BattleRunKey: PreparedBattleRun] = [:]
    /// Changes whenever a prepared run is replaced so the Play shell can restart
    /// presentation warmup without observing the private prepared-run dictionary.
    public internal(set) var preparedBattlePresentationRevision = 0
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
        simulation.outcome
    }

    var hand: [BattleCard] {
        presentation.hand
    }

    var canEndTurn: Bool {
        simulation.phase == .playerTurn && !simulation.isBattleOver
            && simulation.hasState
            && !isDealingOpeningHand
            && spectacle.activeCinematic == nil
            && !spectacle.isShowingVictory && !spectacle.isShowingDefeat
    }

    /// True when a battle configuration has installed an authoritative simulation.
    public var hasActiveSimulation: Bool {
        simulation.hasState
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

    func makeVictorySummary(
        for configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext
    ) -> BattleVictorySummary? {
        guard let input = simulation.victoryInput else { return nil }
        return BattleVictorySummary.make(
            configuration: configuration,
            presentation: presentation,
            earnedGold: input.earnedGold,
            heroName: input.heroName,
            companionName: input.companionName
        )
    }

    /// Used by launch previews that need victory chrome without running combat.
    public func presentLaunchVictory() {
        guard let configuration = activeBattle,
              let context = presentationContext,
              let summary = makeVictorySummary(for: configuration, presentation: context)
        else { return }
        spectacle.victorySummary = summary
        spectacle.isShowingVictory = true
    }

    func combatantReadModel(for combatant: Combatant) -> BattleSimulationStore.CombatantReadModel? {
        simulation.combatantReadModel(for: combatant)
    }

    #if DEBUG
    func performEngineCardForPerformance(cardID: Int) -> Bool {
        do {
            _ = try simulation.playCard(cardID: cardID)
            installSimulationPresentation()
            return true
        } catch {
            return false
        }
    }
    #endif

    public func endBattle() {
        activeBattle = nil
        clearRunState()
        lifecyclePhase = .idle
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

    /// Log projection for the app shell's sheet. The mutable simulation remains
    /// inside BattleFeature while callers receive immutable log DTOs.
    public var logEntries: [LogEntry] {
        simulation.logEntries
    }

    func clearBattleLog() {
        isShowingBattleLog = false
    }

    /// Installs a configuration through the lifecycle boundary. Callers must use
    /// `activate` or `restart` so the transition is validated before this method.
    func installActiveBattle(_ configuration: BattleRunConfiguration) {
        activeBattle = configuration
        presentationContext = .empty
        lifecyclePhase = .active
        resetRun(from: configuration)
    }

    public func installPresentationContext(_ context: BattlePresentationContext) {
        presentationContext = context
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
        simulation.releaseLogProjection()
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
        simulation.syncLog()
    }

    func isCardPlayable(_ card: BattleCard) -> Bool {
        simulation.isCardPlayable(card)
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
        guard canEndTurn, simulation.hasState else {
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
        let events = simulation.endTurn()
        if simulation.hasState {
            installSimulationPresentation()
            // Draw SFX only when the round completed and cards were dealt for the next turn.
            if simulation.phase == .playerTurn {
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
