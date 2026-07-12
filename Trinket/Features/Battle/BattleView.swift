import BattleEngine
import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct BattleView: View {
    @Environment(AppState.self) private var appState
    @State private var persistFailureMessage: StageMapMessage?
    @Namespace private var cinematicNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        let isShowingOutcome = battleSession.isShowingVictory || battleSession.isShowingDefeat

        return outcomeContent(battleSession: battleSession, battleState: battleState)
            .trinketScreenBackground(.battle)
            .navigationTitle(battleSession.isShowingVictory ? "Victory" : battleSession.isShowingDefeat ? "Defeat" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbarVisibility(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    battleActionsMenu(canRetreat: !isShowingOutcome)
                }
            }
            .alert(item: $persistFailureMessage) { message in
                Alert(
                    title: Text(message.title),
                    message: Text(message.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onChange(of: configuration.id) { _, _ in
                battleSession.clearOutcomePresentation()
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
        .accessibilityLabel("Battle Actions")
        .accessibilityIdentifier(AccessibilityID.Battle.actionsMenu)
    }

    @ViewBuilder
    private func outcomeContent(battleSession: BattleSession, battleState: BattleState) -> some View {
        if battleSession.isShowingVictory, let victorySummary = battleSession.victorySummary {
            VictoryView(
                enemyName: battleState.enemy.name,
                summary: victorySummary,
                primaryActionTitle: hasStageProgression ? "Continue" : "Battle Again",
                onPrimaryAction: {
                    if hasStageProgression {
                        let didPersist = appState.completeActiveBattle(
                            configuration,
                            battleEarnedGold: victorySummary.battleGold,
                            materialRewards: victorySummary.materialRewards
                        )
                        if !didPersist {
                            persistFailureMessage = StageMapMessage(
                                title: "Couldn't Save Progress",
                                message: "Your victory was not saved. Stay on this screen and try Continue again."
                            )
                        }
                    } else {
                        appState.restartActiveBattle()
                    }
                }
            )
        } else if battleSession.isShowingDefeat {
            if let labyrinthNodeID = configuration.labyrinthBattle?.nodeID {
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
                    petPane: combatantPane(
                        for: battleState.pet,
                        health: battleState.health(of: battleState.pet),
                        battleState: battleState,
                        battleSession: battleSession
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                BattleHandView(
                    cards: battleSession.hand,
                    isPlayable: { battleSession.isCardPlayable($0) },
                    onTap: { card in
                        battleSession.presentAbilityDetail(card.ability)
                    },
                    onPlay: { card in
                        playCard(cardID: card.id)
                    }
                )
                .frame(height: BattleCardGridLayout.handReservedHeight)
                .zIndex(1)
                .onAppear {
                    wireAutoEndTurn(battleSession)
                    battleSession.considerAutoEndTurn(
                        journey: appState.journey,
                        homestead: appState.homestead
                    )
                }

                cinematicOverlay(for: battleSession)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    @ViewBuilder
    private func cinematicOverlay(for battleSession: BattleSession) -> some View {
        if let cinematic = battleSession.activeCinematic {
            UltimateCinematicOverlay(
                cinematic: cinematic,
                reduceMotion: reduceMotion,
                canSkip: appState.options.canSkipUltimateCinematic(),
                effectsVolume: appState.options.effectsVolume,
                namespace: cinematicNamespace,
                onPlaying: { battleSession.markCinematicPlaying() },
                onRequestSkip: { battleSession.requestSkipCinematic() },
                onAutoFinish: { battleSession.beginCinematicCollapse() },
                onCollapseFinished: { battleSession.completeCinematicCollapse() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .zIndex(10)
        }
    }

    private func playCard(cardID: Int) {
        if let earnedGold = appState.battle.playCard(
            cardID: cardID,
            journey: appState.journey,
            homestead: appState.homestead
        ), let configuration = appState.battle.activeBattle {
            _ = appState.completeActiveBattle(configuration, battleEarnedGold: earnedGold)
        }
    }

    private func wireAutoEndTurn(_ battleSession: BattleSession) {
        battleSession.onTurnAutoEnded = { [weak appState] earnedGold in
            guard let appState,
                  let earnedGold,
                  let configuration = appState.battle.activeBattle else { return }
            _ = appState.completeActiveBattle(configuration, battleEarnedGold: earnedGold)
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
            reduceMotion: reduceMotion,
            cinematicNamespace: cinematicNamespace,
            onCombatantTap: { showDetails(for: combatant, battleState: battleState) }
        )
    }

    private func showDetails(for combatant: Combatant, battleState: BattleState) {
        appState.battle.presentCombatantDetail(
            CombatantCardDetail.battleSnapshot(
                configuration: configuration,
                combatant: combatant,
                health: battleState.health(of: combatant),
                activeEffectSummaries: battleState.effectSummaries(of: combatant)
            )
        )
    }
}
