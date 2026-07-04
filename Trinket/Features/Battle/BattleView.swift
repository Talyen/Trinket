import SwiftUI

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

        Group {
            if isShowingVictory, let victorySummary {
                VictoryView(
                    enemyName: battleRun.enemy.name,
                    summary: victorySummary,
                    primaryActionTitle: hasStageProgression ? "Continue" : "Battle Again",
                    onPrimaryAction: {
                        if hasStageProgression {
                            appState.completeActiveBattle(configuration, battleEarnedGold: victorySummary.battleGold)
                        } else {
                            appState.battle.restartBattle(using: appState.roster)
                        }
                    }
                )
            } else if isShowingDefeat {
                DefeatView(
                    enemyName: battleRun.enemy.name,
                    onBattleAgain: {
                        appState.battle.restartBattle(using: appState.roster)
                    }
                )
            } else {
                battlefieldWithTimeline
            }
        }
        .background(TrinketDesign.Colors.appBackground)
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
        }) {
            BattleLogSheet(
                entries: battleRun.log
            )
            .presentationDetents([.medium])
        }
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
        GeometryReader { geometry in
            let layout = BattleCardGridLayout.metrics(in: geometry.size)

            BattlefieldView(
                layout: layout,
                enemyPane: paneConfiguration(
                    for: battleRun.enemy,
                    health: battleRun.enemyHealth,
                    healthBarPlacement: .bottom
                ),
                partyPanes: [
                    paneConfiguration(
                        for: battleRun.hero,
                        health: battleRun.heroHealth,
                        healthBarPlacement: .top
                    ),
                    paneConfiguration(
                        for: battleRun.pet,
                        health: battleRun.petHealth,
                        healthBarPlacement: .top
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
        healthBarPlacement: BattleCombatantPane.HealthBarPlacement
    ) -> BattleCombatantPaneConfiguration {
        let mana: Int
        let maxMana: Int
        if combatant.id == battleRun.hero.id {
            mana = battleRun.heroMana
            maxMana = battleRun.heroMaxMana
        } else if combatant.id == battleRun.pet.id {
            mana = battleRun.petMana
            maxMana = battleRun.petMaxMana
        } else {
            mana = 0
            maxMana = 0
        }
        return BattleCombatantPaneConfiguration(
            combatant: combatant,
            health: health,
            maxHealth: battleRun.maxHealth(for: combatant),
            mana: mana,
            maxMana: maxMana,
            healthBarPlacement: healthBarPlacement,
            events: feedbackEvents(for: combatant)
        )
    }

    private func showDetails(for combatant: Combatant) {
        appState.battle.presentCombatantDetail(details(
            for: combatant,
            health: battleRun.health(for: combatant),
            activeEffectSummaries: battleRun.effectSummaries(for: combatant)
        ))
    }

    private func feedbackEvents(for combatant: Combatant) -> [ActionEvent] {
        battleRun.activeFeedbackEvents.filter { $0.targetID == combatant.id }
    }

    private var canAutoAdvanceBattle: Bool {
        !battleRun.isBattleOver &&
            !isShowingVictory &&
            !isShowingDefeat &&
            !appState.battle.isPaused
    }

    private func advanceBattleTick() {
        guard canAutoAdvanceBattle else { return }

        battleRun.advanceOneStep()

        switch battleRun.outcome {
        case .victory:
            victorySummary = battleRun.makeVictorySummary(homestead: appState.homestead.current)
            isShowingVictory = true
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
            progression: progression(for: combatant),
            equipmentLoadout: equipmentLoadout(for: combatant),
            inventoryState: configuration.inventoryState,
            health: health,
            activeEffectSummaries: activeEffectSummaries
        )
    }

    private func progression(for combatant: Combatant) -> CombatantProgression {
        if combatant.id == battleRun.hero.id { return configuration.heroProgression }
        if combatant.id == battleRun.pet.id { return configuration.petProgression }
        return .initial
    }

    private func equipmentLoadout(for combatant: Combatant) -> EquipmentLoadout {
        if combatant.id == battleRun.hero.id { return configuration.heroEquipmentLoadout }
        if combatant.id == battleRun.pet.id { return configuration.petEquipmentLoadout }
        return EquipmentLoadout()
    }
}
