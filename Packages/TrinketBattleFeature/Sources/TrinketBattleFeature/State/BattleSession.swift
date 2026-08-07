import BattleEngine
import Foundation
import Observation
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureContracts
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
/// spectacle, and timing. Lifecycle and mutable engine state are owned by
/// `BattleRuntimeSession`; this type only mirrors lifecycle values for SwiftUI and
/// reacts to runtime changes.
@MainActor
@Observable
public final class BattleSession {
    @ObservationIgnored
    public let runtime: BattleRuntimeSession
    let feedback = BattleFeedbackLane()
    public let spectacle = BattleSpectacleState()
    @ObservationIgnored
    let presentationEnvironment: BattleRuntimeDependencies
    /// Session-local Auto control. Persists across battles only when Options
    /// "Remember Auto-Battle Preference" is on.
    public var isAutoBattleEnabled: Bool {
        didSet {
            guard oldValue != isAutoBattleEnabled else { return }
            guard presentationEnvironment.rememberAutoBattlePreference() else { return }
            presentationEnvironment.setAutoBattleEnabled(isAutoBattleEnabled)
        }
    }

    public var overlayCombatantDetail: CombatantCardDetail?
    public var overlayAbilityDetail: Ability?
    /// Presented from Play (not Options) so the log overlays the live battlefield.
    public var isShowingBattleLog = false

    public private(set) var activeBattle: BattleRunConfiguration?
    public internal(set) var presentationContext: BattlePresentationContext?
    public internal(set) var lifecyclePhase: BattleLifecyclePhase = .idle

    let presentation = BattlePresentationState()

    public var onTurnAutoEnded: ((Int?) -> Void)?
    /// Gap between paced opening-hand draws. `<= 0` deals the hand synchronously in `resetRun`
    /// (unit tests). Production uses `TrinketMotion.Battle.cardDrawStagger`.
    public var openingHandDrawStagger: TimeInterval

    /// Auto-battle poll interval while blocked. Unit tests set `.zero`.
    var autoBattleRetryDelay: Duration = .milliseconds(50)

    let autoEndTurnDelay: TimeInterval
    let enemyAttackImpactDelayOverride: TimeInterval?
    @ObservationIgnored
    var pendingAutoEndTask: Task<Void, Never>?
    @ObservationIgnored
    var pendingOpeningHandDealTask: Task<Void, Never>?
    @ObservationIgnored
    var openingHandDealGeneration = 0

    public internal(set) var isDealingOpeningHand = false

    var hasPendingAutoEnd: Bool {
        pendingAutoEndTask != nil
    }

    /// When true, delayed auto-end (and its enemy telegraph) must not advance combat.
    /// Owned by AppState scene-phase reconciliation; independent of battle lifecycle.
    @ObservationIgnored
    public private(set) var isSuspendedForScenePhase = false
    /// Changes whenever a prepared run is replaced so the Play shell can restart
    /// presentation warmup without observing the private prepared-run dictionary.
    public internal(set) var preparedBattlePresentationRevision = 0

    /// Test seam for outcome timing. Production derives the delay from active spectacle.
    @ObservationIgnored
    var outcomePresentationDelayOverride: TimeInterval?

    /// Test seam for the one-frame party celebration beat.
    @ObservationIgnored
    var partyCelebrateDelayOverride: TimeInterval?

    /// Beat after the last playable card so feedback can show before the turn advances.
    public static let autoEndTurnDelay: TimeInterval = 0.4

    public init(
        runtime: BattleRuntimeSession = BattleRuntimeSession(),
        autoEndTurnDelay: TimeInterval = BattleSession.autoEndTurnDelay,
        openingHandDrawStagger: TimeInterval = TrinketMotion.Battle.cardDrawStagger,
        enemyAttackImpactDelayOverride: TimeInterval? = nil,
        outcomePresentationDelayOverride: TimeInterval? = nil,
        presentationEnvironment: BattleRuntimeDependencies = .silent
    ) {
        self.runtime = runtime
        self.autoEndTurnDelay = autoEndTurnDelay
        self.openingHandDrawStagger = openingHandDrawStagger
        self.enemyAttackImpactDelayOverride = enemyAttackImpactDelayOverride
        self.outcomePresentationDelayOverride = outcomePresentationDelayOverride
        self.presentationEnvironment = presentationEnvironment
        isAutoBattleEnabled = Self.preferredAutoBattleEnabled(
            from: presentationEnvironment
        )
        runtime.onChange = { [weak self] change in
            self?.handleRuntimeChange(change)
        }
    }

    static func preferredAutoBattleEnabled(
        from presentationEnvironment: BattleRuntimeDependencies
    ) -> Bool {
        presentationEnvironment.rememberAutoBattlePreference()
            && presentationEnvironment.autoBattleEnabled()
    }

    private func handleRuntimeChange(_ change: BattleRuntimeSession.Change) {
        switch change {
        case .prepared:
            activeBattle = runtime.activeBattle
            lifecyclePhase = runtime.lifecyclePhase
            preparedBattlePresentationRevision = runtime.preparedBattlePresentationRevision
        case .activated:
            guard let configuration = runtime.activeBattle else { return }
            activeBattle = configuration
            lifecyclePhase = runtime.lifecyclePhase
            preparedBattlePresentationRevision = runtime.preparedBattlePresentationRevision
            installActiveBattle(configuration)
        case .ended:
            activeBattle = nil
            lifecyclePhase = runtime.lifecyclePhase
            clearRunState()
        case let .suspensionChanged(suspended):
            isSuspendedForScenePhase = suspended
            if suspended {
                cancelPendingAutoEnd()
            } else {
                scheduleAutoEndIfNeeded()
            }
        case .memoryTrimmed:
            trimPresentationMemory()
        }
    }

    var outcome: BattleSimulationOutcome? {
        runtime.outcome
    }

    var hand: [BattleCard] {
        presentation.hand
    }

    var canEndTurn: Bool {
        runtime.phase == .playerTurn && !runtime.isBattleOver
            && runtime.hasActiveSimulation
            && !isDealingOpeningHand
            && spectacle.activeCinematic == nil
            && !spectacle.isShowingVictory && !spectacle.isShowingDefeat
    }

    /// True when a battle configuration has installed an authoritative simulation.
    public var hasActiveSimulation: Bool {
        runtime.hasActiveSimulation
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
        guard let input = runtime.victoryInput else { return nil }
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

    func combatantReadModel(for combatant: Combatant) -> BattleRuntimeSession.CombatantReadModel? {
        runtime.combatantReadModel(for: combatant)
    }

    #if DEBUG
    func performEngineCardForPerformance(cardID: Int) -> Bool {
        do {
            _ = try runtime.playCard(cardID: cardID)
            installSimulationPresentation()
            return true
        } catch {
            return false
        }
    }
    #endif

    /// Schedules a delayed end turn when nothing in hand is playable.
    func considerAutoEndTurn() {
        scheduleAutoEndIfNeeded()
    }

    public func presentBattleLog() {
        syncLogForDisplay()
        isShowingBattleLog = true
    }

    /// Log projection for the app shell's sheet. The mutable simulation remains
    /// inside BattleFeature while callers receive immutable log DTOs.
    public var logEntries: [LogEntry] {
        runtime.logEntries
    }

    func clearBattleLog() {
        isShowingBattleLog = false
    }

    /// Installs presentation for a configuration already accepted by the runtime.
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

    func trimPresentationMemory() {
        let date = Date.now
        feedback.pruneExpired(at: date)
        pruneExpiredSkillCallout(at: date)
        pruneSoftHold(at: date)
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
        runtime.syncLog()
    }

    func isCardPlayable(_ card: BattleCard) -> Bool {
        runtime.isCardPlayable(card)
    }
}
