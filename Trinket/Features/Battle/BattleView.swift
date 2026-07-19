import BattleEngine
import Observation
import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct BattleView: View {
    @Environment(AppState.self) private var appState
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
    @Namespace private var cinematicNamespace

    private let configuration: ActiveBattleConfiguration

    init(configuration: ActiveBattleConfiguration) {
        self.configuration = configuration
    }

    var body: some View {
        @Bindable var battleSession = appState.battle
        let presentation = battleSession.presentation
        if presentation.configurationID == configuration.id {
            bodyContent(battleSession: battleSession)
        }
    }

    private func bodyContent(battleSession: BattleSession) -> some View {
        outcomeContent(battleSession: battleSession)
            .trinketScreenBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbarVisibility(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    battleActionsMenu(canRetreat: battleSession.canRetreat)
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
                prewarmBattlePresentationEffects()
                installChipBridge()
            }
            .onChange(of: configuration.id) { _, _ in
                battleSession.clearOutcomePresentation()
                castPresentation.reset()
                CombatFeedbackRasterPool.shared.removeAll()
                CombatFeedbackRasterPool.shared.resetDiagnostics()
                prewarmBattlePresentationEffects()
                installChipBridge()
            }
            .onDisappear {
                appState.battle.onFeedbackItemsChanged = nil
                CombatFeedbackRasterPool.shared.removeAll()
                CombatFeedbackRasterPool.shared.resetDiagnostics()
            }
    }

    private func battleActionsMenu(canRetreat: Bool) -> some View {
        Menu {
            Button {
                appState.presentCombatLog()
            } label: {
                Label("Combat Log", systemImage: "list.bullet.rectangle")
            }
            .accessibilityIdentifier(AccessibilityID.Battle.combatLog)

            if canRetreat {
                Button(role: .destructive) {
                    appState.endBattleReturningToOrigin()
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

    @ViewBuilder
    private func outcomeContent(battleSession: BattleSession) -> some View {
        if battleSession.isShowingVictory, let victorySummary = battleSession.victorySummary {
            VictoryView(
                enemyName: configuration.enemy?.name ?? "Enemy",
                summary: victorySummary,
                primaryActionTitle: hasStageProgression ? "Loot All" : "Battle Again",
                onPrimaryAction: {
                    if hasStageProgression {
                        let didPersist = appState.completeActiveBattle(
                            configuration,
                            battleEarnedGold: victorySummary.rawBattleEarnedGold,
                            materialRewards: victorySummary.materialRewards
                        )
                        if !didPersist {
                            persistFailureMessage = StageMapMessage(
                                title: "Couldn't Save Progress",
                                message: "Your victory was not saved. Stay on this screen and try Continue again."
                            )
                        }
                        return didPersist
                    } else {
                        appState.restartActiveBattle()
                        return true
                    }
                }
            )
        } else if battleSession.isShowingDefeat {
            if let labyrinthNodeID = configuration.labyrinthNodeID {
                DefeatView(
                    enemyName: configuration.enemy?.name ?? "Enemy",
                    primaryButtonTitle: "Return to Map",
                    onPrimaryAction: {
                        appState.recordLabyrinthDefeat(nodeID: labyrinthNodeID)
                        appState.endBattleReturningToOrigin()
                    }
                )
            } else {
                DefeatView(
                    enemyName: configuration.enemy?.name ?? "Enemy",
                    onPrimaryAction: {
                        appState.restartActiveBattle()
                    }
                )
            }
        } else {
            battlefield(battleSession: battleSession)
        }
    }

    private var hasStageProgression: Bool {
        configuration.hasProgressionRewards
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
                    battleSize: geometry.size,
                    onPlay: playCard(_:request:),
                    onInteractionChanged: updateCombatantTapSuppression(_:),
                    onAttackWindUp: beginPartyAttackWindUp(for:),
                    onAttackCancel: cancelPartyAttack(for:),
                    onReady: {
                        wireAutoEndTurn(battleSession)
                        battleSession.considerAutoEndTurn(
                            journey: appState.journey,
                            homestead: appState.homestead
                        )
                    }
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

                BattleCinematicLane(namespace: cinematicNamespace)
                    .zIndex(10)

                #if DEBUG
                if let scenario = AppEnvironment.shared.battlePerformanceScenario {
                    BattlePerformanceScenarioHarness(
                        scenario: scenario,
                        appState: appState,
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
            enemyID: battleSession.state?.enemy.id,
            heroID: battleSession.state?.hero.id,
            companionID: battleSession.state?.companion.id
        )
    }

    private func playCard(_ card: BattleCard, request: CardActivationRequest) -> Bool {
        let outcome = appState.battle.playCard(
            cardID: card.id,
            journey: appState.journey,
            homestead: appState.homestead
        )
        guard case let .committed(earnedGold) = outcome else { return false }
        if let earnedGold {
            completeClaimedStageVictoryIfNeeded(earnedGold: earnedGold)
        }
        if let combatantID = appState.battle.combatantID(for: card.owner) {
            appState.battle.commitAttackSwing(for: combatantID)
        }
        castPresentation.append(request)
        return true
    }

    private func beginPartyAttackWindUp(for card: BattleCard) {
        guard let combatantID = appState.battle.combatantID(for: card.owner) else { return }
        appState.battle.beginAttackWindUp(for: combatantID)
    }

    private func cancelPartyAttack(for card: BattleCard) {
        guard let combatantID = appState.battle.combatantID(for: card.owner) else { return }
        appState.battle.cancelAttack(for: combatantID)
    }

    private func wireAutoEndTurn(_ battleSession: BattleSession) {
        battleSession.onTurnAutoEnded = { [weak appState] earnedGold in
            guard let appState,
                  let earnedGold,
                  let configuration = appState.battle.activeBattle else { return }
            let didPersist = appState.completeActiveBattle(
                configuration,
                battleEarnedGold: earnedGold
            )
            if !didPersist {
                // Fall back to victory chrome so Loot All can retry; retreat stays locked
                // once outcome is resolved, so silent failure would hard-stick the fight.
                appState.battle.presentVictoryChromeForPersistRetry(homestead: appState.homestead)
                persistFailureMessage = StageMapMessage(
                    title: "Couldn't Save Progress",
                    message: "Your victory was not saved. Stay on this screen and try Continue again."
                )
            }
        }
    }

    private func completeClaimedStageVictoryIfNeeded(earnedGold: Int) {
        guard let configuration = appState.battle.activeBattle else { return }
        let didPersist = appState.completeActiveBattle(
            configuration,
            battleEarnedGold: earnedGold
        )
        if !didPersist {
            appState.battle.presentVictoryChromeForPersistRetry(homestead: appState.homestead)
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
            presentation: appState.battle.presentation,
            role: role,
            hapticsEnabled: appState.options.hapticsEnabled,
            cinematicNamespace: cinematicNamespace,
            onCombatantTap: showDetails(for:)
        )
    }

    private func showDetails(for combatant: Combatant) {
        guard !interactionState.suppressCombatantTaps,
              let battleState = appState.battle.state else { return }
        appState.battle.presentCombatantDetail(
            CombatantCardDetail.battleSnapshot(
                configuration: configuration,
                combatant: combatant,
                health: battleState.health(of: combatant),
                activeEffectSummaries: battleState.effectSummaries(of: combatant)
            )
        )
    }

    private func updateCombatantTapSuppression(_ isHandInteracting: Bool) {
        interactionState.suppressCombatantTaps = isHandInteracting
    }
}

@MainActor
@Observable
final class BattleInteractionState {
    var suppressCombatantTaps = false
}

private struct BattleCombatantProjectionPane: View {
    enum Role {
        case hero
        case companion
        case enemy
    }

    let presentation: BattlePresentationState
    let role: Role
    let hapticsEnabled: Bool
    let cinematicNamespace: Namespace.ID
    let onCombatantTap: (Combatant) -> Void

    private var snapshot: BattleCombatantPresentation? {
        switch role {
        case .hero:
            presentation.hero
        case .companion:
            presentation.companion
        case .enemy:
            presentation.enemy
        }
    }

    var body: some View {
        if let snapshot {
            BattleCombatantPane(
                combatant: snapshot.combatant,
                health: snapshot.health,
                maxHealth: snapshot.maxHealth,
                mana: snapshot.mana,
                maxMana: snapshot.maxMana,
                hapticsEnabled: hapticsEnabled,
                cinematicNamespace: cinematicNamespace,
                recoilDirection: role == .enemy ? .up : .down,
                onCombatantTap: { onCombatantTap(snapshot.combatant) }
            )
        }
    }
}

/// Hand observation is isolated from combatant projections. Drawing or spending a
/// card updates this lane without rebuilding the static battlefield hierarchy.
private struct BattleHandProjectionLane: View {
    @Environment(AppState.self) private var appState

    let presentation: BattlePresentationState
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
                appState.battle.presentAbilityDetail(card.ability)
            },
            onPlay: { card, request in
                let didPlay = onPlay(card, request)
                if didPlay {
                    cardPlayFeedbackToken &+= 1
                }
                return didPlay
            },
            hapticsEnabled: appState.options.hapticsEnabled,
            battleFrame: CGRect(origin: .zero, size: battleSize),
            configuration: .init(),
            onCardInteractionChanged: onInteractionChanged,
            onAttackWindUp: onAttackWindUp,
            onAttackCancel: onAttackCancel
        )
        .trinketSensoryFeedback(
            .impact(weight: .medium),
            trigger: cardPlayFeedbackToken,
            enabled: appState.options.hapticsEnabled
        )
        .onAppear(perform: onReady)
    }
}

/// Keeps cinematic observation out of `BattleView.body`. Phase changes can now
/// insert/update the full-screen overlay without rebuilding the battlefield, hand,
/// toolbar, and always-mounted feedback hosts behind it.
private struct BattleCinematicLane: View {
    @Environment(AppState.self) private var appState
    let namespace: Namespace.ID

    var body: some View {
        let battleSession = appState.battle
        if let cinematic = battleSession.activeCinematic {
            UltimateCinematicOverlay(
                cinematic: cinematic,
                canSkip: appState.options.canSkipUltimateCinematic(),
                effectsVolume: appState.options.effectsVolume,
                namespace: namespace,
                onPlaying: { battleSession.markCinematicPlaying() },
                onRequestSkip: { battleSession.requestSkipCinematic() },
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
    func installChipBridge() {
        appState.battle.onFeedbackItemsChanged = { update in
            CombatFeedbackChipBridge.publish(update)
        }
    }

    func prewarmBattlePresentationEffects() {
        BattlePresentationWarmup.prepare(
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
        // Start prune / multimodal loops, paced raster prepare, and the chip motion
        // clock before the first chip publish so that frame only bumps dates /
        // enqueues work / inserts layers.
        appState.battle.prepareFeedbackScheduler()
        CombatFeedbackRasterPool.shared.prewarmPacedPrepareLoop()
        CombatFeedbackRasterUIView.prewarmMotionClock()
        let handArtNames = appState.battle.hand.compactMap { $0.ability.artReference?.imageName }
        guard !handArtNames.isEmpty else { return }
        Task { @MainActor in
            await PreparedArtworkCache.shared.prepareAndPin(names: handArtNames)
        }
        // Prime the full cast stack with the lead hand card (invisible).
        handCastPrewarmArtwork = handArtNames[0]
    }
}
