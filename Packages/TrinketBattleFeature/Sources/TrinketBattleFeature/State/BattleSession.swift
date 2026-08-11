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
    case committed

    var didCommit: Bool {
        guard case .committed = self else { return false }
        return true
    }
}

/// Production battle runtime and presentation controller for one battle session.
/// App orchestration sees only `BattleRuntime`; BattleFeature owns the engine state,
/// projection, feedback, spectacle, overlays, and timing on this concrete object.
@MainActor
@Observable
public final class BattleSession: BattleRuntime {
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

    public internal(set) var activeBattle: BattleRunConfiguration?
    public internal(set) var presentationContext: BattlePresentationContext?
    public internal(set) var lifecyclePhase: BattleLifecyclePhase = .idle

    @ObservationIgnored
    var engineState: BattleState?
    @ObservationIgnored
    var preparedBattleRunsByKey: [BattleRunKey: PreparedBattleRun] = [:]

    let presentation = BattlePresentationState()

    @ObservationIgnored
    private var claimedVictoryHandlerOwnerID: UUID?
    @ObservationIgnored
    private var claimedVictoryHandler: ((BattleRunConfiguration, Int) -> Void)?
    @ObservationIgnored
    var deliveredClaimedVictoryConfigurationID: UUID?
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
    @ObservationIgnored
    var preparedArtworkNames: Set<String> = []

    public internal(set) var isDealingOpeningHand = false

    var hasPendingAutoEnd: Bool {
        pendingAutoEndTask != nil
    }

    /// When true, delayed auto-end (and its enemy telegraph) must not advance combat.
    /// Owned by AppState scene-phase reconciliation; independent of battle lifecycle.
    @ObservationIgnored
    public internal(set) var isSuspendedForScenePhase = false
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
        autoEndTurnDelay: TimeInterval = BattleSession.autoEndTurnDelay,
        openingHandDrawStagger: TimeInterval = TrinketMotion.Battle.cardDrawStagger,
        enemyAttackImpactDelayOverride: TimeInterval? = nil,
        outcomePresentationDelayOverride: TimeInterval? = nil,
        presentationEnvironment: BattleRuntimeDependencies = .silent
    ) {
        self.autoEndTurnDelay = autoEndTurnDelay
        self.openingHandDrawStagger = openingHandDrawStagger
        self.enemyAttackImpactDelayOverride = enemyAttackImpactDelayOverride
        self.outcomePresentationDelayOverride = outcomePresentationDelayOverride
        self.presentationEnvironment = presentationEnvironment
        isAutoBattleEnabled = Self.preferredAutoBattleEnabled(
            from: presentationEnvironment
        )
    }

    static func preferredAutoBattleEnabled(
        from presentationEnvironment: BattleRuntimeDependencies
    ) -> Bool {
        presentationEnvironment.rememberAutoBattlePreference()
            && presentationEnvironment.autoBattleEnabled()
    }

    var outcome: BattleSimulationOutcome? {
        guard let engineState else { return nil }
        return BattleSimulationOutcome.resolve(
            isPartyDefeated: engineState.isPartyDefeated,
            isEnemyDefeated: engineState.isEnemyDefeated
        )
    }

    var hand: [BattleCard] {
        presentation.hand
    }

    var canEndTurn: Bool {
        engineState?.phase == .playerTurn && !(engineState?.isBattleOver ?? true)
            && hasActiveSimulation
            && !isDealingOpeningHand
            && spectacle.activeCinematic == nil
            && !spectacle.isShowingVictory && !spectacle.isShowingDefeat
    }

    /// True when a battle configuration has installed an authoritative simulation.
    public var hasActiveSimulation: Bool {
        engineState != nil
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
        guard let input = victoryInput else { return nil }
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

    func combatantReadModel(for combatant: Combatant) -> CombatantReadModel? {
        guard let engineState else { return nil }
        return CombatantReadModel(
            combatant: combatant,
            health: engineState.health(of: combatant),
            maxHealth: engineState.maxHealth(of: combatant),
            mana: engineState.mana(of: combatant),
            activeEffectSummaries: engineState.effectSummaries(of: combatant)
        )
    }

    #if DEBUG
    func performEngineCardForPerformance(cardID: Int) -> Bool {
        do {
            _ = try playEngineCard(cardID: cardID)
            installSimulationPresentation()
            return true
        } catch {
            return false
        }
    }

    /// DEBUG-only config the Preview Lab uses to preview Ultimate transition
    /// styles. Production battles leave this `nil` and use the diagonal split defaults.
    var previewLabConfig: PreviewLabConfig?
    #endif

    /// Connects app-owned battle persistence without making the render tree own
    /// simulation completion. Owner identity prevents a stale overlay teardown
    /// from clearing a newer installation.
    public func installClaimedVictoryHandler(
        ownerID: UUID,
        _ handler: @escaping (BattleRunConfiguration, Int) -> Void
    ) {
        claimedVictoryHandlerOwnerID = ownerID
        claimedVictoryHandler = handler
        deliverClaimedVictoryIfNeeded()
    }

    public func uninstallClaimedVictoryHandler(ownerID: UUID) {
        guard claimedVictoryHandlerOwnerID == ownerID else { return }
        claimedVictoryHandlerOwnerID = nil
        claimedVictoryHandler = nil
    }

    func deliverClaimedVictoryIfNeeded() {
        guard let configuration = activeBattle,
              presentationContext?.stageRewardsAlreadyClaimed == true,
              outcome == .victory,
              deliveredClaimedVictoryConfigurationID != configuration.id,
              let claimedVictoryHandler
        else { return }

        deliveredClaimedVictoryConfigurationID = configuration.id
        claimedVictoryHandler(configuration, earnedGold ?? 0)
    }

    public func presentBattleLog() {
        syncLogForDisplay()
        isShowingBattleLog = true
    }

    /// Log projection for the app shell's sheet. The mutable simulation remains
    /// inside BattleFeature while callers receive immutable log DTOs.
    public var logEntries: [LogEntry] {
        engineState?.log ?? []
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
        deliverClaimedVictoryIfNeeded()
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
        resetFeedbackRasterMemory()
    }

    func resetFeedbackRasterMemory() {
        CombatFeedbackRasterPool.shared.removeAll()
        CombatFeedbackRasterPool.shared.resetDiagnostics()
    }

    func resetFeedbackRasterDiagnostics() {
        CombatFeedbackRasterPool.shared.resetDiagnostics()
    }

    /// Eagerly prepares battle audio before activation. Repeated calls are cheap
    /// because both caches skip already-prepared resources.
    public func prepareBattlePresentation(
        heroActorID: String?,
        heroUltimateID: String?,
        companionActorID: String?,
        companionUltimateID: String?
    ) {
        presentationEnvironment.warmSFX(SFXID.battlePrewarmIDs, 2)
        BattleCinematicPlayer.shared.warmLoadout(
            heroActorID: heroActorID,
            heroUltimateID: heroUltimateID,
            companionActorID: companionActorID,
            companionUltimateID: companionUltimateID
        )
    }

    public func prepareAllBattleCinematics() {
        for reference in UltimateCinematicCatalog.allReferences {
            BattleCinematicPlayer.shared.warm(
                actorID: reference.actorID,
                abilityID: reference.abilityID
            )
        }
    }

    func syncLogForDisplay() {
        syncEngineLog()
    }

    func isCardPlayable(_ card: BattleCard) -> Bool {
        engineState?.isCardPlayable(card) ?? false
    }
}
