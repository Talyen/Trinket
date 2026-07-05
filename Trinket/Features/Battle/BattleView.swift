import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

struct BattleView: View {
    @Environment(AppState.self) private var appState
    @State private var battleRun: BattleRun
    @State private var isShowingBattleLog = false
    @State private var isShowingVictory = false
    @State private var isShowingDefeat = false
    @State private var timelineStartDate: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let configuration: ActiveBattleConfiguration

    @State private var victorySummary: BattleVictorySummary?

    init(configuration: ActiveBattleConfiguration) {
        self.configuration = configuration
        _battleRun = State(initialValue: BattleRun(configuration: configuration))
        _isShowingVictory = State(initialValue: false)
        _timelineStartDate = State(initialValue: Date())
    }

    var body: some View {
        @Bindable var battleSession = appState.battle
        let battleState = battleRun.state

        Group {
            if isShowingVictory, let victorySummary {
                VictoryView(
                    enemyName: battleState.enemy.name,
                    summary: victorySummary,
                    primaryActionTitle: hasStageProgression ? "Continue" : "Battle Again",
                    onPrimaryAction: {
                        if hasStageProgression {
                            appState.completeActiveBattle(configuration, battleEarnedGold: victorySummary.battleGold)
                        } else {
                            appState.battle.restartBattle(using: appState.roster, inventory: appState.inventory)
                        }
                    }
                )
            } else if isShowingDefeat {
                DefeatView(
                    enemyName: battleState.enemy.name,
                    onBattleAgain: {
                        appState.battle.restartBattle(using: appState.roster, inventory: appState.inventory)
                    }
                )
            } else {
                battlefieldWithTimeline
            }
        }
        .trinketScreenBackground(.battle)
        .navigationTitle(isShowingVictory ? "Victory" : isShowingDefeat ? "Defeat" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(isShowingVictory || isShowingDefeat ? .automatic : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    if !isShowingVictory, !isShowingDefeat {
                        Button {
                            battleSession.isPaused.toggle()
                        } label: {
                            Image(systemName: battleSession.isPaused ? "play.fill" : "pause.fill")
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .accessibilityIdentifier("Battle Pause Button")
                    }

                    battleActionsMenu
                }
            }
        }
        .sheet(isPresented: $isShowingBattleLog, onDismiss: {
            appState.battle.restorePauseAfterOverlay()
        }, content: {
            BattleLogSheet(
                entries: battleRun.state.log
            )
            .presentationDetents([.medium])
        })
        .onChange(of: isShowingBattleLog) { _, isShowing in
            if isShowing {
                appState.battle.pauseForOverlay()
            }
        }
        .onChange(of: configuration.id) { _, _ in
            battleRun.reset(from: configuration)
            isShowingVictory = false
            isShowingDefeat = false
            victorySummary = nil
            timelineStartDate = Date()
        }
    }

    private var hasStageProgression: Bool {
        configuration.stageID != nil
    }

    private var stageRewardsAlreadyClaimed: Bool {
        guard let stageID = configuration.stageID,
              let stage = GameContent.stage(id: stageID)
        else { return false }
        return appState.journey.current.hasClaimedRewards(for: stage)
    }

    private var battleTickInterval: TimeInterval {
        AppEnvironment.shared.battleTickInterval ?? AppEnvironment.defaultBattleTickInterval
    }

    private var battlefieldWithTimeline: some View {
        TimelineView(.periodic(from: timelineStartDate, by: battleTickInterval)) { context in
            battlefield
                .onChange(of: context.date) { _, date in
                    battleRun.pruneExpiredFeedback(at: date)
                    advanceBattleTick()
                }
        }
    }

    private var battleActionsMenu: some View {
        Menu {
            Button {
                isShowingBattleLog = true
            } label: {
                Label("Combat Log", systemImage: "list.bullet.rectangle")
            }
            .accessibilityIdentifier("Combat Log")

            if !isShowingVictory, !isShowingDefeat {
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

    private var battlefield: some View {
        let battleState = battleRun.state

        return GeometryReader { geometry in
            let layout = BattleCardGridLayout.metrics(in: geometry.size)

            BattlefieldView(
                layout: layout,
                enemyPane: paneConfiguration(
                    for: battleState.enemy,
                    health: battleState.health(of: battleState.enemy),
                    healthBarPlacement: .bottom,
                    battleState: battleState
                ),
                partyPanes: [
                    paneConfiguration(
                        for: battleState.hero,
                        health: battleState.health(of: battleState.hero),
                        healthBarPlacement: .top,
                        battleState: battleState
                    ),
                    paneConfiguration(
                        for: battleState.pet,
                        health: battleState.health(of: battleState.pet),
                        healthBarPlacement: .top,
                        battleState: battleState
                    )
                ],
                reduceMotion: reduceMotion,
                onCombatantTap: showDetails(for:)
            )
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
    }

    private func paneConfiguration(
        for combatant: Combatant,
        health: Int,
        healthBarPlacement: BattleCombatantPane.HealthBarPlacement,
        battleState: BattleState
    ) -> BattleCombatantPaneConfiguration {
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
        return BattleCombatantPaneConfiguration(
            combatant: combatant,
            health: health,
            maxHealth: battleState.maxHealth(of: combatant),
            mana: mana,
            maxMana: maxMana,
            healthBarPlacement: healthBarPlacement,
            events: feedbackEvents(for: combatant)
        )
    }

    private func showDetails(for combatant: Combatant) {
        let battleState = battleRun.state
        appState.battle.presentCombatantDetail(details(
            for: combatant,
            health: battleState.health(of: combatant),
            activeEffectSummaries: battleState.effectSummaries(of: combatant)
        ))
    }

    private func feedbackEvents(for combatant: Combatant) -> [ActionEvent] {
        battleRun.activeFeedbackEvents.filter { $0.targetID == combatant.id }
    }

    private var canAutoAdvanceBattle: Bool {
        !battleRun.state.isBattleOver &&
            !isShowingVictory &&
            !isShowingDefeat &&
            !appState.battle.isPaused
    }

    private func advanceBattleTick() {
        guard canAutoAdvanceBattle else { return }

        battleRun.advanceOneStep()

        switch battleRun.outcome {
        case .victory:
            if stageRewardsAlreadyClaimed {
                appState.completeActiveBattle(configuration, battleEarnedGold: battleRun.state.earnedGold)
            } else {
                victorySummary = battleRun.makeVictorySummary(homestead: appState.homestead.current)
                isShowingVictory = true
            }
        case .defeat:
            isShowingDefeat = true
        case .ongoing:
            break
        }
    }

    private func details(
        for combatant: Combatant,
        health: Int,
        activeEffectSummaries: [EffectSummary]
    ) -> CombatantCardDetail {
        CombatantCardDetail(
            combatant: combatant,
            progression: configuration.progression(for: combatant),
            equipmentLoadout: configuration.equipmentLoadout(for: combatant),
            inventoryState: configuration.inventoryState,
            health: health,
            activeEffectSummaries: activeEffectSummaries
        )
    }
}
