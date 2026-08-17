import BattleEngine
import Observation
import SwiftUI
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureContracts
import TrinketFeatureSupport

public struct BattleView: View {
    @State private var castPresentation = BattleCastPresentationState()
    /// Blocks combatant detail Buttons while a hand card is held, and briefly after
    /// release so the same finger-up cannot open details.
    @State private var interactionState = BattleInteractionState()

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
        performanceScenario: BattlePerformanceScenario? = nil
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
            .toolbar {
                if !battleSession.spectacle.isShowingVictory,
                   !battleSession.spectacle.isShowingDefeat,
                   battleSession.spectacle.activeCinematic == nil {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        BattleAutoToggle(battleSession: battleSession)
                        battleActionsMenu(canRetreat: battleSession.canRetreat)
                    }
                }
            }
            .statusBarHidden(battleSession.spectacle.activeCinematic != nil)
            .onChange(of: configuration.id) { _, _ in
                castPresentation.reset()
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
                BattleFieldLane(
                    configuration: configuration,
                    presentationContext: presentationContext,
                    battleSession: battleSession,
                    interactionState: interactionState,
                    castPresentation: castPresentation,
                    performanceScenario: debugPerformanceScenario
                )
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

/// Isolated battlefield observation scope. `BattleView` must not read live
/// combatant projections here — helper methods on the parent would fuse HP/hand
/// writes into toolbar and outcome observation.
private struct BattleFieldLane: View {
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
                layout: layout
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
                        onCombatantTap: showDetails(for:)
                    ),
                    heroPane: BattleCombatantProjectionPane(
                        presentation: presentation,
                        role: .hero,
                        hapticsEnabled: hapticsEnabled,
                        onCombatantTap: showDetails(for:)
                    ),
                    companionPane: BattleCombatantProjectionPane(
                        presentation: presentation,
                        role: .companion,
                        hapticsEnabled: hapticsEnabled,
                        onCombatantTap: showDetails(for:)
                    ),
                    interactionState: interactionState
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                BattlefieldFeedbackOverlay(
                    layout: layout,
                    anchors: anchors,
                    enemyID: configuration.enemy?.id,
                    heroID: configuration.hero.combatant.id,
                    companionID: configuration.companion.combatant.id
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                BattleHandProjectionLane(
                    presentation: presentation,
                    hapticsEnabled: hapticsEnabled,
                    battleSize: geometry.size,
                    castPresentation: castPresentation,
                    interactionState: interactionState,
                    onPlay: playCard(_:request:),
                    onInteractionChanged: updateCombatantTapSuppression(_:),
                    onAttackWindUp: beginPartyAttackWindUp(for:),
                    onAttackCancel: cancelPartyAttack(for:)
                )
                .frame(height: BattleCardGridLayout.handReservedHeight)
                .offset(y: -BattleHandLayout.bottomRise)
                .zIndex(1)

                CardCastPresentationLane(presentation: castPresentation)
                    .zIndex(3)

                BattleCastPrewarmLane(presentation: presentation)
                    .zIndex(2)

                BattleCinematicLane(
                    effectsVolume: battleSession.effectsVolume
                )
                .zIndex(10)

                BattleFeedbackBridgeLane()

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

    private func playCard(_ card: BattleCard, request: CardActivationRequest) -> Bool {
        let outcome = battleSession.playCard(
            cardID: card.id
        )
        guard case .committed = outcome else { return false }
        let actorID = battleSession.combatantID(for: card.owner)
        if let actorID {
            battleSession.commitAttackSwing(for: actorID)
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
                    : []
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
    let castPresentation: BattleCastPresentationState
    let interactionState: BattleInteractionState
    let onPlay: (BattleCard, CardActivationRequest) -> Bool
    let onInteractionChanged: (Bool) -> Void
    let onAttackWindUp: (BattleCard) -> Void
    let onAttackCancel: (BattleCard) -> Void

    @State private var cardPlayFeedbackToken = 0

    var body: some View {
        let hand = presentation.hand
        let playableIDs = presentation.playableCardIDs
        let ownerControlSkipKeywords = presentation.ownerControlSkipKeywords
        BattleHandView(
            cards: hand,
            isPlayable: { playableIDs.contains($0.id) },
            ownerControlSkipKeywords: ownerControlSkipKeywords,
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
            hapticsEnabled: hapticsEnabled,
            battleFrame: CGRect(origin: .zero, size: battleSize),
            configuration: .init(),
            autoLiftCardID: interactionState.autoLiftCardID,
            onCardInteractionChanged: onInteractionChanged,
            onAttackWindUp: onAttackWindUp,
            onAttackCancel: onAttackCancel
        )
        .trinketSensoryFeedback(
            .impact(weight: .medium),
            trigger: cardPlayFeedbackToken,
            enabled: hapticsEnabled
        )
        .overlay {
            BattleAutoPlayLane(
                battleSession: battleSession,
                battleSize: battleSize,
                castPresentation: castPresentation,
                interactionState: interactionState,
                onPlay: onPlay
            )
        }
    }
}

/// Keeps cinematic observation out of `BattleView.body`. Phase changes can now
/// insert/update the full-screen overlay without rebuilding the battlefield, hand,
/// toolbar, and always-mounted feedback hosts behind it.
private struct BattleCinematicLane: View {
    @Environment(BattleSession.self) private var battleSession
    let effectsVolume: Double

    var body: some View {
        if let cinematic = battleSession.spectacle.activeCinematic {
            UltimateCinematicOverlay(
                cinematic: cinematic,
                effectsVolume: effectsVolume,
                openingStyle: openingStyle,
                exitStyle: closingStyle,
                onPlaying: { battleSession.markCinematicPlaying() },
                onAutoFinish: { cinematicID in
                    battleSession.beginCinematicCollapse(expectedID: cinematicID)
                },
                onCollapseFinished: { cinematicID in
                    battleSession.completeCinematicCollapse(expectedID: cinematicID)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var openingStyle: UltimateCinematicEnterStyle {
        #if DEBUG
        battleSession.previewLabConfig?.openingStyle ?? .fade
        #else
        .fade
        #endif
    }

    private var closingStyle: UltimateCinematicExitStyle {
        #if DEBUG
        battleSession.previewLabConfig?.closingStyle ?? .fade
        #else
        .fade
        #endif
    }
}

/// Owns the imperative UIKit feedback bridge alongside the always-mounted hosts
/// that consume it, instead of making the battle screen a global-cache manager.
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
                    onChange: CombatFeedbackChipBridge.publish
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
    let artworkName: String?
}

/// Primes the full cast hierarchy once the first dealt card makes a cast imminent.
/// State stays local so hand changes do not invalidate the battlefield hierarchy.
private struct BattleCastPrewarmLane: View {
    let presentation: BattlePresentationState
    @State private var artworkName: String?
    @State private var preparedConfigurationID: UUID?

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
                      let artworkName = prewarmKey.artworkName
                else { return }

                defer {
                    PreparedArtworkCache.shared.releasePins(names: [artworkName])
                }
                await PreparedArtworkCache.shared.prepareAndPin(names: [artworkName])
                guard !Task.isCancelled,
                      presentation.configurationID == configurationID
                else { return }
                preparedConfigurationID = configurationID
                self.artworkName = artworkName
            }
    }

    private var prewarmKey: BattleCastPrewarmKey {
        BattleCastPrewarmKey(
            configurationID: presentation.configurationID,
            artworkName: presentation.hand.first?.ability.artReference?.imageName
        )
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
}
