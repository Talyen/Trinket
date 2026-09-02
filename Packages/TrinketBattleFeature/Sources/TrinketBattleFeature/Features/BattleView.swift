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
        self.completeVictory = completeVictory
        self.restartBattle = restartBattle
        self.retreat = retreat
        #if DEBUG
        self.performanceScenario = performanceScenario
        #endif
    }

    public var body: some View {
        if battleSession.presentation.configurationID == configuration.id {
            bodyContent(battleSession: battleSession)
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
            .toolbarVisibility(.hidden, for: .tabBar)
            .toolbar {
                if !battleSession.spectacle.outcomePresentation.isOutcomePresented {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        BattleAutoToggle(battleSession: battleSession)
                        battleActionsMenu(canRetreat: battleSession.canRetreat)
                    }
                }
            }
            .onChange(of: configuration.id) { _, _ in
                castPresentation.reset()
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
            switch battleSession.spectacle.outcomePresentation {
            case let .victory(victorySummary):
                VictoryView(
                    summary: victorySummary,
                    primaryActionTitle: hasStageProgression ? "Loot All" : "Battle Again",
                    primaryActionAccessibilityIdentifier: hasStageProgression
                        ? AccessibilityID.Battle.continueButton
                        : AccessibilityID.Battle.battleAgainButton,
                    onPrimaryAction: { completeVictoryPrimaryAction(summary: victorySummary) },
                )
                .transition(.opacity)
            case .defeat:
                switch presentationContext.defeatPrimaryAction {
                case .retreat:
                    DefeatView(
                        enemyName: configuration.enemy?.name ?? "Enemy",
                        primaryButtonTitle: "Return to Map",
                        onPrimaryAction: {
                            retreat()
                            return true
                        },
                    )
                    .transition(.opacity)
                case .restart:
                    DefeatView(
                        enemyName: configuration.enemy?.name ?? "Enemy",
                        onPrimaryAction: {
                            restartBattle()
                            return true
                        },
                    )
                    .transition(.opacity)
                }
            case .battle, .pendingVictory:
                BattleFieldLane(
                    configuration: configuration,
                    presentationContext: presentationContext,
                    battleSession: battleSession,
                    interactionState: interactionState,
                    castPresentation: castPresentation,
                    performanceScenario: debugPerformanceScenario,
                )
                .transition(.opacity)
            }
        }
        .animation(TrinketMotion.Screen.crossfade, value: battleSession.spectacle.outcomePresentation)
        .modifier(BattleOutcomeHapticsModifier(
            battleSession: battleSession,
            victoryTrigger: $victoryFeedbackToken,
            defeatTrigger: $defeatFeedbackToken,
        ))
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
            let presentation = battleSession.presentation
            let hapticsEnabled = battleSession.hapticsEnabled

            ZStack(alignment: .bottom) {
                BattlefieldView(
                    layout: layout,
                    enemyPane: BattleCombatantProjectionPane(
                        presentation: presentation,
                        role: .enemy,
                        hapticsEnabled: hapticsEnabled,
                        onCombatantTap: showDetails(for:),
                    ),
                    heroPane: BattleCombatantProjectionPane(
                        presentation: presentation,
                        role: .hero,
                        hapticsEnabled: hapticsEnabled,
                        onCombatantTap: showDetails(for:),
                    ),
                    companionPane: BattleCombatantProjectionPane(
                        presentation: presentation,
                        role: .companion,
                        hapticsEnabled: hapticsEnabled,
                        onCombatantTap: showDetails(for:),
                    ),
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

                BattleHandProjectionLane(
                    presentation: presentation,
                    hapticsEnabled: hapticsEnabled,
                    battleSize: geometry.size,
                    interactionState: interactionState,
                    onPlay: playCard(_:request:),
                    onInteractionChanged: updateCombatantTapSuppression(_:),
                    onAttackWindUp: beginPartyAttackWindUp(for:),
                    onAttackCancel: cancelPartyAttack(for:),
                )
                .frame(height: BattleCardGridLayout.handReservedHeight)
                .offset(y: -BattleHandLayout.bottomRise)
                .zIndex(1)

                CardCastPresentationLane(presentation: castPresentation)
                    .zIndex(3)

                BattleCastPrewarmLane(presentation: presentation)
                    .zIndex(2)

                BattleFeedbackBridgeLane()

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
                        await playCardWithTapLift(card, battleSize: geometry.size)
                    },
                )
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func beginPartyAttackWindUp(for card: BattleCard) {
        guard let combatantID = battleSession.combatantID(for: card.owner) else { return }
        battleSession.publishAttackTelegraph(.windUp, for: combatantID)
    }

    private func showDetails(for combatant: Combatant) {
        guard !interactionState.blocksCombatantTaps,
              let combatantReadModel = battleSession.combatantReadModel(for: combatant)
        else { return }
        let partyMember = configuration.partyMember(for: combatant.id)
        battleSession.presentCombatantDetail(
            CombatantCardDetail(
                combatant: combatant,
                progression: partyMember?.progression ?? .initial,
                equipmentLoadout: partyMember?.equipmentLoadout ?? EquipmentLoadout(),
                inventoryItems: presentationContext.inventoryItems,
                unlockedTalents: partyMember?.unlockedTalents ?? [],
                health: combatantReadModel.health,
                mana: combatantReadModel.mana,
                activeEffectSummaries: combatantReadModel.activeEffectSummaries,
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
    let interactionState: BattleInteractionState
    let onPlay: (BattleCard, CardActivationRequest) -> Bool
    let onInteractionChanged: (Bool) -> Void
    let onAttackWindUp: (BattleCard) -> Void
    let onAttackCancel: (BattleCard) -> Void

    @State private var cardPlayFeedbackToken = 0

    var body: some View {
        let hand = presentation.hand
        let playableIDs = presentation.playableCardIDs
        BattleHandView(
            cards: hand,
            isPlayable: { playableIDs.contains($0.id) },
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
            onPlayDenied: {
                battleSession.playPresentationSFX(SFXID.uiDeny)
            },
            hapticsEnabled: hapticsEnabled,
            battleFrame: CGRect(origin: .zero, size: battleSize),
            autoLiftCardID: interactionState.autoLiftCardID,
            onCardInteractionChanged: onInteractionChanged,
            onAttackWindUp: onAttackWindUp,
            onAttackCancel: onAttackCancel,
        )
        .trinketSensoryFeedback(
            .impact(weight: .medium),
            trigger: cardPlayFeedbackToken,
            enabled: hapticsEnabled,
        )
    }
}

private struct BattleFeedbackBridgeLane: View {
    @Environment(BattleSession.self) private var battleSession
    @State private var ownerID = UUID()

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                battleSession.feedback.installBridge(
                    ownerID: ownerID,
                    onChange: CombatFeedbackChipBridge.publish,
                )
                battleSession.feedback.prepareScheduler()
                CombatFeedbackRasterUIView.prewarmMotionClock()
            }
            .onDisappear {
                battleSession.feedback.uninstallBridge(ownerID: ownerID)
            }
    }
}

private struct BattleCastPrewarmKey: Equatable {
    let configurationID: UUID?
    let artworkNames: [String]
}

private struct BattleCastPrewarmLane: View {
    let presentation: BattlePresentationState
    @State private var artworkName: String?
    @State private var preparedConfigurationID: UUID?
    @State private var preparedArtworkNames: [String] = []

    var body: some View {
        if let artworkName {
            CardCastEffectsPrewarmView(artworkName: artworkName) {
                self.artworkName = nil
            }
        }
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .task(id: prewarmKey) {
                guard let configurationID = prewarmKey.configurationID,
                      preparedConfigurationID != configurationID,
                      !prewarmKey.artworkNames.isEmpty
                else { return }

                let names = prewarmKey.artworkNames
                await PreparedArtworkCache.shared.prepareAndPin(names: names)
                guard !Task.isCancelled,
                      presentation.configurationID == configurationID
                else {
                    PreparedArtworkCache.shared.releasePins(names: names)
                    return
                }
                if !preparedArtworkNames.isEmpty {
                    PreparedArtworkCache.shared.releasePins(names: preparedArtworkNames)
                }
                preparedConfigurationID = configurationID
                preparedArtworkNames = names
                artworkName = names.first
            }
            .onDisappear {
                if !preparedArtworkNames.isEmpty {
                    PreparedArtworkCache.shared.releasePins(names: preparedArtworkNames)
                    preparedArtworkNames = []
                    preparedConfigurationID = nil
                }
            }
    }

    private var prewarmKey: BattleCastPrewarmKey {
        BattleCastPrewarmKey(
            configurationID: presentation.configurationID,
            artworkNames: presentation.hand.compactMap(\.ability.artReference?.imageName).sorted(),
        )
    }
}

private extension BattleView {
    var hasStageProgression: Bool {
        presentationContext.hasProgressionRewards
    }
}

private struct BattleOutcomeHapticsModifier: ViewModifier {
    let battleSession: BattleSession
    @Binding var victoryTrigger: Int
    @Binding var defeatTrigger: Int

    func body(content: Content) -> some View {
        content
            .trinketSensoryFeedback(.success, trigger: victoryTrigger, enabled: battleSession.hapticsEnabled)
            .trinketSensoryFeedback(.error, trigger: defeatTrigger, enabled: battleSession.hapticsEnabled)
            .onChange(of: battleSession.spectacle.outcomePresentation) { _, newValue in
                switch newValue {
                case .victory:
                    victoryTrigger &+= 1
                case .defeat:
                    defeatTrigger &+= 1
                case .battle, .pendingVictory:
                    break
                }
            }
    }
}
