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
    @State private var victoryFeedbackToken = 0
    @State private var defeatFeedbackToken = 0

    private let configuration: BattleRunConfiguration
    private let presentationContext: BattlePresentationContext
    private let battleSession: BattleSession
    private let presentation: BattlePresentationState
    private let spectacle: BattleSpectacleState
    private let completeVictory: (BattleVictorySummary) -> Bool
    private let restartBattle: () -> Bool
    private let retreat: () -> Void
    #if DEBUG
    private let performanceScenario: BattlePerformanceScenario?
    #endif

    public init(
        configuration: BattleRunConfiguration,
        presentationContext: BattlePresentationContext,
        battleSession: BattleSession,
        completeVictory: @escaping (BattleVictorySummary) -> Bool,
        restartBattle: @escaping () -> Bool,
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

    private var input: BattleViewInput {
        BattleViewInput(session: battleSession, presentation: presentation)
    }

    /// Collapses payload-only outcome changes so a refreshed settlement does not
    /// replay the screen crossfade or the success/defeat haptic.
    private var outcomeStage: Int {
        switch spectacle.outcomePresentation {
        case .battle: 0
        case .pendingVictory: 1
        case .victory: 2
        case .defeat: 3
        }
    }

    private func handleOutcomePresentationChange(
        _ oldValue: BattleOutcomePresentation,
        _ newValue: BattleOutcomePresentation,
    ) {
        let wasVictory = if case .victory = oldValue {
            true
        } else {
            false
        }
        let wasDefeat = if case .defeat = oldValue {
            true
        } else {
            false
        }
        switch newValue {
        case .victory where !wasVictory:
            victoryFeedbackToken &+= 1
        case .defeat where !wasDefeat:
            defeatFeedbackToken &+= 1
        case .battle, .pendingVictory, .victory, .defeat:
            break
        }
    }

    private func bodyContent(battleSession: BattleSession) -> some View {
        outcomeContent(battleSession: battleSession)
            .allowsHitTesting(input.isCurrent)
            .accessibilityHidden(!input.isCurrent)
            .environment(battleSession)
            .environment(spectacle)
            .trinketScreenBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbarVisibility(.visible, for: .navigationBar)
            .toolbarVisibility(.hidden, for: .tabBar)
            .toolbar {
                if input.isCurrent, !spectacle.outcomePresentation.isOutcomePresented {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        BattleAutoToggle(battleSession: battleSession, input: input)
                            .disabled(!battleSession.canAcceptBattleCommands)
                        battleActionsMenu(canRetreat: battleSession.canRetreat)
                            .disabled(!battleSession.canAcceptBattleCommands)
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if input.isCurrent, battleSession.isShowingAutoBattlePauseNotice,
                   !spectacle.outcomePresentation.isOutcomePresented {
                    BattleAutoPauseNotice(
                        playManually: {
                            input.perform {
                                $0.isShowingAutoBattlePauseNotice = false
                                $0.scheduleAutoEndIfNeeded()
                            }
                        },
                        retreat: {
                            input.perform {
                                if $0.retreatFromBattle() {
                                    $0.isShowingAutoBattlePauseNotice = false
                                }
                            }
                        },
                    )
                }
            }
            .onChange(of: configuration.id) { _, _ in
                castPresentation.reset()
                interactionState.suppressCombatantTaps = false
            }
    }

    private func battleActionsMenu(canRetreat: Bool) -> some View {
        Menu {
            Button {
                input.perform { $0.presentBattleLog() }
            } label: {
                Label(String(localized: L10n.ui_battleview_combat_log_84d6c), systemImage: "list.bullet.rectangle")
            }
            .accessibilityIdentifier(AccessibilityID.Battle.combatLog)

            #if DEBUG
            Button {
                input.perform { $0.debugSkipCombat() }
            } label: {
                Label(String(localized: L10n.ui_battleview_skip_combat_9b75b), systemImage: "forward.end")
            }
            .accessibilityIdentifier(AccessibilityID.Battle.skipCombat)
            #endif

            Button(role: .destructive) {
                input.perform { $0.retreatFromBattle() }
            } label: {
                Label(String(localized: L10n.ui_battleview_retreat_e6e5c), systemImage: "figure.run")
            }
            .disabled(!canRetreat)
            .accessibilityIdentifier(AccessibilityID.Battle.retreat)
        } label: {
            Image(systemName: "ellipsis")
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(Text(L10n.ui_battleview_battle_actions_310a4))
        }

        .accessibilityIdentifier(AccessibilityID.Battle.actionsMenu)
    }

    private func outcomeContent(battleSession: BattleSession) -> some View {
        ZStack {
            switch spectacle.outcomePresentation {
            case let .victory(victorySummary):
                VictoryView(
                    summary: victorySummary,
                    primaryActionTitle: hasStageProgression ? String(localized: L10n.ui_battleview_loot_all_5f814) :
                        String(localized: L10n.ui_battleview_battle_again_8381e),
                    primaryActionAccessibilityIdentifier: hasStageProgression
                        ? AccessibilityID.Battle.continueButton
                        : AccessibilityID.Battle.battleAgainButton,
                    action: hasStageProgression ? .collect(
                        hapticsEnabled: battleSession.hapticsEnabled,
                        claim: { completeVictoryPrimaryAction(summary: victorySummary) },
                        finish: { input.perform { $0.finishVictoryPresentation(configurationID: configuration.id) } },
                    ) : .immediate { completeVictoryPrimaryAction(summary: victorySummary) },
                    onExceptionalReveal: { input.perform { $0.playPresentationSFX(SFXID.lootExceptional) } },
                )
                .transition(.opacity)
            case let .defeat(settlement):
                defeatContent(battleSession: battleSession, settlement: settlement)
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
        .animation(TrinketMotion.Screen.crossfade, value: outcomeStage)
        .trinketSensoryFeedback(.success, trigger: victoryFeedbackToken, enabled: battleSession.hapticsEnabled)
        .trinketSensoryFeedback(.error, trigger: defeatFeedbackToken, enabled: battleSession.hapticsEnabled)
        .onChange(of: spectacle.outcomePresentation, handleOutcomePresentationChange)
    }

    private func defeatContent(battleSession: BattleSession, settlement: BattleRewardSettlement) -> some View {
        DefeatView(
            configuration: configuration, settlement: settlement,
            didRetreat: battleSession.retreatProgress != nil,
        ) { action in
            guard input.isCurrent else { return false }
            if battleSession.progression == nil {
                switch action {
                case .retry: return restartBattle()
                case .leave:
                    retreat()
                    return true
                }
            }
            return battleSession.claimDefeat(configurationID: configuration.id, settlement: settlement, action: action)
        }
    }

    private func completeVictoryPrimaryAction(summary: BattleVictorySummary) -> Bool {
        #if DEBUG
        print("VICTORY_DIAG action current=\(input.isCurrent) progression=\(hasStageProgression)")
        #endif
        guard input.isCurrent else { return false }
        guard hasStageProgression else {
            // A failed restart must leave the reward sequence in `.ready`, so
            // the primary action re-arms instead of locking on completion.
            return restartBattle()
        }
        return completeVictory(summary)
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

    @State private var measuredHandFrame: CGRect?

    var body: some View {
        GeometryReader { geometry in
            let handFrame = BattleHandLayout.frame(in: geometry.size)
            let battlefieldSize = BattleHandLayout.battlefieldSize(in: geometry.size)
            let layout = BattleCardGridLayout.metrics(in: battlefieldSize)
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

                automaticCardLane(handFrame: handFrame)

                BattleHandProjectionLane(
                    presentation: presentation,
                    hapticsEnabled: hapticsEnabled,
                    onFrameChanged: { frame in
                        if let measuredHandFrame, measuredHandFrame != frame {
                            castPresentation.hideStaleGeometry()
                        }
                        measuredHandFrame = frame
                    },
                    onPlay: { playCard($0, request: $1) },
                    onInteractionChanged: updateCombatantTapSuppression(_:),
                    onLift: beginCardLift,
                    onLiftCancel: cancelCardLift(for:),
                )
                .frame(height: handFrame.height)
                .offset(y: -BattleHandLayout.bottomRise)
                .zIndex(1)

                cardCastLane()
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
                    input: input,
                    isCardCastPacingBlocked: { castPresentation.blocksAutoBattle(at: .now) },
                    isManualInteractionActive: { interactionState.blocksCombatantTaps },
                    playCard: { card in
                        guard let measuredHandFrame, !measuredHandFrame.isEmpty else { return false }
                        return playAutoBattleCard(card, handFrame: measuredHandFrame)
                    },
                )
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func automaticCardLane(handFrame: CGRect) -> some View {
        ForEach(presentation.cardPlayback.automaticCasts) { cast in
            AutomaticCardCastView(
                cast: cast,
                stagingFrame: CGRect(x: handFrame.minX, y: 0, width: handFrame.width, height: max(0, handFrame.minY)),
                handFrame: handFrame,
            ) {
                presentation.cardPlayback.remove(id: cast.id)
            }
        }
    }

    private func cardCastLane() -> some View {
        CardCastPresentationLane(
            presentation: castPresentation,
            playback: presentation.cardPlayback,
            hapticsEnabled: battleSession.hapticsEnabled,
        )
    }

    private func beginCardLift(
        _ card: BattleCard,
        _ mode: BattleCardCuePresentationMode,
    ) {
        input.perform { $0.beginCardCue(card, mode: mode) }
    }

    private func showDetails(for combatant: Combatant) {
        guard input.isCurrent, !interactionState.blocksCombatantTaps,
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
                nodeModifiers: combatant.role == .enemy
                    ? presentationContext.nodeModifiers
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
    let onFrameChanged: (CGRect) -> Void
    let onPlay: (BattleCard, CardActivationRequest) -> Bool
    let onInteractionChanged: (Bool) -> Void
    let onLift: (BattleCard, BattleCardCuePresentationMode) -> Void
    let onLiftCancel: (BattleCard) -> Void

    @State private var cardPlayFeedbackToken = 0

    private var input: BattleViewInput {
        BattleViewInput(session: battleSession, presentation: presentation)
    }

    var body: some View {
        let hand = presentation.hand
        ZStack(alignment: .bottom) {
            BattleHandView(
                cards: hand,
                isDetailPresented: battleSession.overlayAbilityDetail != nil,
                // One play-intent gate for tap, drag, and accessibility
                // activation: the session's own eligibility, plus the
                // visual-only finishing taps a finished battle still accepts.
                isPlayable: { card in input.perform { $0.isHandCardPlayable(card) } ?? false },
                onInspect: { card in
                    input.perform { $0.presentAbilityDetail(card.ability) }
                },
                onPlay: { card, request in
                    let didPlay = onPlay(card, request)
                    if didPlay {
                        cardPlayFeedbackToken &+= 1
                    }
                    return didPlay
                },
                onPlayDenied: { card in
                    input.perform { session in
                        session.denyCardCue(card)
                        session.playPresentationSFX(SFXID.uiDeny)
                    }
                },
                hapticsEnabled: hapticsEnabled,
                onFrameChanged: onFrameChanged,
                onCardInteractionChanged: onInteractionChanged,
                onLift: onLift,
                onLiftCancel: onLiftCancel,
            )
        }
        .allowsHitTesting(input.isCurrent && battleSession.canInteractWithHand)
        .trinketSensoryFeedback(
            .impact(weight: .medium),
            trigger: cardPlayFeedbackToken,
            enabled: hapticsEnabled,
        )
    }
}

/// Invisible battle infrastructure: feedback scheduler preparation (mount
/// lifetime) plus cast-artwork prewarm (per-configuration lifetime).
/// One ZStack member instead of two; the two effects are independent.
private struct BattleInfrastructureLane: View {
    @Environment(BattleSession.self) private var battleSession

    let presentation: BattlePresentationState
    @State private var artworkName: String?
    @State private var preparedConfigurationID: UUID?

    var body: some View {
        Group {
            Color.clear
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)

            if let artworkName {
                CardCastEffectsPrewarmView(artworkName: artworkName) {
                    self.artworkName = nil
                }
            }
        }
        .onAppear {
            battleSession.feedback.prepareScheduler()
            CombatFeedbackRasterUIView.prewarmMotionClock()
        }
        .task(id: presentation.configurationID) {
            guard let configurationID = presentation.configurationID,
                  preparedConfigurationID != configurationID,
                  let name = presentation.hand.lazy.compactMap(\.ability.artReference?.imageName).first
            else { return }

            preparedConfigurationID = configurationID
            artworkName = name
        }
        .onChange(of: presentation.configurationID) { _, newID in
            if newID != preparedConfigurationID {
                preparedConfigurationID = nil
                artworkName = nil
            }
        }
    }
}

private extension BattleView {
    var hasStageProgression: Bool {
        presentationContext.hasProgressionRewards
    }
}
