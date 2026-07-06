import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

struct BattleView: View {
    @Environment(AppState.self) private var appState
    @State private var isShowingBattleLog = false
    @State private var timelineStartDate: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let configuration: ActiveBattleConfiguration

    init(configuration: ActiveBattleConfiguration) {
        self.configuration = configuration
        _timelineStartDate = State(initialValue: Date())
    }

    var body: some View {
        @Bindable var battleSession = appState.battle
        if let battleState = battleSession.state {
            bodyContent(battleSession: battleSession, battleState: battleState)
        }
    }

    private func bodyContent(battleSession: BattleSession, battleState: BattleState) -> some View {
        Group {
            if battleSession.isShowingVictory, let victorySummary = battleSession.victorySummary {
                VictoryView(
                    enemyName: battleState.enemy.name,
                    summary: victorySummary,
                    primaryActionTitle: hasStageProgression ? "Continue" : "Battle Again",
                    onPrimaryAction: {
                        if hasStageProgression {
                            appState.completeActiveBattle(
                                configuration,
                                battleEarnedGold: victorySummary.battleGold,
                                materialRewards: victorySummary.materialRewards
                            )
                        } else {
                            appState.restartActiveBattle()
                        }
                    }
                )
            } else if battleSession.isShowingDefeat {
                DefeatView(
                    enemyName: battleState.enemy.name,
                    onBattleAgain: {
                        appState.restartActiveBattle()
                    }
                )
            } else {
                battlefieldWithTimeline(battleSession: battleSession, battleState: battleState)
            }
        }
        .trinketScreenBackground(.battle)
        .navigationTitle(battleSession.isShowingVictory ? "Victory" : battleSession.isShowingDefeat ? "Defeat" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(battleSession.isShowingVictory || battleSession.isShowingDefeat ? .automatic : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    if !battleSession.isShowingVictory, !battleSession.isShowingDefeat {
                        Button {
                            battleSession.isPaused.toggle()
                        } label: {
                            Image(systemName: battleSession.isPaused ? "play.fill" : "pause.fill")
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .accessibilityIdentifier("Battle Pause Button")
                    }

                    battleActionsMenu(battleSession: battleSession)
                }
            }
        }
        .sheet(isPresented: $isShowingBattleLog, onDismiss: {
            appState.battle.restorePauseAfterOverlay()
        }, content: {
            BattleLogSheet(
                entries: battleSession.state?.log ?? []
            )
            .presentationDetents([.medium])
        })
        .onChange(of: isShowingBattleLog) { _, isShowing in
            if isShowing {
                appState.battle.pauseForOverlay()
                appState.battle.syncLogForDisplay()
            }
        }
        .onChange(of: configuration.id) { _, _ in
            battleSession.clearOutcomePresentation()
            timelineStartDate = Date()
        }
    }

    private var hasStageProgression: Bool {
        configuration.stageID != nil
    }

    private var battleTickInterval: TimeInterval {
        AppEnvironment.shared.battleTickInterval ?? AppEnvironment.defaultBattleTickInterval
    }

    private func battlefieldWithTimeline(battleSession: BattleSession, battleState: BattleState) -> some View {
        TimelineView(.periodic(from: timelineStartDate, by: battleTickInterval)) { context in
            battlefield(battleSession: battleSession, battleState: battleState)
                .onChange(of: context.date) { _, date in
                    appState.handleBattlePeriodicTick(configuration: configuration, at: date)
                }
        }
    }

    private func battleActionsMenu(battleSession: BattleSession) -> some View {
        Menu {
            Button {
                isShowingBattleLog = true
            } label: {
                Label("Combat Log", systemImage: "list.bullet.rectangle")
            }
            .accessibilityIdentifier("Combat Log")

            if !battleSession.isShowingVictory, !battleSession.isShowingDefeat {
                Divider()

                Button(role: .destructive) {
                    appState.battle.endBattle()
                } label: {
                    Label("Retreat", systemImage: "figure.run")
                }
                .tint(TrinketDesign.Colors.destructive)
                .accessibilityIdentifier("Retreat")
            }
        } label: {
            Label {
                Text("Battle actions")
            } icon: {
                Image(systemName: "ellipsis")
            }
            .labelStyle(.iconOnly)
        }
        .accessibilityLabel("Battle Menu")
        .accessibilityIdentifier("Battle Menu")
    }

    private func battlefield(battleSession: BattleSession, battleState: BattleState) -> some View {
        GeometryReader { geometry in
            let layout = BattleCardGridLayout.metrics(in: geometry.size)

            BattlefieldView(
                layout: layout,
                enemyPane: combatantPane(
                    for: battleState.enemy,
                    health: battleState.health(of: battleState.enemy),
                    healthBarPlacement: .bottom,
                    battleState: battleState,
                    battleSession: battleSession
                ),
                heroPane: combatantPane(
                    for: battleState.hero,
                    health: battleState.health(of: battleState.hero),
                    healthBarPlacement: .top,
                    battleState: battleState,
                    battleSession: battleSession
                ),
                petPane: combatantPane(
                    for: battleState.pet,
                    health: battleState.health(of: battleState.pet),
                    healthBarPlacement: .top,
                    battleState: battleState,
                    battleSession: battleSession
                )
            )
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
    }

    private func combatantPane(
        for combatant: Combatant,
        health: Int,
        healthBarPlacement: BattleCombatantPane.HealthBarPlacement,
        battleState: BattleState,
        battleSession: BattleSession
    ) -> BattleCombatantPane {
        let mana: Int
        let maxMana: Int
        if combatant.id == battleState.hero.id {
            mana = battleState.mana(of: battleState.hero)
            maxMana = battleState.maxMana(of: battleState.hero)
        } else if combatant.id == battleState.pet.id {
            mana = battleState.mana(of: battleState.pet)
            maxMana = battleState.maxMana(of: battleState.pet)
        } else {
            mana = 0
            maxMana = 0
        }
        return BattleCombatantPane(
            combatant: combatant,
            health: health,
            maxHealth: battleState.maxHealth(of: combatant),
            mana: mana,
            maxMana: maxMana,
            healthBarPlacement: healthBarPlacement,
            events: feedbackEvents(for: combatant, battleSession: battleSession),
            reduceMotion: reduceMotion,
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

    private func feedbackEvents(for combatant: Combatant, battleSession: BattleSession) -> [ActionEvent] {
        battleSession.feedbackEvents(for: combatant.id)
    }

}
