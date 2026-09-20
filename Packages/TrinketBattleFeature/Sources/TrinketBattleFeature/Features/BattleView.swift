import BattleEngine
import Observation
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureContracts
import TrinketFeatureSupport

public struct BattleView: View {
    @State private var castPresentation = BattleCastPresentationState()
    @State private var interactionState = BattleInteractionState()
    @State private var isConfirmingRetreat = false
    @State private var victoryFeedbackToken = 0
    @State private var defeatFeedbackToken = 0

    private let configuration: BattleRunConfiguration
    private let presentationContext: BattlePresentationContext
    private let battleSession: BattleSession
    private let presentation: BattlePresentationState
    private let spectacle: BattleSpectacleState
    private let completeVictory: (BattleVictorySummary) -> Bool
    private let restartBattle: () -> Void
    private let retreat: () -> Void
    #if DEBUG
    private let performanceScenario: BattlePerformanceScenario?
    #endif

    public init(
        configuration: BattleRunConfiguration,
        presentationContext: BattlePresentationContext,
        battleSession: BattleSession,
        completeVictory: @escaping (BattleVictorySummary) -> Bool,
        restartBattle: @escaping () -> Void,
        retreat: @escaping () -> Void,
        performanceScenario: BattlePerformanceScenario? = nil,
    ) {
        self.configuration = configuration
        self.presentationContext = presentationContext
        self.battleSession = battleSession
        presentation = battleSession.presentation
        spectacle = battleSession.spectacle
        self.completeVictory = completeVictory
        self.restartBattle = restartBattle
        self.retreat = retreat
        #if DEBUG
        self.performanceScenario = performanceScenario
        #endif
    }

    public var body: some View {
        if presentation.configurationID == configuration.id {
            bodyContent(battleSession: battleSession)
        } else {
            Color.clear
                .trinketScreenBackground()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func bodyContent(battleSession: BattleSession) -> some View {
        outcomeContent(battleSession: battleSession)
            .environment(battleSession)
            .environment(spectacle)
            .trinketScreenBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbarVisibility(.visible, for: .navigationBar)
            .toolbarVisibility(.hidden, for: .tabBar)
            .toolbar {
                if !spectacle.outcomePresentation.isOutcomePresented {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        BattleAutoToggle(battleSession: battleSession)
                        battleActionsMenu(canRetreat: battleSession.canRetreat)
                    }
                }
            }
            .onChange(of: configuration.id) { _, _ in
                castPresentation.reset()
                interactionState.suppressCombatantTaps = false
            }
            .alert(
                "Retreat from this battle?",
                isPresented: $isConfirmingRetreat,
            ) {
                Button("Retreat", role: .destructive) {
                    battleSession.playPresentationSFX(SFXID.uiCancel)
                    retreat()
                }
                .accessibilityIdentifier(AccessibilityID.Battle.retreatConfirm)
                Button("Cancel", role: .cancel) {}
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
                    isConfirmingRetreat = true
                } label: {
                    Label("Retreat", systemImage: "figure.run")
                }
                .accessibilityIdentifier(AccessibilityID.Battle.retreat)
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Battle actions")
        }

        .accessibilityIdentifier(AccessibilityID.Battle.actionsMenu)
    }

    private func outcomeContent(battleSession: BattleSession) -> some View {
        ZStack {
            switch spectacle.outcomePresentation {
            case let .victory(victorySummary):
                VictoryView(
                    summary: victorySummary,
                    primaryActionTitle: hasStageProgression ? "Loot All" : "Battle Again",
                    primaryActionAccessibilityIdentifier: hasStageProgression
                        ? AccessibilityID.Battle.continueButton
                        : AccessibilityID.Battle.battleAgainButton,
                    action: hasStageProgression ? .collect(
                        hapticsEnabled: battleSession.hapticsEnabled,
                        claim: { completeVictoryPrimaryAction(summary: victorySummary) },
                        finish: { battleSession.finishVictoryPresentation(configurationID: configuration.id) },
                    ) : .immediate { completeVictoryPrimaryAction(summary: victorySummary) },
                )
                .transition(.opacity)
            case let .defeat(settlement):
                DefeatView(configuration: configuration, settlement: settlement) { action in
                    if battleSession.progression == nil {
                        switch action {
                        case .retry: restartBattle()
                        case .leave: retreat()
                        }
                        return true
                    }
                    return battleSession.claimDefeat(configurationID: configuration.id, settlement: settlement, action: action)
                }
                .id([
                    settlement.inputs.heroProgression, settlement.heroProgressionAfter,
                    settlement.inputs.companionProgression, settlement.companionProgressionAfter,
                ])
                .transition(.opacity)
            case .battle, .pendingVictory:
                BattleFieldLane(
                    configuration: configuration,
                    presentationContext: presentationContext,
                    battleSession: battleSession,
                    presentation: presentation,
                    interactionState: interactionState,
                    castPresentation: castPresentation,
                    performanceScenario: debugPerformanceScenario,
                )
                .transition(.identity)
            }
        }
        .animation(TrinketMotion.Screen.crossfade, value: spectacle.outcomePresentation)
        .trinketSensoryFeedback(.success, trigger: victoryFeedbackToken, enabled: battleSession.hapticsEnabled)
        .trinketSensoryFeedback(.error, trigger: defeatFeedbackToken, enabled: battleSession.hapticsEnabled)
        .onChange(of: spectacle.outcomePresentation) { _, newValue in
            switch newValue {
            case .victory:
                victoryFeedbackToken &+= 1
            case .defeat:
                defeatFeedbackToken &+= 1
            case .battle, .pendingVictory:
                break
            }
        }
    }

    private func completeVictoryPrimaryAction(summary: BattleVictorySummary) -> Bool {
        guard hasStageProgression else {
            restartBattle()
            return true
        }
        let didPersist = completeVictory(summary)
        if didPersist {
            battleSession.playPresentationSFX(SFXID.uiBuySell)
        }
        return didPersist
    }

    private var debugPerformanceScenario: BattlePerformanceScenario? {
        #if DEBUG
        performanceScenario
        #else
        nil
        #endif
    }
}

struct BattleFieldLane: View {
    let configuration: BattleRunConfiguration
    let presentationContext: BattlePresentationContext
    let battleSession: BattleSession
    let presentation: BattlePresentationState
    let interactionState: BattleInteractionState
    let castPresentation: BattleCastPresentationState
    var performanceScenario: BattlePerformanceScenario?

    var body: some View {
        GeometryReader { geometry in
            let layout = BattleCardGridLayout.metrics(in: geometry.size)
            let anchors = BattleCardGridLayout.feedbackAnchors(
                containerWidth: geometry.size.width,
                layout: layout,
            )
            let hapticsEnabled = battleSession.hapticsEnabled

            ZStack(alignment: .bottom) {
                BattlefieldView(
                    layout: layout,
                    presentation: presentation,
                    hapticsEnabled: hapticsEnabled,
                    onCombatantTap: showDetails(for:),
                    interactionState: interactionState,
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                BattlefieldFeedbackOverlay(
                    layout: layout,
                    anchors: anchors,
                    enemyID: configuration.enemy?.id,
                    heroID: configuration.hero.combatant.id,
                    companionID: configuration.companion.combatant.id,
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                automaticCardLane(in: geometry.size)

                BattleHandProjectionLane(
                    presentation: presentation,
                    hapticsEnabled: hapticsEnabled,
                    battleSize: geometry.size,
                    onPlay: { playCard($0, request: $1) },
                    onInteractionChanged: updateCombatantTapSuppression(_:),
                    onLift: beginCardLift,
                    onLiftCancel: cancelCardLift(for:),
                )
                .frame(height: BattleCardGridLayout.handReservedHeight)
                .offset(y: -BattleHandLayout.bottomRise)
                .zIndex(1)

                cardCastLane(in: geometry.size)
                    .zIndex(3)

                BattleInfrastructureLane(presentation: presentation)
                    .zIndex(2)

                #if DEBUG
                if let scenario = performanceScenario {
                    BattlePerformanceScenarioHarness(
                        scenario: scenario,
                        battleSession: battleSession,
                        battleSize: geometry.size,
                        castPresentation: castPresentation,
                    )
                    .zIndex(20)
                }
                #endif
            }
            .coordinateSpace(.named(BattleCoordinateSpace.field))
            .task(id: autoBattleTaskID) {
                interactionState.suppressCombatantTaps = false
                await battleSession.driveAutoBattle(
                    isCardCastActive: { castPresentation.request != nil },
                    isManualInteractionActive: { interactionState.blocksCombatantTaps },
                    playCard: { card in
                        playAutoBattleCard(card, battleSize: geometry.size)
                    },
                )
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func automaticCardLane(in size: CGSize) -> some View {
        ForEach(presentation.cardPlayback.casts) { cast in
            AutomaticCardCastView(cast: cast, battleSize: size) {
                presentation.cardPlayback.remove(id: cast.id)
            }
        }
    }

    private func cardCastLane(in size: CGSize) -> some View {
        CardCastPresentationLane(
            presentation: castPresentation,
            playback: presentation.cardPlayback,
            battleSize: size,
            hapticsEnabled: battleSession.hapticsEnabled,
        )
    }

    private func beginCardLift(
        _ card: BattleCard,
        _ mode: BattleCardCuePresentationMode,
    ) {
        battleSession.beginCardCue(card, mode: mode)
    }

    private func showDetails(for combatant: Combatant) {
        guard !interactionState.blocksCombatantTaps,
              let effectSummaries = battleSession.effectSummaries(for: combatant)
        else { return }
        let combatantPresentation = switch combatant.role {
        case .hero: presentation.hero
        case .companion: presentation.companion
        case .enemy: presentation.enemy
        }
        guard let combatantPresentation else { return }
        let partyMember = configuration.partyMember(for: combatant.id)
        battleSession.presentCombatantDetail(
            CombatantCardDetail(
                combatant: combatant,
                progression: partyMember?.progression
                    ?? .at(level: configuration.enemyEncounterLevel ?? 1),
                equipmentLoadout: partyMember?.equipmentLoadout ?? EquipmentLoadout(),
                inventoryItems: presentationContext.inventoryItems,
                unlockedTalents: partyMember?.unlockedTalents ?? [],
                health: combatantPresentation.health,
                mana: combatantPresentation.mana,
                maxHealth: combatantPresentation.maxHealth,
                maxMana: combatantPresentation.maxMana,
                activeEffectSummaries: effectSummaries,
                labyrinthModifiers: combatant.role == .enemy
                    ? presentationContext.labyrinthModifiers
                    : [],
            ),
        )
    }

    private func updateCombatantTapSuppression(_ isHandInteracting: Bool) {
        interactionState.suppressCombatantTaps = isHandInteracting
    }
}

private struct BattleHandProjectionLane: View {
    @Environment(BattleSession.self) private var battleSession

    let presentation: BattlePresentationState
    let hapticsEnabled: Bool
    let battleSize: CGSize
    let onPlay: (BattleCard, CardActivationRequest) -> Bool
    let onInteractionChanged: (Bool) -> Void
    let onLift: (BattleCard, BattleCardCuePresentationMode) -> Void
    let onLiftCancel: (BattleCard) -> Void

    @State private var cardPlayFeedbackToken = 0

    var body: some View {
        let hand = presentation.hand
        let playableIDs = presentation.playableCardIDs
        ZStack(alignment: .bottom) {
            BattleHandView(
                cards: hand,
                isDetailPresented: battleSession.overlayAbilityDetail != nil,
                isPlayable: { presentation.isBattleOver || playableIDs.contains($0.id) },
                onInspect: { card in
                    battleSession.presentAbilityDetail(card.ability)
                },
                onPlay: { card, request in
                    let didPlay = onPlay(card, request)
                    if didPlay {
                        cardPlayFeedbackToken &+= 1
                    }
                    return didPlay
                },
                onPlayDenied: { card in
                    battleSession.denyCardCue(card)
                    battleSession.playPresentationSFX(SFXID.uiDeny)
                },
                hapticsEnabled: hapticsEnabled,
                battleFrame: CGRect(origin: .zero, size: battleSize),
                onCardInteractionChanged: onInteractionChanged,
                onLift: onLift,
                onLiftCancel: onLiftCancel,
            )
        }
        .allowsHitTesting(battleSession.canInteractWithHand)
        .trinketSensoryFeedback(
            .impact(weight: .medium),
            trigger: cardPlayFeedbackToken,
            enabled: hapticsEnabled,
        )
    }
}

/// Invisible battle infrastructure: feedback bridge wiring (mount
/// lifetime) plus cast-artwork prewarm (per-configuration lifetime).
/// One ZStack member instead of two; the two effects are independent.
private struct BattleInfrastructureLane: View {
    @Environment(BattleSession.self) private var battleSession
    @State private var ownerID = UUID()

    let presentation: BattlePresentationState
    @State private var artworkName: String?
    @State private var preparedConfigurationID: UUID?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                battleSession.feedback.installBridge(
                    ownerID: ownerID,
                    onChange: { [weak feedback = battleSession.feedback] update in
                        CombatFeedbackChipBridge.publish(update, onEvict: { [weak feedback] ids in
                            feedback?.evictedItemIDs.formUnion(ids)
                        })
                    },
                )
                battleSession.feedback.prepareScheduler()
                CombatFeedbackRasterUIView.prewarmMotionClock()
            }
            .onDisappear {
                battleSession.feedback.uninstallBridge(ownerID: ownerID)
            }
            .task(id: prewarmKey) {
                guard let prewarmKey,
                      preparedConfigurationID != prewarmKey.configurationID
                else { return }

                preparedConfigurationID = prewarmKey.configurationID
                artworkName = prewarmKey.artworkName
            }
            .onChange(of: presentation.configurationID) { _, newID in
                if newID != preparedConfigurationID {
                    preparedConfigurationID = nil
                    artworkName = nil
                }
            }

        if let artworkName {
            CardCastEffectsPrewarmView(artworkName: artworkName) {
                self.artworkName = nil
            }
        }
    }

    private var prewarmKey: BattleCastPrewarmKey? {
        guard let configurationID = presentation.configurationID,
              preparedConfigurationID != configurationID,
              let artworkName = presentation.hand.lazy.compactMap(\.ability.artReference?.imageName).first
        else { return nil }
        return BattleCastPrewarmKey(
            configurationID: configurationID,
            artworkName: artworkName,
        )
    }
}

private struct BattleCastPrewarmKey: Equatable {
    let configurationID: UUID
    let artworkName: String
}

private extension BattleView {
    var hasStageProgression: Bool {
        presentationContext.hasProgressionRewards
    }
}
