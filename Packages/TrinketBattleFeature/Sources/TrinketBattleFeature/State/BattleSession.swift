import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureContracts
import TrinketFeatureSupport

enum BattleCardPlayResolution: Equatable {
    case rejected
    case committed

    var didCommit: Bool {
        self == .committed
    }
}

@MainActor
struct CancellableGeneration {
    var generation = 0
    var task: Task<Void, Never>?

    var hasPendingTask: Bool {
        task != nil
    }

    mutating func invalidate() {
        generation &+= 1
        task?.cancel()
        task = nil
    }

    mutating func claim() -> Int {
        invalidate()
        return generation
    }

    mutating func finish(generation: Int) {
        if self.generation == generation {
            task = nil
        }
    }

    func isCurrent(_ generation: Int) -> Bool {
        self.generation == generation
    }
}

@MainActor
@Observable
public final class BattleSession: BattleRuntime {
    let feedback = BattleFeedbackLane()
    let cardCues = BattleCardCueState()
    public let spectacle = BattleSpectacleState()
    @ObservationIgnored
    let dependencies: BattleRuntimeDependencies
    public var isAutoBattleEnabled: Bool {
        didSet {
            guard oldValue != isAutoBattleEnabled else { return }
            guard dependencies.rememberAutoBattlePreference() else { return }
            dependencies.setAutoBattleEnabled(isAutoBattleEnabled)
        }
    }

    public var overlayCombatantDetail: CombatantCardDetail?
    public var overlayAbilityDetail: Ability?
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
    public var openingHandDrawStagger: Duration

    var autoBattleRetryDelay: Duration = .milliseconds(50)
    let autoEndTurnDelay: Duration
    let enemyAttackImpactDelayOverride: Duration?
    @ObservationIgnored
    var autoEnd = CancellableGeneration()
    @ObservationIgnored
    var openingHandDeal = CancellableGeneration()
    @ObservationIgnored
    var turnDraw = CancellableGeneration()
    @ObservationIgnored
    var preparedArtworkNames: Set<String> = []

    public internal(set) var isDealingOpeningHand = false

    var hasPendingAutoEnd: Bool {
        autoEnd.hasPendingTask
    }

    @ObservationIgnored
    public internal(set) var isSuspendedForScenePhase = false
    public internal(set) var preparedBattlePresentationRevision = 0

    @ObservationIgnored
    var outcomePresentationDelayOverride: Duration?

    @ObservationIgnored
    var partyCelebrateDelayOverride: Duration?

    @ObservationIgnored
    var ultimateInFrameDurationOverride: Duration?

    public init(
        autoEndTurnDelay: TimeInterval = 0.4,
        openingHandDrawStagger: TimeInterval? = nil,
        enemyAttackImpactDelayOverride: TimeInterval? = nil,
        outcomePresentationDelayOverride: TimeInterval? = nil,
        partyCelebrateDelayOverride: TimeInterval? = nil,
        ultimateInFrameDurationOverride: TimeInterval? = nil,
        presentationEnvironment: BattleRuntimeDependencies = .silent,
    ) {
        self.autoEndTurnDelay = .seconds(autoEndTurnDelay)
        self.openingHandDrawStagger = openingHandDrawStagger.map { .seconds($0) } ?? .seconds(BattleMotion.cardDrawStagger)
        self.enemyAttackImpactDelayOverride = enemyAttackImpactDelayOverride.map { .seconds($0) }
        self.outcomePresentationDelayOverride = outcomePresentationDelayOverride.map { .seconds($0) }
        self.partyCelebrateDelayOverride = partyCelebrateDelayOverride.map { .seconds($0) }
        self.ultimateInFrameDurationOverride = ultimateInFrameDurationOverride.map { .seconds($0) }
        dependencies = presentationEnvironment
        isAutoBattleEnabled = Self.preferredAutoBattleEnabled(
            from: presentationEnvironment,
        )
    }

    static func preferredAutoBattleEnabled(
        from dependencies: BattleRuntimeDependencies,
    ) -> Bool {
        dependencies.rememberAutoBattlePreference()
            && dependencies.autoBattleEnabled()
    }

    var outcome: BattleSimulationOutcome? {
        guard let engineState else { return nil }
        return BattleSimulationOutcome.resolve(
            isPartyDefeated: engineState.isPartyDefeated,
            isEnemyDefeated: engineState.isEnemyDefeated,
        )
    }

    var hand: [BattleCard] {
        presentation.hand
    }

    var canEndTurn: Bool {
        engineState?.phase == .playerTurn && !(engineState?.isBattleOver ?? true)
            && hasActiveSimulation
            && spectacle.outcomePresentation == .battle
    }

    var hasActiveSimulation: Bool {
        engineState != nil
    }

    var canRetreat: Bool {
        activeBattle != nil && !presentation.isBattleOver && spectacle.outcomePresentation == .battle
    }

    var hapticsEnabled: Bool {
        dependencies.hapticsEnabled()
    }

    var effectsVolume: Double {
        dependencies.effectsVolume()
    }

    var areUltimateCinematicAnimationsEnabled: Bool {
        dependencies.ultimateCinematicAnimationsEnabled()
    }

    func playPresentationSFX(_ id: String) {
        dependencies.playSFX([id])
    }

    var hasPlayableCard: Bool {
        hand.contains { isCardPlayable($0) }
    }

    func makeVictorySummary(
        for configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext,
    ) -> BattleVictorySummary? {
        guard let input = victoryInput else { return nil }
        return BattleVictorySummary.make(
            configuration: configuration,
            presentation: presentation,
            earnedGold: input.earnedGold,
            heroName: input.heroName,
            companionName: input.companionName,
        )
    }

    public func presentLaunchVictory() {
        guard let configuration = activeBattle,
              let context = presentationContext,
              let summary = makeVictorySummary(for: configuration, presentation: context)
        else { return }
        spectacle.outcomePresentation = .victory(summary)
    }

    func combatantReadModel(for combatant: Combatant) -> CombatantReadModel? {
        guard let engineState else { return nil }
        let summaries = engineState.effectSummaries(of: combatant)
        return CombatantReadModel(
            combatant: combatant,
            health: engineState.health(of: combatant),
            mana: engineState.mana(of: combatant),
            activeEffectSummaries: summaries,
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

    #endif

    public func installClaimedVictoryHandler(
        ownerID: UUID,
        _ handler: @escaping (BattleRunConfiguration, Int) -> Void,
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
        clearCardCues()
        syncEngineLog()
        isShowingBattleLog = true
    }

    public var logEntries: [LogEntry] {
        engineState?.log ?? []
    }

    func clearBattleLog() {
        isShowingBattleLog = false
    }

    func installActiveBattle(
        _ configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext? = nil,
    ) {
        clearCardCues()
        let holdOpeningHandForOverlayFade = activeBattle == nil
        activeBattle = configuration
        presentationContext = presentation
        lifecyclePhase = .active
        resetRun(
            from: configuration,
            holdOpeningHandForOverlayFade: holdOpeningHandForOverlayFade,
        )
    }

    public func installPresentationContext(_ context: BattlePresentationContext) {
        presentationContext = context
        deliverClaimedVictoryIfNeeded()
    }

    func clearOutcomePresentation() {
        spectacle.outcomeTask.invalidate()
        spectacle.outcomePresentation = .battle
    }

    func trimPresentationMemory() {
        let date = Date.now
        feedback.pruneExpired(at: date)
        CombatFeedbackRasterPool.shared.removeAll()
        CombatFeedbackRasterPool.shared.resetDiagnostics()
        CombatFeedbackGlyphAtlas.shared.removeAll()
        CardDissolveTexture.clearCache()
    }

    func resetFeedbackRasterDiagnostics() {
        CombatFeedbackRasterPool.shared.resetDiagnostics()
    }

    public func prepareBattlePresentation(
        heroActorID: String?,
        heroUltimateID: String?,
        companionActorID: String?,
        companionUltimateID: String?,
    ) {
        dependencies.warmSFX(SFXID.battlePrewarmIDs, 2)
        BattleCinematicPlayer.shared.isEnabled = areUltimateCinematicAnimationsEnabled
        guard areUltimateCinematicAnimationsEnabled else { return }
        BattleCinematicPlayer.shared.warmLoadout(
            heroActorID: heroActorID,
            heroUltimateID: heroUltimateID,
            companionActorID: companionActorID,
            companionUltimateID: companionUltimateID,
        )
    }

    func isCardPlayable(_ card: BattleCard) -> Bool {
        engineState?.isCardPlayable(card) ?? false
    }
}
