import BattleEngine
import Observation
import SwiftUI
import TrinketBattleContracts
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureContracts
import TrinketFeatureSupport

public struct BattleView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale
    @State private var persistFailureMessage: StageMapMessage?
    @State private var castPresentation = BattleCastPresentationState()
    /// Offscreen first-hand cast prime so production play does not cold-mount
    /// card face + mask + particles together.
    @State private var handCastPrewarmArtwork: String?
    /// Blocks combatant detail Buttons while a hand card is held, and briefly after
    /// release so the same finger-up cannot open details.
    @State private var interactionState = BattleInteractionState()
    @State private var feedbackBridgeOwnerID = UUID()
    @Namespace private var cinematicNamespace

    private let configuration: BattleRunConfiguration
    private let presentationContext: BattlePresentationContext
    private let battleSession: BattleSession
    private let completeBattle: (BattleRunConfiguration, Int, [ResourceAmount]?) -> Bool
    private let restartBattle: () -> Void
    private let retreat: () -> Void
    #if DEBUG
    private let performanceScenario: BattlePerformanceScenario?
    #endif

    public init(
        configuration: BattleRunConfiguration,
        presentationContext: BattlePresentationContext,
        battleSession: BattleSession,
        completeBattle: @escaping (BattleRunConfiguration, Int, [ResourceAmount]?) -> Bool,
        restartBattle: @escaping () -> Void,
        retreat: @escaping () -> Void,
        performanceScenario: BattlePerformanceScenario? = nil
    ) {
        self.configuration = configuration
        self.presentationContext = presentationContext
        self.battleSession = battleSession
        self.completeBattle = completeBattle
        self.restartBattle = restartBattle
        self.retreat = retreat
        #if DEBUG
        self.performanceScenario = performanceScenario
        #endif
    }

    public var body: some View {
        @Bindable var observedSession = battleSession
        let presentation = observedSession.presentation
        if presentation.configurationID == configuration.id {
            bodyContent(battleSession: observedSession)
        }
    }

    private func bodyContent(battleSession: BattleSession) -> some View {
        outcomeContent(battleSession: battleSession)
            .environment(battleSession)
            .trinketScreenBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbarVisibility(.visible, for: .navigationBar)
            .toolbar {
                if !battleSession.spectacle.isShowingVictory, !battleSession.spectacle.isShowingDefeat {
                    ToolbarItem(placement: .topBarTrailing) {
                        battleActionsMenu(canRetreat: battleSession.canRetreat)
                    }
                }
            }
            .alert(item: $persistFailureMessage) { message in
                Alert(
                    title: Text(message.title),
                    message: Text(message.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                let launchVictoryWasPresented = battleSession.spectacle.isShowingVictory
                battleSession.installPresentationContext(presentationContext)
                if launchVictoryWasPresented {
                    battleSession.presentLaunchVictory()
                }
                prewarmBattlePresentationEffects()
                installChipBridge()
            }
            .onChange(of: configuration.id) { _, _ in
                battleSession.installPresentationContext(presentationContext)
                battleSession.clearOutcomePresentation()
                castPresentation.reset()
                CombatFeedbackRasterPool.shared.removeAll()
                CombatFeedbackRasterPool.shared.resetDiagnostics()
                prewarmBattlePresentationEffects()
                installChipBridge()
            }
            .onDisappear {
                battleSession.feedback.uninstallBridge(ownerID: feedbackBridgeOwnerID)
                CombatFeedbackRasterPool.shared.removeAll()
                CombatFeedbackRasterPool.shared.resetDiagnostics()
            }
    }

    private func battleActionsMenu(canRetreat: Bool) -> some View {
        Menu {
            Button {
                battleSession.presentBattleLog()
            } label: {
                Label("Combat Log", systemImage: "list.bullet.rectangle")
            }
            .accessibilityIdentifier(AccessibilityID.Battle.combatLog)

            #if DEBUG
            Button {
                battleSession.debugSkipCombat()
            } label: {
                Label("Skip Combat", systemImage: "forward.end")
            }
            .accessibilityIdentifier(AccessibilityID.Battle.skipCombat)
            #endif

            if canRetreat {
                Button(role: .destructive) {
                    battleSession.playPresentationSFX(SFXID.uiCancel)
                    retreat()
                } label: {
                    Label("Retreat", systemImage: "figure.run")
                }
                .accessibilityIdentifier(AccessibilityID.Battle.retreat)
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(minWidth: 44, minHeight: 44)
        }

        .accessibilityIdentifier(AccessibilityID.Battle.actionsMenu)
    }

    private func outcomeContent(battleSession: BattleSession) -> some View {
        ZStack {
            if battleSession.spectacle.isShowingVictory,
               let victorySummary = battleSession.spectacle.victorySummary {
                VictoryView(
                    enemyName: configuration.enemy?.name ?? "Enemy",
                    summary: victorySummary,
                    primaryActionTitle: hasStageProgression ? "Loot All" : "Battle Again",
                    onPrimaryAction: { completeVictoryPrimaryAction(summary: victorySummary) }
                )
                .transition(.opacity)
            } else if battleSession.spectacle.isShowingDefeat {
                switch presentationContext.defeatPrimaryAction {
                case .retreat:
                    DefeatView(
                        enemyName: configuration.enemy?.name ?? "Enemy",
                        primaryButtonTitle: "Return to Map",
                        onPrimaryAction: {
                            retreat()
                            return true
                        }
                    )
                    .transition(.opacity)
                case .restart:
                    DefeatView(
                        enemyName: configuration.enemy?.name ?? "Enemy",
                        onPrimaryAction: {
                            restartBattle()
                            return true
                        }
                    )
                    .transition(.opacity)
                }
            } else {
                battlefield(battleSession: battleSession)
                    .transition(.opacity)
            }
        }
        .animation(TrinketMotion.Screen.crossfade, value: outcomePhase(for: battleSession))
    }

    private func completeVictoryPrimaryAction(summary: BattleVictorySummary) -> Bool {
        guard hasStageProgression else {
            restartBattle()
            return true
        }
        let didPersist = completeBattle(
            configuration,
            summary.rawBattleEarnedGold,
            summary.materialRewards
        )
        if didPersist {
            battleSession.playPresentationSFX(SFXID.uiBuySell)
        } else {
            persistFailureMessage = StageMapMessage(
                title: "Couldn't Save Progress",
                message: "Your victory was not saved. Stay on this screen and try Continue again."
            )
        }
        return didPersist
    }

    private func battlefield(battleSession: BattleSession) -> some View {
        GeometryReader { geometry in
            let layout = BattleCardGridLayout.metrics(in: geometry.size)

            ZStack(alignment: .bottom) {
                BattlefieldView(
                    layout: layout,
                    enemyPane: projectedCombatantPane(.enemy),
                    heroPane: projectedCombatantPane(.hero),
                    companionPane: projectedCombatantPane(.companion),
                    interactionState: interactionState
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                feedbackOverlay(layout: layout, battleSession: battleSession)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                BattleHandProjectionLane(
                    presentation: battleSession.presentation,
                    hapticsEnabled: battleSession.hapticsEnabled,
                    battleSize: geometry.size,
                    onPlay: playCard(_:request:),
                    onInteractionChanged: updateCombatantTapSuppression(_:),
                    onAttackWindUp: beginPartyAttackWindUp(for:),
                    onAttackCancel: cancelPartyAttack(for:),
                    onReady: { prepareAutoEndTurn(battleSession) }
                )
                .frame(height: BattleCardGridLayout.handReservedHeight)
                .offset(y: -BattleHandLayout.bottomRise)
                .zIndex(1)

                CardCastPresentationLane(presentation: castPresentation)
                    .zIndex(3)

                if let handCastPrewarmArtwork {
                    CardCastEffectsPrewarmView(artworkName: handCastPrewarmArtwork) {
                        self.handCastPrewarmArtwork = nil
                    }
                    .zIndex(2)
                }

                BattleCinematicLane(
                    namespace: cinematicNamespace,
                    effectsVolume: battleSession.effectsVolume
                )
                .zIndex(10)

                #if DEBUG
                if let scenario = performanceScenario {
                    BattlePerformanceScenarioHarness(
                        scenario: scenario,
                        battleSession: battleSession,
                        battleSize: geometry.size,
                        castPresentation: castPresentation
                    )
                    .zIndex(20)
                }
                #endif
            }
            .coordinateSpace(.named(BattleCoordinateSpace.field))
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func feedbackOverlay(
        layout: BattleCardGridLayout.Metrics,
        battleSession: BattleSession
    ) -> BattlefieldFeedbackOverlay {
        BattlefieldFeedbackOverlay(
            layout: layout,
            enemyID: battleSession.presentation.enemy?.combatant.id,
            heroID: battleSession.presentation.hero?.combatant.id,
            companionID: battleSession.presentation.companion?.combatant.id
        )
    }

    private func playCard(_ card: BattleCard, request: CardActivationRequest) -> Bool {
        let outcome = battleSession.playCard(
            cardID: card.id
        )
        guard case let .committed(earnedGold) = outcome else { return false }
        if let earnedGold {
            completeClaimedStageVictoryIfNeeded(earnedGold: earnedGold)
        }
        if let combatantID = battleSession.combatantID(for: card.owner) {
            battleSession.commitAttackSwing(for: combatantID)
        }
        castPresentation.append(request)
        return true
    }

    private func beginPartyAttackWindUp(for card: BattleCard) {
        guard let combatantID = battleSession.combatantID(for: card.owner) else { return }
        battleSession.beginAttackWindUp(for: combatantID)
    }

    private func cancelPartyAttack(for card: BattleCard) {
        guard let combatantID = battleSession.combatantID(for: card.owner) else { return }
        battleSession.cancelAttack(for: combatantID)
    }

    private func wireAutoEndTurn(_ battleSession: BattleSession) {
        battleSession.onTurnAutoEnded = { [weak battleSession] earnedGold in
            guard let battleSession,
                  let earnedGold,
                  let configuration = battleSession.activeBattle else { return }
            let didPersist = completeBattle(
                configuration,
                earnedGold,
                nil
            )
            if !didPersist {
                // Fall back to victory chrome so Loot All can retry; retreat stays locked
                // once outcome is resolved, so silent failure would hard-stick the fight.
                battleSession.presentVictoryChromeForPersistRetry()
                persistFailureMessage = StageMapMessage(
                    title: "Couldn't Save Progress",
                    message: "Your victory was not saved. Stay on this screen and try Continue again."
                )
            }
        }
    }

    private func prepareAutoEndTurn(_ battleSession: BattleSession) {
        wireAutoEndTurn(battleSession)
        battleSession.considerAutoEndTurn()
    }

    private func completeClaimedStageVictoryIfNeeded(earnedGold: Int) {
        guard let configuration = battleSession.activeBattle else { return }
        let didPersist = completeBattle(
            configuration,
            earnedGold,
            nil
        )
        if !didPersist {
            battleSession.presentVictoryChromeForPersistRetry()
            persistFailureMessage = StageMapMessage(
                title: "Couldn't Save Progress",
                message: "Your victory was not saved. Stay on this screen and try Continue again."
            )
        }
    }

    private func projectedCombatantPane(
        _ role: BattleCombatantProjectionPane.Role
    ) -> BattleCombatantProjectionPane {
        BattleCombatantProjectionPane(
            presentation: battleSession.presentation,
            role: role,
            hapticsEnabled: battleSession.hapticsEnabled,
            cinematicNamespace: cinematicNamespace,
            onCombatantTap: showDetails(for:)
        )
    }

    private func showDetails(for combatant: Combatant) {
        guard !interactionState.suppressCombatantTaps,
              let combatantReadModel = battleSession.combatantReadModel(for: combatant)
        else { return }
        let partyMember = configuration.partyMember(for: combatant.id)
        battleSession.presentCombatantDetail(
            CombatantCardDetail(
                combatant: combatant,
                progression: partyMember?.progression ?? .initial,
                equipmentLoadout: partyMember?.equipmentLoadout ?? EquipmentLoadout(),
                inventoryItems: presentationContext.inventoryItems,
                health: combatantReadModel.health,
                activeEffectSummaries: combatantReadModel.activeEffectSummaries
            )
        )
    }

    private func updateCombatantTapSuppression(_ isHandInteracting: Bool) {
        interactionState.suppressCombatantTaps = isHandInteracting
    }
}

/// Hand observation is isolated from combatant projections. Drawing or spending a
/// card updates this lane without rebuilding the static battlefield hierarchy.
private struct BattleHandProjectionLane: View {
    @Environment(BattleSession.self) private var battleSession

    let presentation: BattlePresentationState
    let hapticsEnabled: Bool
    let battleSize: CGSize
    let onPlay: (BattleCard, CardActivationRequest) -> Bool
    let onInteractionChanged: (Bool) -> Void
    let onAttackWindUp: (BattleCard) -> Void
    let onAttackCancel: (BattleCard) -> Void
    let onReady: () -> Void

    @State private var cardPlayFeedbackToken = 0

    var body: some View {
        let hand = presentation.hand
        let playableIDs = presentation.playableCardIDs
        BattleHandView(
            cards: hand,
            isPlayable: { playableIDs.contains($0.id) },
            onTap: { card in
                battleSession.presentAbilityDetail(card.ability)
            },
            onPlay: { card, request in
                let didPlay = onPlay(card, request)
                if didPlay {
                    cardPlayFeedbackToken &+= 1
                }
                return didPlay
            },
            hapticsEnabled: hapticsEnabled,
            battleFrame: CGRect(origin: .zero, size: battleSize),
            configuration: .init(),
            onCardInteractionChanged: onInteractionChanged,
            onAttackWindUp: onAttackWindUp,
            onAttackCancel: onAttackCancel
        )
        .trinketSensoryFeedback(
            .impact(weight: .medium),
            trigger: cardPlayFeedbackToken,
            enabled: hapticsEnabled
        )
        .onAppear(perform: onReady)
    }
}

/// Keeps cinematic observation out of `BattleView.body`. Phase changes can now
/// insert/update the full-screen overlay without rebuilding the battlefield, hand,
/// toolbar, and always-mounted feedback hosts behind it.
private struct BattleCinematicLane: View {
    @Environment(BattleSession.self) private var battleSession
    let namespace: Namespace.ID
    let effectsVolume: Double

    var body: some View {
        if let cinematic = battleSession.spectacle.activeCinematic {
            UltimateCinematicOverlay(
                cinematic: cinematic,
                effectsVolume: effectsVolume,
                namespace: namespace,
                onPlaying: { battleSession.markCinematicPlaying() },
                onAutoFinish: { cinematicID in
                    battleSession.beginCinematicCollapse(expectedID: cinematicID)
                },
                onCollapseFinished: { cinematicID in
                    battleSession.completeCinematicCollapse(expectedID: cinematicID)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        }
    }
}

private extension BattleView {
    func outcomePhase(for battleSession: BattleSession) -> String {
        if battleSession.spectacle.isShowingVictory {
            "victory"
        } else if battleSession.spectacle.isShowingDefeat {
            "defeat"
        } else {
            "battle"
        }
    }

    var hasStageProgression: Bool {
        presentationContext.hasProgressionRewards
    }

    func installChipBridge() {
        battleSession.feedback.installBridge(
            ownerID: feedbackBridgeOwnerID,
            onChange: CombatFeedbackChipBridge.publish
        )
    }

    func prewarmBattlePresentationEffects() {
        BattlePresentationWarmup.prepare(
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
        // Start prune / multimodal loops, paced raster prepare, and the chip motion
        // clock before the first chip publish so that frame only bumps dates /
        // enqueues work / inserts layers.
        battleSession.feedback.prepareScheduler()
        CombatFeedbackRasterPool.shared.prewarmPacedPrepareLoop()
        CombatFeedbackRasterUIView.prewarmMotionClock()
        let handArtNames = battleSession.hand.compactMap { $0.ability.artReference?.imageName }
        guard !handArtNames.isEmpty else { return }
        Task { @MainActor in
            await PreparedArtworkCache.shared.prepareAndPin(names: handArtNames)
        }
        // Prime the full cast stack with the lead hand card (invisible).
        handCastPrewarmArtwork = handArtNames[0]
    }
}
