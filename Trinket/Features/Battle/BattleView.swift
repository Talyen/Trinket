import SwiftUI

struct BattleView: View {
    @State private var battle: BattleState
    @State private var isShowingBattleLog = false
    @State private var isShowingVictory = false
    @State private var isShowingOptions = false
    @State private var activeFeedbackEvents: [BattleState.ActionEvent] = []
    @Binding var isBattlePaused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let heroProgression: CombatantProgression
    private let petProgression: CombatantProgression
    private let heroEquipmentLoadout: EquipmentLoadout
    private let petEquipmentLoadout: EquipmentLoadout
    private let inventoryState: PlayerInventoryState
    private let onEndBattle: () -> Void
    private let onShowCombatantDetail: (CombatantCardDetail) -> Void
    private let feedbackLifetime: TimeInterval = 1.0
    private let maximumVisibleFeedbackEvents = 2

    init(
        hero: Combatant,
        pet: Combatant,
        initialBattle: BattleState? = nil,
        heroProgression: CombatantProgression = .initial,
        petProgression: CombatantProgression = .initial,
        heroEquipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
        petEquipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
        inventoryState: PlayerInventoryState = .initial,
        isBattlePaused: Binding<Bool>,
        onEndBattle: @escaping () -> Void,
        onShowCombatantDetail: @escaping (CombatantCardDetail) -> Void
    ) {
        self.heroProgression = heroProgression
        self.petProgression = petProgression
        self.heroEquipmentLoadout = heroEquipmentLoadout
        self.petEquipmentLoadout = petEquipmentLoadout
        self.inventoryState = inventoryState
        self.onEndBattle = onEndBattle
        self.onShowCombatantDetail = onShowCombatantDetail
        let initialState = initialBattle ?? BattleState(hero: hero, pet: pet)
        _battle = State(initialValue: initialState)
        _isBattlePaused = isBattlePaused
        _isShowingVictory = State(initialValue: initialState.isEnemyDefeated)
    }

    var body: some View {
        Group {
            if isShowingVictory {
                VictoryView(
                    enemyName: battle.enemy.name,
                    onBattleAgain: restartBattle
                )
            } else {
                battlefieldWithTimeline
            }
        }
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle(isShowingVictory ? "Victory" : "Battle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    if !isShowingVictory {
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
        .sheet(isPresented: $isShowingOptions) {
            NavigationStack {
                OptionsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                isShowingOptions = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var battlefieldWithTimeline: some View {
        TimelineView(.periodic(from: .now, by: 0.8)) { context in
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

            Button {
                isShowingOptions = true
            } label: {
                Label("Options", systemImage: "gearshape")
            }
            .accessibilityIdentifier("Options menu item")

            if !isShowingVictory {
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
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let spacing: CGFloat = 18
            let enemyWidth = availableWidth * 0.40
            let partyWidth = (availableWidth - spacing) * 0.45

            VStack(spacing: spacing) {
                ZStack(alignment: .top) {
                    CombatantStatusCard(
                        combatant: battle.enemy,
                        health: battle.enemyHealth,
                        maxHealth: battle.enemy.maxHealth,
                        prominence: .enemy,
                        cardWidth: enemyWidth,
                        showsText: false,
                        isPaused: isBattlePaused
                    ) {
                        onShowCombatantDetail(details(
                            for: battle.enemy,
                            health: battle.enemyHealth,
                            activeStatusSummaries: battle.enemyStatusSummaries
                        ))
                    }

                    CombatFeedbackOverlay(
                        events: activeFeedbackEvents,
                        reduceMotion: reduceMotion,
                        onRemoveEvent: { id in
                            activeFeedbackEvents.removeAll { $0.id == id }
                        }
                    )
                    .padding(.top, 10)
                }

                HStack(alignment: .top, spacing: spacing) {
                    CombatantStatusCard(
                        combatant: battle.hero,
                        health: battle.hero.maxHealth,
                        maxHealth: battle.hero.maxHealth,
                        prominence: .party,
                        cardWidth: partyWidth,
                        showsText: false,
                        isPaused: isBattlePaused
                    ) {
                        onShowCombatantDetail(details(
                            for: battle.hero,
                            health: battle.hero.maxHealth,
                            activeStatusSummaries: []
                        ))
                    }

                    CombatantStatusCard(
                        combatant: battle.pet,
                        health: battle.pet.maxHealth,
                        maxHealth: battle.pet.maxHealth,
                        prominence: .party,
                        cardWidth: partyWidth,
                        showsText: false,
                        isPaused: isBattlePaused
                    ) {
                        onShowCombatantDetail(details(
                            for: battle.pet,
                            health: battle.pet.maxHealth,
                            activeStatusSummaries: []
                        ))
                    }
                }
            }
            .padding(20)
        }
    }

    private var canAutoAdvanceBattle: Bool {
        !isShowingBattleLog &&
            !battle.isEnemyDefeated &&
            !isShowingVictory &&
            !isBattlePaused
    }

    private func advanceBattleTick() {
        guard canAutoAdvanceBattle else { return }

        let events = battle.performNextAction()
        events.forEach(appendFeedbackEvent)

        if battle.isEnemyDefeated {
            isShowingVictory = true
        }
    }

    private func appendFeedbackEvent(_ event: BattleState.ActionEvent) {
        activeFeedbackEvents.append(event)
        activeFeedbackEvents = Array(activeFeedbackEvents.suffix(maximumVisibleFeedbackEvents))
    }

    private func restartBattle() {
        battle = BattleState(hero: battle.hero, pet: battle.pet, enemy: battle.enemy)
        activeFeedbackEvents = []
        isShowingBattleLog = false
        isShowingVictory = false
        isBattlePaused = false
    }

    private func details(
        for combatant: Combatant,
        health: Int,
        activeStatusSummaries: [StatusSummary]
    ) -> CombatantCardDetail {
        CombatantCardDetail(
            combatant: combatant,
            progression: progression(for: combatant),
            equipmentLoadout: equipmentLoadout(for: combatant),
            inventoryState: inventoryState,
            health: health,
            activeStatusSummaries: activeStatusSummaries
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
}
