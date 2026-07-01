import SwiftUI

struct BattleView: View {
    @State private var battle: BattleState
    @State private var isShowingBattleLog = false
    @State private var isShowingVictory = false
    @State private var isShowingDefeat = false
    @State private var timelineStartDate: Date
    @State private var activeFeedbackEvents: [BattleState.ActionEvent] = []
    @Binding var isBattlePaused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let heroProgression: CombatantProgression
    private let petProgression: CombatantProgression
    private let heroEquipmentLoadout: EquipmentLoadout
    private let petEquipmentLoadout: EquipmentLoadout
    private let inventoryState: PlayerInventoryState
    private let stageReward: StageReward?
    private let rewardItemNames: [String]
    private let onEndBattle: () -> Void
    private let onRestartBattle: () -> Void
    private let onVictoryContinue: ((Int) -> Void)?
    private let onShowCombatantDetail: (CombatantCardDetail) -> Void

    @State private var victorySummary: BattleVictorySummary?

    init(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant? = nil,
        heroProgression: CombatantProgression = .initial,
        petProgression: CombatantProgression = .initial,
        heroEquipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
        petEquipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
        inventoryState: PlayerInventoryState = .initial,
        stageReward: StageReward? = nil,
        rewardItemNames: [String] = [],
        isBattlePaused: Binding<Bool>,
        onEndBattle: @escaping () -> Void,
        onRestartBattle: @escaping () -> Void,
        onVictoryContinue: ((Int) -> Void)? = nil,
        onShowCombatantDetail: @escaping (CombatantCardDetail) -> Void
    ) {
        self.heroProgression = heroProgression
        self.petProgression = petProgression
        self.heroEquipmentLoadout = heroEquipmentLoadout
        self.petEquipmentLoadout = petEquipmentLoadout
        self.inventoryState = inventoryState
        self.stageReward = stageReward
        self.rewardItemNames = rewardItemNames
        self.onEndBattle = onEndBattle
        self.onRestartBattle = onRestartBattle
        self.onVictoryContinue = onVictoryContinue
        self.onShowCombatantDetail = onShowCombatantDetail
        _battle = State(initialValue: BattleState(hero: hero, pet: pet, enemy: enemy))
        _isBattlePaused = isBattlePaused
        _isShowingVictory = State(initialValue: false)
        _timelineStartDate = State(initialValue: Date())
    }

    var body: some View {
        Group {
            if isShowingVictory, let victorySummary {
                VictoryView(
                    enemyName: battle.enemy.name,
                    summary: victorySummary,
                    primaryActionTitle: onVictoryContinue == nil ? "Battle Again" : "Continue",
                    onPrimaryAction: {
                        if let onVictoryContinue {
                            onVictoryContinue(victorySummary.battleGold)
                        } else {
                            onRestartBattle()
                        }
                    }
                )
            } else if isShowingDefeat {
                DefeatView(
                    enemyName: battle.enemy.name,
                    onBattleAgain: onRestartBattle
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
                            isBattlePaused.toggle()
                        } label: {
                            Image(systemName: isBattlePaused ? "play.fill" : "pause.fill")
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
                    onEndBattle()
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
        VStack(spacing: 0) {
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
            .frame(maxHeight: .infinity)

            HStack(spacing: 0) {
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
            }
            .frame(maxHeight: .infinity)
        }
        .ignoresSafeArea(edges: .top)
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

        onShowCombatantDetail(details(
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

    private func feedbackEvents(for combatant: Combatant) -> [BattleState.ActionEvent] {
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
            !isBattlePaused
    }

    private func advanceBattleTick() {
        guard canAutoAdvanceBattle else { return }

        let step = battle.advanceOneStep()
        step.events.forEach(appendFeedbackEvent)

        if battle.isEnemyDefeated {
            victorySummary = makeVictorySummary()
            isShowingVictory = true
        } else if battle.isPartyDefeated {
            isShowingDefeat = true
        }
    }

    private func appendFeedbackEvent(_ event: BattleState.ActionEvent) {
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
            inventoryState: inventoryState,
            health: health,
            activeEffectSummaries: activeEffectSummaries
        )
    }

    private func progression(for combatant: Combatant) -> CombatantProgression {
        if combatant.id == battle.hero.id { return heroProgression }
        if combatant.id == battle.pet.id { return petProgression }
        return .initial
    }

    private func equipmentLoadout(for combatant: Combatant) -> EquipmentLoadout {
        if combatant.id == battle.hero.id { return heroEquipmentLoadout }
        if combatant.id == battle.pet.id { return petEquipmentLoadout }
        return EquipmentLoadout()
    }

    private func makeVictorySummary() -> BattleVictorySummary {
        let xpAwarded = stageReward?.experience ?? 0
        let heroAfter = heroProgression.addingExperience(xpAwarded)
        let petAfter = petProgression.addingExperience(xpAwarded)

        return BattleVictorySummary(
            stageGold: stageReward?.gold ?? 0,
            battleGold: battle.earnedGold,
            experience: xpAwarded,
            heroName: battle.hero.name,
            petName: battle.pet.name,
            itemNames: rewardItemNames,
            heroProgressionBefore: heroProgression,
            heroProgressionAfter: heroAfter,
            petProgressionBefore: petProgression,
            petProgressionAfter: petAfter
        )
    }
}
