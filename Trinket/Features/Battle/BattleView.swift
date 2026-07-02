import SwiftUI

struct BattleView: View {
    @Environment(AppState.self) private var appState
    @State private var battle: BattleState
    @State private var isShowingBattleLog = false
    @State private var isShowingVictory = false
    @State private var isShowingDefeat = false
    @State private var timelineStartDate: Date
    @State private var activeFeedbackEvents: [ActionEvent] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let configuration: ActiveBattleConfiguration

    @State private var victorySummary: BattleVictorySummary?

    init(configuration: ActiveBattleConfiguration) {
        self.configuration = configuration
        _battle = State(initialValue: BattleState(
            hero: configuration.hero,
            pet: configuration.pet,
            enemy: configuration.enemy,
            heroModifiers: configuration.heroModifiers,
            petModifiers: configuration.petModifiers
        ))
        _isShowingVictory = State(initialValue: false)
        _timelineStartDate = State(initialValue: Date())
    }

    var body: some View {
        @Bindable var battleSession = appState.battle

        Group {
            if isShowingVictory, let victorySummary {
                VictoryView(
                    enemyName: battle.enemy.name,
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
                    enemyName: battle.enemy.name,
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
                entries: battle.log
            )
            .presentationDetents([.medium])
        }
    }

    private var hasStageProgression: Bool {
        configuration.stageID != nil
    }

    private var battlefieldWithTimeline: some View {
        TimelineView(.periodic(from: timelineStartDate, by: 0.8)) { context in
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
                    combatant: battle.enemy,
                    health: battle.enemyHealth,
                    maxHealth: battle.enemy.maxHealth,
                    healthBarPlacement: .bottom,
                    events: feedbackEvents(for: battle.enemy),
                    reduceMotion: reduceMotion,
                    onRemoveEvent: removeFeedbackEvent
                ) {
                    showDetails(for: battle.enemy)
                }
                .frame(width: layout.enemySize.width, height: layout.enemySize.height)

                HStack(spacing: layout.cardSpacing) {
                    BattleCombatantPane(
                        combatant: battle.hero,
                        health: battle.heroHealth,
                        maxHealth: battle.hero.maxHealth,
                        healthBarPlacement: .top,
                        events: feedbackEvents(for: battle.hero),
                        reduceMotion: reduceMotion,
                        onRemoveEvent: removeFeedbackEvent
                    ) {
                        showDetails(for: battle.hero)
                    }
                    .frame(width: layout.partySize.width, height: layout.partySize.height)

                    BattleCombatantPane(
                        combatant: battle.pet,
                        health: battle.petHealth,
                        maxHealth: battle.pet.maxHealth,
                        healthBarPlacement: .top,
                        events: feedbackEvents(for: battle.pet),
                        reduceMotion: reduceMotion,
                        onRemoveEvent: removeFeedbackEvent
                    ) {
                        showDetails(for: battle.pet)
                    }
                    .frame(width: layout.partySize.width, height: layout.partySize.height)
                }
            }
            .padding(layout.outerPadding)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
    }

    private func showDetails(for combatant: Combatant) {
        let health: Int
        if combatant.id == battle.enemy.id {
            health = battle.enemyHealth
        } else if combatant.id == battle.hero.id {
            health = battle.heroHealth
        } else {
            health = battle.petHealth
        }

        appState.battle.presentCombatantDetail(details(
            for: combatant,
            health: health,
            activeEffectSummaries: effectSummaries(for: combatant)
        ))
    }

    private func effectSummaries(for combatant: Combatant) -> [EffectSummary] {
        if combatant.id == battle.enemy.id { return battle.enemyEffectSummaries }
        if combatant.id == battle.hero.id { return battle.heroEffectSummaries }
        return battle.petEffectSummaries
    }

    private func feedbackEvents(for combatant: Combatant) -> [ActionEvent] {
        activeFeedbackEvents.filter { $0.targetID == combatant.id }
    }

    private func removeFeedbackEvent(_ id: Int) {
        activeFeedbackEvents.removeAll { $0.id == id }
    }

    private var canAutoAdvanceBattle: Bool {
        !isShowingBattleLog &&
            !battle.isBattleOver &&
            !isShowingVictory &&
            !isShowingDefeat &&
            !appState.battle.isPaused
    }

    private func advanceBattleTick() {
        guard canAutoAdvanceBattle else { return }

        let step = battle.advanceOneStep()
        step.events
            .filter { $0.kind != .milestone }
            .forEach(appendFeedbackEvent)

        if battle.isEnemyDefeated {
            victorySummary = makeVictorySummary()
            isShowingVictory = true
        } else if battle.isPartyDefeated {
            isShowingDefeat = true
        }
    }

    private func appendFeedbackEvent(_ event: ActionEvent) {
        activeFeedbackEvents.append(event)
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
        if combatant.id == battle.hero.id { return configuration.heroProgression }
        if combatant.id == battle.pet.id { return configuration.petProgression }
        return .initial
    }

    private func equipmentLoadout(for combatant: Combatant) -> EquipmentLoadout {
        if combatant.id == battle.hero.id { return configuration.heroEquipmentLoadout }
        if combatant.id == battle.pet.id { return configuration.petEquipmentLoadout }
        return EquipmentLoadout()
    }

    private func makeVictorySummary() -> BattleVictorySummary {
        let xpAwarded = configuration.stageReward?.experience ?? 0
        let heroAfter = configuration.heroProgression.addingExperience(xpAwarded)
        let petAfter = configuration.petProgression.addingExperience(xpAwarded)

        return BattleVictorySummary(
            stageGold: configuration.stageReward?.gold ?? 0,
            battleGold: battle.earnedGold,
            experience: xpAwarded,
            heroName: battle.hero.name,
            petName: battle.pet.name,
            itemNames: configuration.rewardItemNames,
            heroProgressionBefore: configuration.heroProgression,
            heroProgressionAfter: heroAfter,
            petProgressionBefore: configuration.petProgression,
            petProgressionAfter: petAfter
        )
    }
}
