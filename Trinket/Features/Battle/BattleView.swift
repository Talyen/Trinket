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
        .sheet(isPresented: $isShowingBattleLog) {
            BattleLogSheet(
                entries: battleRun.log
            )
            .presentationDetents([.medium])
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
                .onChange(of: context.date) { _, _ in
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

            VStack(spacing: layout.cardSpacing) {
                BattleCombatantPane(
                    combatant: battleRun.enemy,
                    health: battleRun.enemyHealth,
                    maxHealth: battleRun.enemy.maxHealth,
                    healthBarPlacement: .bottom,
                    events: feedbackEvents(for: battleRun.enemy),
                    reduceMotion: reduceMotion,
                    onRemoveEvent: battleRun.removeFeedbackEvent
                ) {
                    showDetails(for: battleRun.enemy)
                }
                .frame(width: layout.enemySize.width, height: layout.enemySize.height)

                HStack(spacing: layout.cardSpacing) {
                    BattleCombatantPane(
                        combatant: battleRun.hero,
                        health: battleRun.heroHealth,
                        maxHealth: battleRun.hero.maxHealth,
                        healthBarPlacement: .top,
                        events: feedbackEvents(for: battleRun.hero),
                        reduceMotion: reduceMotion,
                        onRemoveEvent: battleRun.removeFeedbackEvent
                    ) {
                        showDetails(for: battleRun.hero)
                    }
                    .frame(width: layout.partySize.width, height: layout.partySize.height)

                    BattleCombatantPane(
                        combatant: battleRun.pet,
                        health: battleRun.petHealth,
                        maxHealth: battleRun.pet.maxHealth,
                        healthBarPlacement: .top,
                        events: feedbackEvents(for: battleRun.pet),
                        reduceMotion: reduceMotion,
                        onRemoveEvent: battleRun.removeFeedbackEvent
                    ) {
                        showDetails(for: battleRun.pet)
                    }
                    .frame(width: layout.partySize.width, height: layout.partySize.height)
                }
            }
            .padding(layout.outerPadding)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
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
        !isShowingBattleLog &&
            !battleRun.isBattleOver &&
            !isShowingVictory &&
            !isShowingDefeat &&
            !appState.battle.isPaused
    }

    private func advanceBattleTick() {
        guard canAutoAdvanceBattle else { return }

        battleRun.advanceOneStep()

        if battleRun.isEnemyDefeated {
            victorySummary = makeVictorySummary()
            isShowingVictory = true
        } else if battleRun.isPartyDefeated {
            isShowingDefeat = true
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

    private func makeVictorySummary() -> BattleVictorySummary {
        let xpAwarded = configuration.stageReward?.experience ?? 0
        let heroAfter = configuration.heroProgression.addingExperience(xpAwarded)
        let petAfter = configuration.petProgression.addingExperience(xpAwarded)

        return BattleVictorySummary(
            stageGold: configuration.stageReward?.gold ?? 0,
            battleGold: battleRun.earnedGold,
            experience: xpAwarded,
            heroName: battleRun.hero.name,
            petName: battleRun.pet.name,
            itemNames: configuration.rewardItemNames,
            heroProgressionBefore: configuration.heroProgression,
            heroProgressionAfter: heroAfter,
            petProgressionBefore: configuration.petProgression,
            petProgressionAfter: petAfter
        )
    }
}
