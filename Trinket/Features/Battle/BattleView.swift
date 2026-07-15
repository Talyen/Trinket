import BattleEngine
import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct BattleView: View {
    @Environment(AppState.self) private var appState
    @State private var persistFailureMessage: StageMapMessage?
    @State private var cardPlayFeedbackToken = 0
    @State private var castingCards: [CardActivationRequest] = []
    @State private var showCastEffectsPrewarm = true
    @State private var performanceForcedDrag: (cardID: Int, translation: CGSize)?
    /// Blocks combatant detail Buttons while a hand card is held, and briefly after
    /// release so the same finger-up cannot open details.
    @State private var suppressCombatantTaps = false
    @State private var handInteractionGeneration = 0
    @Namespace private var cinematicNamespace

    private let configuration: ActiveBattleConfiguration

    init(configuration: ActiveBattleConfiguration) {
        self.configuration = configuration
    }

    var body: some View {
        @Bindable var battleSession = appState.battle
        if let battleState = battleSession.state {
            bodyContent(battleSession: battleSession, battleState: battleState)
        }
    }

    private func bodyContent(battleSession: BattleSession, battleState: BattleState) -> some View {
        outcomeContent(battleSession: battleSession, battleState: battleState)
            .trinketScreenBackground()
            .navigationTitle(battleSession.isShowingDefeat ? "Defeat" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbarVisibility(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    battleActionsMenu(canRetreat: battleSession.canRetreat)
                }
            }
            .trinketSensoryFeedback(
                .impact(weight: .medium),
                trigger: cardPlayFeedbackToken,
                enabled: appState.options.hapticsEnabled
            )
            .alert(item: $persistFailureMessage) { message in
                Alert(
                    title: Text(message.title),
                    message: Text(message.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onChange(of: configuration.id) { _, _ in
                battleSession.clearOutcomePresentation()
                castingCards = []
                showCastEffectsPrewarm = true
                CombatFeedbackRasterPool.shared.removeAll()
                CombatFeedbackRasterPool.shared.resetDiagnostics()
            }
            .onDisappear {
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
    private func outcomeContent(battleSession: BattleSession, battleState: BattleState) -> some View {
        if battleSession.isShowingVictory, let victorySummary = battleSession.victorySummary {
            VictoryView(
                enemyName: battleState.enemy.name,
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
                    enemyName: battleState.enemy.name,
                    infoTitle: "The Path Holds",
                    infoMessage: "Try again or take another way. The Labyrinth remembers.",
                    primaryButtonTitle: "Return to Map",
                    onPrimaryAction: {
                        appState.recordLabyrinthDefeat(nodeID: labyrinthNodeID)
                        appState.endBattleReturningToOrigin()
                    }
                )
            } else {
                DefeatView(
                    enemyName: battleState.enemy.name,
                    onPrimaryAction: {
                        appState.restartActiveBattle()
                    }
                )
            }
        } else {
            battlefield(battleSession: battleSession, battleState: battleState)
        }
    }

    private var hasStageProgression: Bool {
        configuration.hasProgressionRewards
    }

    private func battlefield(battleSession: BattleSession, battleState: BattleState) -> some View {
        GeometryReader { geometry in
            let layout = BattleCardGridLayout.metrics(in: geometry.size)

            ZStack(alignment: .bottom) {
                BattlefieldView(
                    layout: layout,
                    enemyPane: combatantPane(
                        for: battleState.enemy,
                        health: battleState.health(of: battleState.enemy),
                        battleState: battleState,
                        battleSession: battleSession
                    ),
                    heroPane: combatantPane(
                        for: battleState.hero,
                        health: battleState.health(of: battleState.hero),
                        battleState: battleState,
                        battleSession: battleSession
                    ),
                    companionPane: combatantPane(
                        for: battleState.companion,
                        health: battleState.health(of: battleState.companion),
                        battleState: battleState,
                        battleSession: battleSession
                    )
                )
                .allowsHitTesting(!suppressCombatantTaps)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                battleHand(
                    battleSession: battleSession,
                    battleSize: geometry.size
                )

                if showCastEffectsPrewarm,
                   AppEnvironment.shared.battlePerformanceScenario != .firstCardCastCold {
                    CardCastEffectsPrewarmView {
                        showCastEffectsPrewarm = false
                    }
                }

                CardCastEffectsLayer(requests: castingCards) { requestID in
                    castingCards.removeAll { $0.id == requestID }
                }
                .zIndex(3)

                cinematicOverlay(for: battleSession)
                    .zIndex(10)

                #if DEBUG
                if let scenario = AppEnvironment.shared.battlePerformanceScenario {
                    BattlePerformanceScenarioHarness(
                        scenario: scenario,
                        appState: appState,
                        battleSession: battleSession,
                        battleSize: geometry.size,
                        castingCards: $castingCards,
                        forcedDrag: $performanceForcedDrag
                    )
                    .zIndex(20)
                }
                #endif
            }
            .coordinateSpace(.named(BattleCoordinateSpace.field))
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func battleHand(
        battleSession: BattleSession,
        battleSize: CGSize
    ) -> some View {
        BattleHandView(
            cards: battleSession.hand,
            isPlayable: { battleSession.isCardPlayable($0) },
            onTap: { card in
                battleSession.presentAbilityDetail(card.ability)
            },
            onPlay: { card, request in
                BattleFramePacingSignposts.event(
                    BattleFramePacingSignposts.Name.cardCommit,
                    detail: "card=\(card.id) ability=\(card.ability.id) owner=\(card.owner)"
                )
                let didPlay = playCard(cardID: card.id)
                guard didPlay else { return false }
                castingCards.append(request)
                let maxCasts = TrinketMotion.Battle.maxConcurrentCardCasts
                if castingCards.count > maxCasts {
                    castingCards.removeFirst(castingCards.count - maxCasts)
                }
                cardPlayFeedbackToken &+= 1
                return true
            },
            hapticsEnabled: appState.options.hapticsEnabled,
            battleFrame: CGRect(origin: .zero, size: battleSize),
            configuration: .init(),
            forcedDragTranslation: performanceForcedDrag,
            onCardInteractionChanged: updateCombatantTapSuppression(_:)
        )
        .frame(height: BattleCardGridLayout.handReservedHeight)
        .offset(y: -BattleHandLayout.bottomRise)
        .zIndex(1)
        .onAppear {
            wireAutoEndTurn(battleSession)
            battleSession.considerAutoEndTurn(
                journey: appState.journey,
                homestead: appState.homestead
            )
        }
    }

    @ViewBuilder
    private func cinematicOverlay(for battleSession: BattleSession) -> some View {
        if let cinematic = battleSession.activeCinematic {
            UltimateCinematicOverlay(
                cinematic: cinematic,
                canSkip: appState.options.canSkipUltimateCinematic(),
                effectsVolume: appState.options.effectsVolume,
                namespace: cinematicNamespace,
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
            .zIndex(10)
        }
    }

    private func playCard(cardID: Int) -> Bool {
        let wasInHand = appState.battle.hand.contains { $0.id == cardID }
        guard wasInHand else { return false }
        if let earnedGold = appState.battle.playCard(
            cardID: cardID,
            journey: appState.journey,
            homestead: appState.homestead
        ) {
            completeClaimedStageVictoryIfNeeded(earnedGold: earnedGold)
        }
        return !appState.battle.hand.contains { $0.id == cardID }
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

    private func combatantPane(
        for combatant: Combatant,
        health: Int,
        battleState: BattleState,
        battleSession: BattleSession
    ) -> BattleCombatantPane {
        BattleCombatantPane(
            combatant: combatant,
            health: health,
            maxHealth: battleState.maxHealth(of: combatant),
            mana: battleState.mana(of: combatant),
            maxMana: battleState.maxMana(of: combatant),
            items: battleSession.feedbackItems(for: combatant.id),
            hitReaction: battleSession.hitReactionsByTargetID[combatant.id],
            keywordBursts: battleSession.keywordBursts(for: combatant.id),
            skillCallout: battleSession.activeSkillCallout?.actorID == combatant.id
                ? battleSession.activeSkillCallout
                : nil,
            hapticsEnabled: appState.options.hapticsEnabled,
            cinematicNamespace: cinematicNamespace,
            onCombatantTap: { showDetails(for: combatant, battleState: battleState) }
        )
    }

    private func showDetails(for combatant: Combatant, battleState: BattleState) {
        guard !suppressCombatantTaps else { return }
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
        if isHandInteracting {
            handInteractionGeneration &+= 1
            suppressCombatantTaps = true
            return
        }

        let generation = handInteractionGeneration
        Task { @MainActor in
            try? await Task.sleep(
                for: .seconds(BattleHandLayout.combatantTapSuppressionGrace)
            )
            guard generation == handInteractionGeneration else { return }
            suppressCombatantTaps = false
        }
    }
}
