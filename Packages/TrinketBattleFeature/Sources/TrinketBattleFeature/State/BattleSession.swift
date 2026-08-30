import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureContracts
import TrinketFeatureSupport

enum BattleCardPlayResolution: Equatable, Sendable {
    case rejected
    case committed

    var didCommit: Bool {
        self == .committed
    }
}

@MainActor
@Observable
public final class BattleSession: BattleRuntime {
    let feedback = BattleFeedbackLane()
    public let spectacle = BattleSpectacleState()
    @ObservationIgnored
    let presentationEnvironment: BattleRuntimeDependencies
    public var isAutoBattleEnabled: Bool {
        didSet {
            guard oldValue != isAutoBattleEnabled else { return }
            guard presentationEnvironment.rememberAutoBattlePreference() else { return }
            presentationEnvironment.setAutoBattleEnabled(isAutoBattleEnabled)
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
    @ObservationIgnored
    var cinematicSessionWatchdogOverride: Duration?

    let autoEndTurnDelay: Duration
    let enemyAttackImpactDelayOverride: Duration?
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

    @ObservationIgnored
    public internal(set) var isSuspendedForScenePhase = false
    public internal(set) var preparedBattlePresentationRevision = 0

    @ObservationIgnored
    var outcomePresentationDelayOverride: Duration?

    @ObservationIgnored
    var partyCelebrateDelayOverride: Duration?

    public static let autoEndTurnDelay: Duration = .milliseconds(400)

    public init(
        autoEndTurnDelay: TimeInterval = 0.4,
        openingHandDrawStagger: TimeInterval? = nil,
        enemyAttackImpactDelayOverride: TimeInterval? = nil,
        outcomePresentationDelayOverride: TimeInterval? = nil,
        partyCelebrateDelayOverride: TimeInterval? = nil,
        cinematicSessionWatchdogOverride: TimeInterval? = nil,
        presentationEnvironment: BattleRuntimeDependencies = .silent,
    ) {
        self.autoEndTurnDelay = .seconds(autoEndTurnDelay)
        self.openingHandDrawStagger = openingHandDrawStagger.map { .seconds($0) } ?? .seconds(BattleMotion.cardDrawStagger)
        self.enemyAttackImpactDelayOverride = enemyAttackImpactDelayOverride.map { .seconds($0) }
        self.outcomePresentationDelayOverride = outcomePresentationDelayOverride.map { .seconds($0) }
        self.partyCelebrateDelayOverride = partyCelebrateDelayOverride.map { .seconds($0) }
        self.cinematicSessionWatchdogOverride = cinematicSessionWatchdogOverride.map { .seconds($0) }
        self.presentationEnvironment = presentationEnvironment
        isAutoBattleEnabled = Self.preferredAutoBattleEnabled(
            from: presentationEnvironment,
        )
    }

    static func preferredAutoBattleEnabled(
        from presentationEnvironment: BattleRuntimeDependencies,
    ) -> Bool {
        presentationEnvironment.rememberAutoBattlePreference()
            && presentationEnvironment.autoBattleEnabled()
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
            && pendingBoonOffer == nil
            && hasActiveSimulation
            && !isDealingOpeningHand
            && spectacle.activeCinematic == nil
            && !spectacle.isShowingVictory && !spectacle.isShowingDefeat
    }

    var hasActiveSimulation: Bool {
        engineState != nil
    }

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
        spectacle.victorySummary = summary
        spectacle.isShowingVictory = true
    }

    func combatantReadModel(for combatant: Combatant) -> CombatantReadModel? {
        guard let engineState else { return nil }
        var summaries = engineState.effectSummaries(of: combatant)
        if combatant.role != .enemy {
            var seen = Set<String>()
            for active in engineState.activeBoons where seen.insert(active.id).inserted {
                for keyword in Set(active.boon.category.keywords) {
                    summaries.append(EffectSummary(keyword: keyword, text: "\(active.boon.name): \(active.boon.description)"))
                }
            }
        }
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

    var previewLabConfig: PreviewLabConfig?
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
        syncLogForDisplay()
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
        resetFeedbackRasterMemory()
    }

    func resetFeedbackRasterMemory() {
        CombatFeedbackRasterPool.shared.removeAll()
        CombatFeedbackRasterPool.shared.resetDiagnostics()
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
        presentationEnvironment.warmSFX(SFXID.battlePrewarmIDs, 2)
        BattleCinematicPlayer.shared.warmLoadout(
            heroActorID: heroActorID,
            heroUltimateID: heroUltimateID,
            companionActorID: companionActorID,
            companionUltimateID: companionUltimateID,
        )
    }

    func syncLogForDisplay() {
        syncEngineLog()
    }

    func isCardPlayable(_ card: BattleCard) -> Bool {
        engineState?.isCardPlayable(card) ?? false
    }
}
