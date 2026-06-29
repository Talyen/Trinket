import SwiftUI

private extension View {
    func trinketFloatingGlassControl() -> some View {
        modifier(TrinketDesign.FloatingGlassControlButtonModifier())
    }

    func trinketFloatingGlassToggle() -> some View {
        modifier(TrinketDesign.FloatingGlassToggleModifier())
    }

    func trinketCardSurface() -> some View {
        modifier(TrinketDesign.CardSurfaceModifier())
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab
    @State private var activeBattle: ActiveBattleConfiguration?
    @State private var rosterState = PlayerRosterState.initial
    @State private var inventoryState = PlayerInventoryState.initial
    @State private var isBattlePaused = false
    @AppStorage("options.theme") private var theme = TrinketDesign.AppTheme.system

    init() {
        _selectedTab = State(initialValue: AppTab.launchDefault)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.play.displayName, systemImage: AppTab.play.symbolName, value: AppTab.play) {
                PlayView(
                    rosterState: $rosterState,
                    inventoryState: $inventoryState,
                    activeBattle: $activeBattle,
                    isBattlePaused: $isBattlePaused
                )
            }

            Tab(AppTab.collection.displayName, systemImage: AppTab.collection.symbolName, value: AppTab.collection) {
                NavigationStack {
                    CollectionView(
                        rosterState: $rosterState,
                        inventoryState: $inventoryState
                    )
                }
            }

            Tab(AppTab.homestead.displayName, systemImage: AppTab.homestead.symbolName, value: AppTab.homestead) {
                NavigationStack {
                    PlaceholderTabView(title: "Homestead")
                }
            }

            Tab(value: AppTab.search, role: .search) {
                NavigationStack {
                    SearchView(
                        rosterState: $rosterState,
                        inventoryState: $inventoryState
                    )
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
        .onChange(of: selectedTab) { _, newTab in
            guard activeBattle != nil else { return }
            isBattlePaused = newTab != .play
        }
        .onChange(of: activeBattle?.id) { _, newValue in
            guard newValue != nil else {
                isBattlePaused = false
                return
            }

            isBattlePaused = selectedTab != .play
        }
    }
}

private struct ActiveBattleConfiguration: Identifiable {
    let id = UUID()
    let hero: Combatant
    let pet: Combatant
    let heroProgression: CombatantProgression
    let petProgression: CombatantProgression
    let heroEquipmentLoadout: EquipmentLoadout
    let petEquipmentLoadout: EquipmentLoadout
    let inventoryState: PlayerInventoryState
    let debugConfiguration: BattleDebugConfiguration

    init(
        hero: Combatant,
        pet: Combatant,
        heroProgression: CombatantProgression = .initial,
        petProgression: CombatantProgression = .initial,
        heroEquipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
        petEquipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
        inventoryState: PlayerInventoryState = .initial,
        debugConfiguration: BattleDebugConfiguration = .disabled
    ) {
        self.hero = hero
        self.pet = pet
        self.heroProgression = heroProgression
        self.petProgression = petProgression
        self.heroEquipmentLoadout = heroEquipmentLoadout
        self.petEquipmentLoadout = petEquipmentLoadout
        self.inventoryState = inventoryState
        self.debugConfiguration = debugConfiguration
    }
}

private enum AppTab: String {
    case play
    case collection
    case homestead
    case search

    var symbolName: String {
        switch self {
        case .play: return "map.fill"
        case .collection: return "person.2.fill"
        case .homestead: return "house.fill"
        case .search: return "magnifyingglass"
        }
    }

    var displayName: String {
        switch self {
        case .play: return "Play"
        case .collection: return "Collection"
        case .homestead: return "Homestead"
        case .search: return "Search"
        }
    }

    static var launchDefault: AppTab {
        let arguments = ProcessInfo.processInfo.arguments
        guard
            let flagIndex = arguments.firstIndex(of: "-selectedTab"),
            arguments.indices.contains(flagIndex + 1),
            let tab = AppTab.fromLaunchArgument(arguments[flagIndex + 1])
        else {
            return .play
        }

        return tab
    }

    private static func fromLaunchArgument(_ argument: String) -> AppTab? {
        let normalized = argument.lowercased()
        if normalized == "heroes" || normalized == "pets" || normalized == "inventory" {
            return .collection
        }
        return AppTab(rawValue: normalized)
    }
}

private enum PlayRoute: Hashable {
    case heroSelection
    case petSelection(Combatant)
}

private struct PlayView: View {
    @Binding var rosterState: PlayerRosterState
    @Binding var inventoryState: PlayerInventoryState
    @Binding var activeBattle: ActiveBattleConfiguration?
    @Binding var isBattlePaused: Bool
    @State private var path: [PlayRoute] = []

    private let debugConfiguration = BattleDebugConfiguration.current

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationDestination(for: PlayRoute.self) { route in
                    switch route {
                    case .heroSelection:
                        HeroSelectionView(rosterState: $rosterState) { hero in
                            path.append(.petSelection(hero))
                        }
                    case .petSelection(let hero):
                        PetSelectionView(hero: hero, rosterState: $rosterState) { pet in
                            activeBattle = ActiveBattleConfiguration(
                                hero: hero,
                                pet: pet,
                                heroProgression: rosterState.progression(for: hero),
                                petProgression: rosterState.progression(for: pet),
                                heroEquipmentLoadout: rosterState.equipmentLoadout(for: hero),
                                petEquipmentLoadout: rosterState.equipmentLoadout(for: pet),
                                inventoryState: inventoryState
                            )
                            path.removeAll()
                        }
                    }
                }
        }
        .onAppear {
            guard debugConfiguration.isEnabled, activeBattle == nil else { return }
            activeBattle = ActiveBattleConfiguration(
                hero: debugConfiguration.hero,
                pet: debugConfiguration.pet,
                debugConfiguration: debugConfiguration
            )
        }
        .onChange(of: activeBattle?.id) { _, newValue in
            if newValue != nil {
                path.removeAll()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let activeBattle {
            BattleView(
                hero: activeBattle.hero,
                pet: activeBattle.pet,
                heroProgression: activeBattle.heroProgression,
                petProgression: activeBattle.petProgression,
                heroEquipmentLoadout: activeBattle.heroEquipmentLoadout,
                petEquipmentLoadout: activeBattle.petEquipmentLoadout,
                inventoryState: activeBattle.inventoryState,
                debugConfiguration: activeBattle.debugConfiguration,
                isBattlePaused: $isBattlePaused,
                onEndBattle: {
                    isBattlePaused = false
                    self.activeBattle = nil
                }
            )
            .id(activeBattle.id)
            .navigationBarBackButtonHidden(true)
        } else {
            playDashboard
        }
    }

    private var playDashboard: some View {
        List {
            Section {
                NavigationLink(value: PlayRoute.heroSelection) {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(GameMode.battle.rawValue)

                            Text(GameMode.battle.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "bolt.fill")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle("Play")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct HeroSelectionView: View {
    @Binding var rosterState: PlayerRosterState
    let onSelect: (Combatant) -> Void

    var body: some View {
        SelectionGridView(
            title: "Select Hero",
            combatants: rosterState.configuredCombatants(GameContent.heroes),
            onSelect: onSelect
        )
    }
}

private struct PetSelectionView: View {
    let hero: Combatant
    @Binding var rosterState: PlayerRosterState
    let onSelect: (Combatant) -> Void

    var body: some View {
        SelectionGridView(
            title: "Select Pet",
            combatants: rosterState.configuredCombatants(GameContent.pets),
            onSelect: onSelect
        )
    }
}

private struct SelectionGridView: View {
    let title: String
    let combatants: [Combatant]
    let onSelect: (Combatant) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(combatants) { combatant in
                        Button {
                            onSelect(combatant)
                        } label: {
                            CombatantCard(combatant: combatant)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("\(combatant.name) selection card")
                    }
                }
            }
            .padding(20)
        }
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct CombatantCardDetail: Identifiable {
    let combatant: Combatant
    let progression: CombatantProgression
    let equipmentLoadout: EquipmentLoadout
    let inventoryState: PlayerInventoryState
    let health: Int
    let activeStatusSummaries: [StatusSummary]

    var id: String { combatant.id }

    static func base(_ combatant: Combatant) -> CombatantCardDetail {
        CombatantCardDetail(
            combatant: combatant,
            progression: .initial,
            equipmentLoadout: EquipmentLoadout(),
            inventoryState: .initial,
            health: combatant.maxHealth,
            activeStatusSummaries: []
        )
    }
}

private struct BattleView: View {
    @State private var battle: BattleState
    @State private var selectedDetails: CombatantCardDetail?
    @State private var isShowingBattleLog = false
    @State private var isShowingVictory = false
    @State private var isShowingOptions = false
    @State private var activeFeedbackEvents: [BattleState.ActionEvent] = []
    @Binding var isBattlePaused: Bool
    @State private var isDebugPaused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let heroProgression: CombatantProgression
    private let petProgression: CombatantProgression
    private let heroEquipmentLoadout: EquipmentLoadout
    private let petEquipmentLoadout: EquipmentLoadout
    private let inventoryState: PlayerInventoryState
    private let debugConfiguration: BattleDebugConfiguration
    private let onEndBattle: () -> Void
    private let timer = Timer.publish(
        every: ProcessInfo.processInfo.arguments.contains("-disableAnimations") ? 0.25 : 0.8,
        on: .main,
        in: .common
    ).autoconnect()
    private let feedbackLifetime: TimeInterval = 1.15
    private let maximumVisibleFeedbackEvents = 2

    init(
        hero: Combatant,
        pet: Combatant,
        heroProgression: CombatantProgression = .initial,
        petProgression: CombatantProgression = .initial,
        heroEquipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
        petEquipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
        inventoryState: PlayerInventoryState = .initial,
        debugConfiguration: BattleDebugConfiguration = .disabled,
        isBattlePaused: Binding<Bool>,
        onEndBattle: @escaping () -> Void
    ) {
        self.heroProgression = heroProgression
        self.petProgression = petProgression
        self.heroEquipmentLoadout = heroEquipmentLoadout
        self.petEquipmentLoadout = petEquipmentLoadout
        self.inventoryState = inventoryState
        self.debugConfiguration = debugConfiguration
        self.onEndBattle = onEndBattle
        _battle = State(initialValue: BattleState(hero: hero, pet: pet))
        _isBattlePaused = isBattlePaused
        _isDebugPaused = State(initialValue: debugConfiguration.startsPaused)
    }

    var body: some View {
        Group {
            if isShowingVictory {
                VictoryView(
                    enemyName: battle.enemy.name,
                    onBattleAgain: restartBattle
                )
            } else {
                battlefield
            }
        }
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle(isShowingVictory ? "Victory" : "Battle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                battleActionsMenu
            }
        }
        .sheet(item: $selectedDetails) { details in
            NavigationStack {
                CombatantDetailPane(
                    combatant: details.combatant,
                    progression: details.progression,
                    loadout: .constant(details.combatant.abilityLoadout),
                    equipmentLoadout: .constant(details.equipmentLoadout),
                    inventoryState: .constant(details.inventoryState),
                    allowsEditing: false,
                    battleHealth: details.health,
                    activeStatusSummaries: details.activeStatusSummaries,
                    selectedItemSlot: .constant(nil),
                    showsDismissButton: false
                )
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
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
        .safeAreaInset(edge: .bottom) {
            if !isShowingVictory && debugConfiguration.isEnabled {
                BattleDebugOverlay(
                    tickCount: battle.tickCount,
                    enemyHealth: battle.enemyHealth,
                    enemyMaxHealth: battle.enemy.maxHealth,
                    statusSummary: debugStatusSummary,
                    isPaused: $isDebugPaused,
                    onStepTick: advanceBattleTick,
                    onReset: restartBattle,
                    onFinishBattle: finishBattle
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .onReceive(timer) { _ in
            guard canAutoAdvanceBattle else {
                return
            }

            advanceBattleTick()
        }
    }

    private var battleActionsMenu: some View {
        Menu {
            if !isShowingVictory {
                Toggle(isOn: $isBattlePaused) {
                    Label {
                        Text(isBattlePaused ? "Resume" : "Pause")
                    } icon: {
                        Image(systemName: isBattlePaused ? "play.fill" : "pause.fill")
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .accessibilityIdentifier("Battle Pause Toggle")
            }

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
        ScrollView {
            VStack(spacing: 18) {
                ZStack(alignment: .top) {
                    CombatantStatusCard(
                        combatant: battle.enemy,
                        health: battle.enemyHealth,
                        maxHealth: battle.enemy.maxHealth,
                        prominence: .enemy,
                        cardWidth: 210,
                        showsText: false,
                        isPaused: isBattlePaused
                    ) {
                        selectedDetails = details(
                            for: battle.enemy,
                            health: battle.enemyHealth,
                            activeStatusSummaries: battle.enemyStatusSummaries
                        )
                    }

                    CombatFeedbackOverlay(
                        events: activeFeedbackEvents,
                        reduceMotion: reduceMotion
                    )
                    .padding(.top, 10)
                }

                HStack(alignment: .top, spacing: 18) {
                    CombatantStatusCard(
                        combatant: battle.hero,
                        health: battle.hero.maxHealth,
                        maxHealth: battle.hero.maxHealth,
                        prominence: .party,
                        cardWidth: 150,
                        showsText: false,
                        isPaused: isBattlePaused
                    ) {
                        selectedDetails = details(
                            for: battle.hero,
                            health: battle.hero.maxHealth,
                            activeStatusSummaries: []
                        )
                    }

                    CombatantStatusCard(
                        combatant: battle.pet,
                        health: battle.pet.maxHealth,
                        maxHealth: battle.pet.maxHealth,
                        prominence: .party,
                        cardWidth: 150,
                        showsText: false,
                        isPaused: isBattlePaused
                    ) {
                        selectedDetails = details(
                            for: battle.pet,
                            health: battle.pet.maxHealth,
                            activeStatusSummaries: []
                        )
                    }
                }
            }
            .padding(20)
        }
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

    private var canAutoAdvanceBattle: Bool {
        selectedDetails == nil &&
            !isShowingBattleLog &&
            !battle.isEnemyDefeated &&
            !isShowingVictory &&
            !isBattlePaused &&
            !(debugConfiguration.isEnabled && isDebugPaused)
    }

    private var debugStatusSummary: String {
        let statusText = battle.enemyStatusSummaries.map(\.text).joined(separator: " ")
        return statusText.isEmpty ? "No active statuses" : statusText
    }

    private func advanceBattleTick() {
        guard !battle.isEnemyDefeated, !isShowingVictory else { return }

        let events = battle.performNextAction()
        events.forEach(appendFeedbackEvent)

        if battle.isEnemyDefeated {
            isShowingVictory = true
        }
    }

    private func finishBattle() {
        var safetyLimit = 100
        while !battle.isEnemyDefeated, safetyLimit > 0 {
            advanceBattleTick()
            safetyLimit -= 1
        }
    }

    private func appendFeedbackEvent(_ event: BattleState.ActionEvent) {
        activeFeedbackEvents.append(event)
        activeFeedbackEvents = Array(activeFeedbackEvents.suffix(maximumVisibleFeedbackEvents))

        DispatchQueue.main.asyncAfter(deadline: .now() + feedbackLifetime) {
            activeFeedbackEvents.removeAll { $0.id == event.id }
        }
    }

    private func restartBattle() {
        battle = BattleState(hero: battle.hero, pet: battle.pet, enemy: battle.enemy)
        activeFeedbackEvents = []
        selectedDetails = nil
        isShowingBattleLog = false
        isShowingVictory = false
        isBattlePaused = false
        isDebugPaused = debugConfiguration.startsPaused
    }
}

private struct BattleDebugOverlay: View {
    let tickCount: Int
    let enemyHealth: Int
    let enemyMaxHealth: Int
    let statusSummary: String
    @Binding var isPaused: Bool
    let onStepTick: () -> Void
    let onReset: () -> Void
    let onFinishBattle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Battle Debug", systemImage: "hammer.fill")
                    .font(.caption.bold())

                Spacer()

                Text(isPaused ? "Paused" : "Running")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isPaused ? TrinketDesign.Colors.caution : TrinketDesign.Colors.success)
                    .accessibilityIdentifier("Debug Pause State")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Debug Tick: \(tickCount)")
                    .accessibilityIdentifier("Debug Tick Count")
                Text("Debug Enemy HP: \(enemyHealth)/\(enemyMaxHealth)")
                    .accessibilityIdentifier("Debug Enemy HP")
                Text("Debug Status: \(statusSummary)")
                    .accessibilityIdentifier("Debug Status Summary")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()

            HStack(spacing: 8) {
                Button("Debug Step Tick", action: onStepTick)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("Debug Step Tick")

                Button(isPaused ? "Debug Resume" : "Debug Pause") {
                    isPaused.toggle()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("Debug Pause Toggle")
            }

            HStack(spacing: 8) {
                Button("Debug Reset", action: onReset)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("Debug Reset")

                Button("Debug Finish Battle", action: onFinishBattle)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("Debug Finish Battle")
            }
        }
        .font(.caption)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TrinketDesign.Materials.card, in: TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(.quaternary, lineWidth: 1)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}


private struct CollectionView: View {
    @Binding var rosterState: PlayerRosterState
    @Binding var inventoryState: PlayerInventoryState

    @State private var selectedItem: InventoryItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Heroes Section
                VStack(alignment: .leading, spacing: 12) {
                    NavigationLink {
                        HeroesGridView(
                            rosterState: $rosterState,
                            inventoryState: $inventoryState
                        )
                    } label: {
                        HStack(spacing: 6) {
                            Text("Heroes")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("Heroes collection category")

                    horizontalShelf {
                        ForEach(rosterState.configuredCombatants(GameContent.heroes)) { combatant in
                            NavigationLink {
                                CombatantCollectionDetailView(
                                    combatant: combatant,
                                    progression: rosterState.progression(for: combatant),
                                    loadout: loadoutBinding(for: combatant),
                                    equipmentLoadout: equipmentLoadoutBinding(for: combatant),
                                    inventoryState: $inventoryState
                                )
                            } label: {
                                CombatantCard(combatant: combatant)
                                    .frame(width: 130)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(combatant.name) collection card")
                        }
                    }
                }

                // Pets Section
                VStack(alignment: .leading, spacing: 12) {
                    NavigationLink {
                        PetsGridView(
                            rosterState: $rosterState,
                            inventoryState: $inventoryState
                        )
                    } label: {
                        HStack(spacing: 6) {
                            Text("Pets")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("Pets collection category")

                    horizontalShelf {
                        ForEach(rosterState.configuredCombatants(GameContent.pets)) { combatant in
                            NavigationLink {
                                CombatantCollectionDetailView(
                                    combatant: combatant,
                                    progression: rosterState.progression(for: combatant),
                                    loadout: loadoutBinding(for: combatant),
                                    equipmentLoadout: equipmentLoadoutBinding(for: combatant),
                                    inventoryState: $inventoryState
                                )
                            } label: {
                                CombatantCard(combatant: combatant)
                                    .frame(width: 130)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(combatant.name) collection card")
                        }
                    }
                }

                // Inventory Section
                VStack(alignment: .leading, spacing: 12) {
                    NavigationLink {
                        InventoryGridView(
                            inventoryState: $inventoryState
                        )
                    } label: {
                        HStack(spacing: 6) {
                            Text("Inventory")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("Inventory collection category")

                    horizontalShelf {
                        ForEach(inventoryState.items) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                ItemCard(item: item, showsAffixCount: false)
                                    .frame(width: 130)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(item.displayName) item card")
                        }
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle("Collection")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                ItemDetailView(item: item)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }

    private func horizontalShelf<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }

    private func loadoutBinding(for combatant: Combatant) -> Binding<AbilityLoadout> {
        Binding {
            rosterState.loadout(for: combatant)
        } set: { loadout in
            rosterState.setLoadout(loadout, for: combatant)
        }
    }

    private func equipmentLoadoutBinding(for combatant: Combatant) -> Binding<EquipmentLoadout> {
        Binding {
            rosterState.equipmentLoadout(for: combatant)
        } set: { loadout in
            rosterState.setEquipmentLoadout(loadout, for: combatant)
        }
    }
}


private struct HeroesGridView: View {
    @Binding var rosterState: PlayerRosterState
    @Binding var inventoryState: PlayerInventoryState

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(rosterState.configuredCombatants(GameContent.heroes)) { combatant in
                        NavigationLink {
                            CombatantCollectionDetailView(
                                combatant: combatant,
                                progression: rosterState.progression(for: combatant),
                                loadout: loadoutBinding(for: combatant),
                                equipmentLoadout: equipmentLoadoutBinding(for: combatant),
                                inventoryState: $inventoryState
                            )
                        } label: {
                            CombatantCard(combatant: combatant)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("\(combatant.name) collection card")
                    }
                }
            }
            .padding(20)
        }
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle("Heroes")
        .navigationBarTitleDisplayMode(.large)
    }

    private func loadoutBinding(for combatant: Combatant) -> Binding<AbilityLoadout> {
        Binding {
            rosterState.loadout(for: combatant)
        } set: { loadout in
            rosterState.setLoadout(loadout, for: combatant)
        }
    }

    private func equipmentLoadoutBinding(for combatant: Combatant) -> Binding<EquipmentLoadout> {
        Binding {
            rosterState.equipmentLoadout(for: combatant)
        } set: { loadout in
            rosterState.setEquipmentLoadout(loadout, for: combatant)
        }
    }
}

private struct PetsGridView: View {
    @Binding var rosterState: PlayerRosterState
    @Binding var inventoryState: PlayerInventoryState

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(rosterState.configuredCombatants(GameContent.pets)) { combatant in
                        NavigationLink {
                            CombatantCollectionDetailView(
                                combatant: combatant,
                                progression: rosterState.progression(for: combatant),
                                loadout: loadoutBinding(for: combatant),
                                equipmentLoadout: equipmentLoadoutBinding(for: combatant),
                                inventoryState: $inventoryState
                            )
                        } label: {
                            CombatantCard(combatant: combatant)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("\(combatant.name) collection card")
                    }
                }
            }
            .padding(20)
        }
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle("Pets")
        .navigationBarTitleDisplayMode(.large)
    }

    private func loadoutBinding(for combatant: Combatant) -> Binding<AbilityLoadout> {
        Binding {
            rosterState.loadout(for: combatant)
        } set: { loadout in
            rosterState.setLoadout(loadout, for: combatant)
        }
    }

    private func equipmentLoadoutBinding(for combatant: Combatant) -> Binding<EquipmentLoadout> {
        Binding {
            rosterState.equipmentLoadout(for: combatant)
        } set: { loadout in
            rosterState.setEquipmentLoadout(loadout, for: combatant)
        }
    }
}

private struct SearchView: View {
    @Binding var rosterState: PlayerRosterState
    @Binding var inventoryState: PlayerInventoryState
    @State private var searchText = ""
    @State private var selectedItem: InventoryItem?

    var body: some View {
        searchContent
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                ItemDetailView(item: item)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedQuery.isEmpty {
            ContentUnavailableView(
                "Heroes, Pets, and Items",
                systemImage: "magnifyingglass"
            )
        } else {
            let results = getSearchResults(for: trimmedQuery)

            if results.isEmpty {
                ContentUnavailableView(
                    "No Results Found",
                    systemImage: "questionmark.magnifyingglass",
                    description: Text("No match for \"\(searchText)\" .")
                )
            } else {
                List {
                    if !results.heroes.isEmpty {
                        SearchResultSection(title: "Heroes", items: results.heroes) { combatant in
                            NavigationLink {
                                CombatantCollectionDetailView(
                                    combatant: combatant,
                                    progression: rosterState.progression(for: combatant),
                                    loadout: loadoutBinding(for: combatant),
                                    equipmentLoadout: equipmentLoadoutBinding(for: combatant),
                                    inventoryState: $inventoryState
                                )
                            } label: {
                                CombatantCard(combatant: combatant)
                                    .frame(width: 130)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(combatant.name) collection card")
                        }
                    }

                    if !results.pets.isEmpty {
                        SearchResultSection(title: "Pets", items: results.pets) { combatant in
                            NavigationLink {
                                CombatantCollectionDetailView(
                                    combatant: combatant,
                                    progression: rosterState.progression(for: combatant),
                                    loadout: loadoutBinding(for: combatant),
                                    equipmentLoadout: equipmentLoadoutBinding(for: combatant),
                                    inventoryState: $inventoryState
                                )
                            } label: {
                                CombatantCard(combatant: combatant)
                                    .frame(width: 130)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(combatant.name) collection card")
                        }
                    }

                    if !results.items.isEmpty {
                        SearchResultSection(title: "Items", items: results.items) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                ItemCard(item: item, showsAffixCount: true)
                                    .frame(width: 130)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(item.displayName) item card")
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private struct SearchResults {
        let heroes: [Combatant]
        let pets: [Combatant]
        let items: [InventoryItem]
        
        var isEmpty: Bool {
            heroes.isEmpty && pets.isEmpty && items.isEmpty
        }
    }

    private func getSearchResults(for query: String) -> SearchResults {
        let matchingHeroes = rosterState.configuredCombatants(GameContent.heroes).filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
        let matchingPets = rosterState.configuredCombatants(GameContent.pets).filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
        let matchingItems = inventoryState.items.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) ||
            $0.baseType.name.localizedCaseInsensitiveContains(query)
        }

        return SearchResults(heroes: matchingHeroes, pets: matchingPets, items: matchingItems)
    }

    private func loadoutBinding(for combatant: Combatant) -> Binding<AbilityLoadout> {
        Binding {
            rosterState.loadout(for: combatant)
        } set: { loadout in
            rosterState.setLoadout(loadout, for: combatant)
        }
    }

    private func equipmentLoadoutBinding(for combatant: Combatant) -> Binding<EquipmentLoadout> {
        Binding {
            rosterState.equipmentLoadout(for: combatant)
        } set: { loadout in
            rosterState.setEquipmentLoadout(loadout, for: combatant)
        }
    }
}

private struct SearchResultSection<Item: Identifiable, Content: View>: View {
    let title: String
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        Section(title) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(items) { item in
                        content(item)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
        }
    }
}

private extension Combatant.Role {
    var fallbackArtSymbolName: String {
        switch self {
        case .hero:
            return "person.fill"
        case .pet:
            return "pawprint.fill"
        case .enemy:
            return "flame.fill"
        }
    }
}

private extension UnitPoint {
    var artAlignment: Alignment {
        let horizontal: HorizontalAlignment
        if x <= 0.34 {
            horizontal = .leading
        } else if x >= 0.66 {
            horizontal = .trailing
        } else {
            horizontal = .center
        }

        let vertical: VerticalAlignment
        if y <= 0.34 {
            vertical = .top
        } else if y >= 0.66 {
            vertical = .bottom
        } else {
            vertical = .center
        }

        return Alignment(horizontal: horizontal, vertical: vertical)
    }
}

private struct CombatantArtwork: View {
    let combatant: Combatant

    var body: some View {
        GeometryReader { geometry in
            if let artReference = combatant.artReference {
                Image(artReference.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height,
                        alignment: artReference.focalPoint.artAlignment
                    )
                    .clipped()
                    .accessibilityLabel(artReference.accessibilityLabel)
            } else {
                placeholderArt
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .accessibilityLabel("\(combatant.name) placeholder art")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var placeholderArt: some View {
        ZStack {
            LinearGradient(
                colors: [
                    TrinketDesign.Colors.cardArtAccent.opacity(0.18),
                    Color(.systemBackground).opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: combatant.role.fallbackArtSymbolName)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(TrinketDesign.Colors.cardArtAccent)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
        }
    }
}

private struct CombatantCard: View {
    let combatant: Combatant

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .fill(TrinketDesign.Materials.card)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    CombatantArtwork(combatant: combatant)
                        .clipShape(TrinketDesign.cardShape)
                }
                .overlay {
                    TrinketDesign.cardShape
                        .stroke(.quaternary, lineWidth: 1)
                }

            Text(combatant.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(combatant.name) card")
    }
}

private struct CombatantStatusCard: View {
    enum Prominence {
        case enemy
        case party
    }

    let combatant: Combatant
    let health: Int
    let maxHealth: Int
    let prominence: Prominence
    let cardWidth: CGFloat
    let showsText: Bool
    var isPaused: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                BattleArtCard(
                    combatant: combatant,
                    showsText: showsText,
                    isPaused: isPaused
                )
                .frame(width: cardWidth)

                CombatHealthBar(
                    health: health,
                    maxHealth: maxHealth,
                    fillColor: combatant.healthBarColor
                )
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(combatant.name) card")
            .accessibilityValue(healthText)
            .accessibilityHint("Shows details")
        }
        .buttonStyle(.plain)
        .frame(maxWidth: prominence == .enemy ? .infinity : cardWidth)
        .accessibilityIdentifier("\(combatant.name) card")
    }

    private var healthText: String {
        "\(health)/\(maxHealth) HP"
    }
}

private struct BattleArtCard: View {
    let combatant: Combatant
    let showsText: Bool
    var isPaused: Bool = false

    var body: some View {
        TrinketDesign.cardShape
            .fill(TrinketDesign.Materials.card)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                ZStack(alignment: .bottom) {
                    CombatantArtwork(combatant: combatant)
                        .clipShape(TrinketDesign.cardShape)

                    if showsText {
                        LinearGradient(
                            colors: [
                                .clear,
                                .black.opacity(0.72)
                            ],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .clipShape(TrinketDesign.cardShape)
                        .accessibilityHidden(true)

                        Text(combatant.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                            .padding(12)
                    }
                }
            }
            .overlay {
                TrinketDesign.cardShape
                    .stroke(.quaternary, lineWidth: 1)
            }
    }
}

private struct CombatHealthBar: View {
    let health: Int
    let maxHealth: Int
    let fillColor: Color

    @State private var displayedHealth: Double
    @State private var trailingHealth: Double
    @State private var restoreHealth: Double
    @State private var restoreOpacity = 0.0

    init(health: Int, maxHealth: Int, fillColor: Color) {
        self.health = health
        self.maxHealth = maxHealth
        self.fillColor = fillColor
        let initialHealth = Double(health)
        _displayedHealth = State(initialValue: initialHealth)
        _trailingHealth = State(initialValue: initialHealth)
        _restoreHealth = State(initialValue: initialHealth)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

                Capsule()
                    .fill(TrinketDesign.Colors.healthRestore)
                    .frame(width: width * restoreFraction)
                    .opacity(restoreOpacity)

                Capsule()
                    .fill(TrinketDesign.Colors.healthTrailingDamage)
                    .frame(width: width * trailingFraction)

                Capsule()
                    .fill(fillColor)
                    .frame(width: width * displayedFraction)
            }
        }
        .frame(height: 7)
        .clipShape(Capsule())
        .onChange(of: health) { oldValue, newValue in
            animateHealthChange(from: oldValue, to: newValue)
        }
    }

    private var displayedFraction: Double {
        healthFraction(displayedHealth)
    }

    private var trailingFraction: Double {
        healthFraction(trailingHealth)
    }

    private var restoreFraction: Double {
        healthFraction(restoreHealth)
    }

    private func healthFraction(_ value: Double) -> Double {
        guard maxHealth > 0 else { return 0 }
        return min(max(value / Double(maxHealth), 0), 1)
    }

    private func animateHealthChange(from oldValue: Int, to newValue: Int) {
        let newHealth = Double(newValue)

        if newValue < oldValue {
            withAnimation(.easeOut(duration: 0.18)) {
                displayedHealth = newHealth
            }

            withAnimation(.easeOut(duration: 0.42).delay(0.22)) {
                trailingHealth = newHealth
            }
        } else if newValue > oldValue {
            restoreHealth = newHealth
            withAnimation(.easeOut(duration: 0.22)) {
                displayedHealth = newHealth
                trailingHealth = newHealth
                restoreOpacity = 1
            }

            withAnimation(.easeIn(duration: 0.35).delay(0.28)) {
                restoreOpacity = 0
            }
        } else {
            displayedHealth = newHealth
            trailingHealth = newHealth
            restoreHealth = newHealth
        }
    }
}

private struct CombatFeedbackOverlay: View {
    let events: [BattleState.ActionEvent]
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                CombatFeedbackEventView(
                    event: event,
                    stackIndex: index,
                    reduceMotion: reduceMotion
                )
            }
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CombatFeedbackEventView: View {
    let event: BattleState.ActionEvent
    let stackIndex: Int
    let reduceMotion: Bool

    var body: some View {
        if reduceMotion {
                feedbackLabel
                    .opacity(0.95)
                    .transition(.opacity)
                    .offset(y: CGFloat(stackIndex) * 52)
        } else {
            KeyframeAnimator(
                initialValue: CombatFeedbackAnimationState(),
                trigger: event.id
            ) { state in
                feedbackLabel
                    .scaleEffect(state.scale)
                    .opacity(state.opacity)
                    .offset(y: state.verticalOffset + CGFloat(stackIndex) * 52)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1.1, duration: 0.16)
                    CubicKeyframe(1.0, duration: 0.24)
                    CubicKeyframe(0.98, duration: 0.55)
                }

                KeyframeTrack(\.opacity) {
                    CubicKeyframe(1.0, duration: 0.18)
                    CubicKeyframe(1.0, duration: 0.52)
                    CubicKeyframe(0.0, duration: 0.25)
                }

                KeyframeTrack(\.verticalOffset) {
                    CubicKeyframe(-8, duration: 0.16)
                    CubicKeyframe(-34, duration: 0.58)
                    CubicKeyframe(-48, duration: 0.21)
                }
            }
        }
    }

    private var feedbackLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: event.keyword.visualStyle.symbolName)
                .font(.caption.bold())

            Text(event.floatingText)
                .font(.headline)
                .monospacedDigit()
        }
        .foregroundStyle(event.keyword.visualStyle.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // UIStyleCheck: allow combat feedback uses a transient material capsule over battle art.
        .background(TrinketDesign.Materials.feedback, in: Capsule())
        .overlay {
            Capsule()
                .stroke(event.keyword.visualStyle.feedbackStroke, lineWidth: 1)
        }
        .shadow(color: event.keyword.visualStyle.feedbackShadow, radius: 10, y: 5)
    }
}

private struct CombatFeedbackAnimationState {
    var opacity = 1.0
    var scale = 1.0
    var verticalOffset = 0.0
}

private extension AbilityTier {
    var symbolName: String {
        switch self {
        case .basic:
            return "circle.fill"
        case .skill:
            return "sparkles"
        case .ultimate:
            return "star.fill"
        }
    }

    var cadenceLabel: String {
        switch self {
        case .basic:
            return "Every turn"
        case .skill:
            return "Every 3 turns"
        case .ultimate:
            return "Every 6 turns"
        }
    }
}

private struct CombatantCollectionDetailView: View {
    let combatant: Combatant
    let progression: CombatantProgression
    @Binding var loadout: AbilityLoadout
    @Binding var equipmentLoadout: EquipmentLoadout
    @Binding var inventoryState: PlayerInventoryState
    @State private var selectedItemSlot: ItemSlot?

    var body: some View {
        CombatantDetailPane(
            combatant: combatant,
            progression: progression,
            loadout: $loadout,
            equipmentLoadout: $equipmentLoadout,
            inventoryState: $inventoryState,
            allowsEditing: true,
            selectedItemSlot: $selectedItemSlot
        )
        .sheet(item: $selectedItemSlot) { slot in
            NavigationStack {
                ItemSlotPickerView(
                    slot: slot,
                    equipmentLoadout: $equipmentLoadout,
                    inventoryState: $inventoryState
                )
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct CombatantDetailPane: View {
    let combatant: Combatant
    let progression: CombatantProgression
    @Binding var loadout: AbilityLoadout
    @Binding var equipmentLoadout: EquipmentLoadout
    @Binding var inventoryState: PlayerInventoryState
    let allowsEditing: Bool
    var battleHealth: Int?
    var activeStatusSummaries: [StatusSummary] = []
    @Binding var selectedItemSlot: ItemSlot?
    var showsDismissButton: Bool = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            List {
                CombatantHeroHeader(
                    combatant: combatant,
                    progression: progression,
                    battleHealth: battleHealth
                )
                .frame(width: geometry.size.width, height: geometry.size.width * 4.0 / 3.0)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listSectionMargins(.horizontal, 0)
                .listSectionMargins(.top, 0)
                .accessibilityIdentifier("\(combatant.name) detail hero header")

                Section("Experience") {
                    ExperienceProgressDetail(progression: progression)
                }

                if let battleHealth {
                    Section("Health") {
                        CombatantHealthDetail(
                            health: battleHealth,
                            maxHealth: combatant.maxHealth,
                            fillColor: combatant.healthBarColor
                        )
                    }
                }

                if !activeStatusSummaries.isEmpty {
                    Section("Active Effects") {
                        ForEach(activeStatusSummaries) { summary in
                            KeywordDescriptionText(text: summary.text)
                                .font(.subheadline)
                                .accessibilityElement(children: .combine)
                        }
                    }
                }

                Section("Stats") {
                    HStack {
                        Text("Health")

                        Spacer()

                        Text("\(combatant.maxHealth) HP")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Section("Abilities") {
                    AbilitySummaryGrid(
                        combatant: combatant,
                        loadout: $loadout,
                        allowsEditing: allowsEditing
                    )
                    .padding(.vertical, 4)
                }

                Section("Items") {
                    EquipmentSlotSummaryGrid(
                        equipmentLoadout: equipmentLoadout,
                        inventoryState: inventoryState,
                        onSelect: allowsEditing ? { selectedItemSlot = $0 } : nil
                    )
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 0, for: .scrollContent)
            .ignoresSafeArea(showsDismissButton ? [] : .container, edges: .top)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TrinketDesign.Colors.appBackground)
        .tint(.white)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

private struct CombatantHeroHeader: View {
    let combatant: Combatant
    let progression: CombatantProgression
    let battleHealth: Int?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                CombatantArtwork(combatant: combatant)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.78)
                    ],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Text(combatant.role.rawValue.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.78))

                    Text(combatant.name)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    HStack(spacing: 12) {
                        Text("Level \(progression.level)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))

                        Text("\(currentHealth)/\(combatant.maxHealth) HP")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(combatant.name), \(combatant.role.rawValue), level \(progression.level), \(currentHealth) of \(combatant.maxHealth) health")
    }

    private var currentHealth: Int {
        battleHealth ?? combatant.maxHealth
    }
}

private struct ExperienceProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

                Capsule()
                    .fill(TrinketDesign.Colors.progression)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 6)
        .clipShape(Capsule())
    }
}

private struct ExperienceProgressDetail: View {
    let progression: CombatantProgression

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(progression.currentXP)/\(progression.requiredXP) XP")
                    .font(.footnote.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(progression.progressFraction * 100))%")
                    .font(.footnote.monospacedDigit().weight(.bold))
                    .foregroundStyle(TrinketDesign.Colors.progression)
            }

            ExperienceProgressBar(progress: progression.progressFraction)
                .frame(height: 6)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }
}

private struct AbilitySummaryGrid: View {
    let combatant: Combatant
    @Binding var loadout: AbilityLoadout
    let allowsEditing: Bool
    @State private var selectedAbilityTier: AbilityTier?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(AbilityTier.allCases) { tier in
                    if allowsEditing {
                        Button {
                            selectedAbilityTier = tier
                        } label: {
                            abilitySlot(for: tier)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("\(tier.rawValue) ability slot")
                        .accessibilityHint("Shows \(tier.rawValue) ability choices.")
                    } else {
                        abilitySlot(for: tier)
                            .accessibilityIdentifier("\(tier.rawValue) ability slot")
                            .accessibilityHint("Shows selected \(tier.rawValue) ability.")
                    }
                }
            }
        }
        .sheet(item: $selectedAbilityTier) { tier in
            NavigationStack {
                AbilityTierPickerSheet(
                    combatant: combatant,
                    tier: tier,
                    loadout: $loadout
                )
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func abilitySlot(for tier: AbilityTier) -> some View {
        Group {
            if let ability = selectedAbility(for: tier) {
                AbilityChoiceCard(ability: ability)
            } else {
                EmptyAbilitySlotCard(tier: tier)
            }
        }
    }

    private func selectedAbility(for tier: AbilityTier) -> Ability? {
        if let selected = loadout.ability(for: tier) {
            return selected
        }

        return combatant.abilityChoices.abilities(for: tier).first
    }
}

private struct EquipmentSlotSummaryGrid: View {
    let equipmentLoadout: EquipmentLoadout
    let inventoryState: PlayerInventoryState
    let onSelect: ((ItemSlot) -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(ItemSlot.allCases) { slot in
                if let onSelect {
                    Button {
                        onSelect(slot)
                    } label: {
                        itemSlot(for: slot)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(slot.rawValue) item slot")
                    .accessibilityHint("Shows \(slot.rawValue) items.")
                } else {
                    itemSlot(for: slot)
                        .accessibilityIdentifier("\(slot.rawValue) item slot")
                        .accessibilityHint("Shows equipped \(slot.rawValue) item.")
                }
            }
        }
    }

    private func itemSlot(for slot: ItemSlot) -> some View {
        Group {
            if let item = inventoryState.item(matching: equipmentLoadout.itemID(for: slot)) {
                ItemCard(item: item, showsAffixCount: false)
            } else {
                EmptyItemSlotCard(slot: slot)
            }
        }
    }
}



private struct AbilityTierPickerSheet: View {
    let combatant: Combatant
    let tier: AbilityTier
    @Binding var loadout: AbilityLoadout
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAbilityID: String? = nil

    private var abilities: [Ability] {
        combatant.abilityChoices.abilities(for: tier)
    }

    var body: some View {
        List {
            Section {
                ForEach(abilities) { ability in
                    Button {
                        selectedAbilityID = ability.id
                        loadout = loadout.selecting(ability)
                        dismiss()
                    } label: {
                        let isSelected = ability.id == (selectedAbilityID ?? selectedAbility?.id)
                        HStack(spacing: 14) {
                            AbilityChoiceCard(ability: ability)
                            .frame(height: 133)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ability.name)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                
                                KeywordDescriptionText(text: ability.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                            
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(TrinketDesign.Colors.selection)
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(TrinketDesign.Colors.groupedSurface)
                    .accessibilityIdentifier("\(tier.rawValue) \(ability.name) ability card")
                    .accessibilityValue(ability.id == (selectedAbilityID ?? selectedAbility?.id) ? "Selected" : "Available")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .sensoryFeedback(.selection, trigger: selectedAbilityID)
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle(tier.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var selectedAbility: Ability? {
        if let selected = loadout.ability(for: tier),
           let ability = abilities.first(where: { $0.id == selected.id }) {
            return ability
        }

        return abilities.first
    }
}

private struct ItemSlotPickerView: View {
    let slot: ItemSlot
    @Binding var equipmentLoadout: EquipmentLoadout
    @Binding var inventoryState: PlayerInventoryState
    @Environment(\.dismiss) private var dismiss
    @State private var itemOrder: [String] = []
    @State private var selectedItemID: String? = nil

    var body: some View {
        List {
            Section {
                ForEach(orderedItems) { item in
                    Button {
                        selectedItemID = item.id
                        equipmentLoadout.equip(item, in: slot)
                        dismiss()
                    } label: {
                        let isSelected = item.id == (selectedItemID ?? equipmentLoadout.itemID(for: slot))
                        HStack(spacing: 14) {
                            ItemCard(item: item, showsAffixCount: false)
                                .frame(height: 133)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.displayName)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)

                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(item.affixes.prefix(4)) { affix in
                                        Text(affix.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(TrinketDesign.Colors.selection)
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(TrinketDesign.Colors.groupedSurface)
                    .accessibilityIdentifier("Equip \(item.displayName)")
                    .accessibilityValue(equipmentLoadout.itemID(for: slot) == item.id ? "Equipped" : "Available")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .sensoryFeedback(.selection, trigger: selectedItemID)
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle("Equip \(slot.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if itemOrder.isEmpty {
                itemOrder = entrySortedItems.map(\.id)
            }
        }
    }

    private var orderedItems: [InventoryItem] {
        let items = inventoryState.items(for: slot)
        guard !itemOrder.isEmpty else { return entrySortedItems }

        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let ordered = itemOrder.compactMap { itemsByID[$0] }
        let orderedIDs = Set(itemOrder)
        let newItems = items.filter { !orderedIDs.contains($0.id) }
        return ordered + newItems
    }

    private var entrySortedItems: [InventoryItem] {
        let items = inventoryState.items(for: slot)
        guard
            let equippedID = equipmentLoadout.itemID(for: slot),
            let equippedItem = items.first(where: { $0.id == equippedID })
        else {
            return items
        }

        return [equippedItem] + items.filter { $0.id != equippedID }
    }
}

private enum InventoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case weapon = "Weapon"
    case armor = "Armor"
    case trinket = "Trinket"

    var id: String { rawValue }

    var slot: ItemSlot? {
        switch self {
        case .all:
            return nil
        case .weapon:
            return .weapon
        case .armor:
            return .armor
        case .trinket:
            return .trinket
        }
    }

}

private struct InventoryGridView: View {
    @Binding var inventoryState: PlayerInventoryState
    @State private var searchText = ""
    @State private var selectedFilter: InventoryFilter = .all
    @State private var selectedItem: InventoryItem?
 
    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredItems) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            ItemCard(item: item, showsAffixCount: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("\(item.displayName) item card")
                    }
                }
            }
            .padding(20)
        }
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search items")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(InventoryFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.body.weight(selectedFilter != .all ? .semibold : .regular))
                        .foregroundStyle(selectedFilter != .all ? TrinketDesign.Colors.cardArtAccent : .primary)
                }
                .accessibilityLabel("Filter")
                .accessibilityIdentifier("Inventory filter")
            }
        }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                ItemDetailView(item: item)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var filteredItems: [InventoryItem] {
        inventoryState.items.filter { item in
            let matchesSlot = selectedFilter.slot.map { $0 == item.baseType.slot } ?? true
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty
                || item.displayName.localizedCaseInsensitiveContains(query)
                || item.baseType.name.localizedCaseInsensitiveContains(query)
                || item.affixes.contains { affix in
                    affix.title.localizedCaseInsensitiveContains(query)
                        || affix.description.localizedCaseInsensitiveContains(query)
                }

            return matchesSlot && matchesSearch
        }
    }
}

private struct ItemDetailView: View {
    let item: InventoryItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    HStack {
                        Spacer()

                        ItemCard(item: item, showsAffixCount: false, showsName: false)
                            .frame(maxWidth: 220)

                        Spacer()
                    }

                    Text(item.displayName)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .listRowBackground(Color.clear)
            }

            Section("Affixes") {
                ForEach(item.affixes.prefix(4)) { affix in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(affix.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(affix.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle(item.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private struct CombatantHealthDetail: View {
    let health: Int
    let maxHealth: Int
    let fillColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CombatHealthBar(
                health: health,
                maxHealth: maxHealth,
                fillColor: fillColor
            )
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)

            Text("\(health)/\(maxHealth) HP")
                .font(.subheadline.monospacedDigit())
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AbilityChoiceCard: View {
    let ability: Ability

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .fill(TrinketDesign.Materials.card)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    LinearGradient(
                        colors: [
                            ability.damageKeyword.visualStyle.cardTint,
                            Color(.systemBackground).opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(TrinketDesign.cardShape)
                }
                .overlay {
                    Image(systemName: ability.damageKeyword.visualStyle.symbolName)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(ability.damageKeyword.visualStyle.color)
                        .accessibilityHidden(true)
                }
                .overlay {
                    TrinketDesign.cardShape
                        .stroke(.quaternary, lineWidth: 1)
                }

            Text(ability.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ability.name) card")
    }
}

private struct EmptyAbilitySlotCard: View {
    let tier: AbilityTier

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .fill(TrinketDesign.Materials.card)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    Image(systemName: tier.symbolName)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .overlay {
                    TrinketDesign.cardShape
                        .stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [5]))
                }

            Text("Empty \(tier.rawValue)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        }
        .accessibilityElement(children: .combine)
    }
}


private struct KeywordDescriptionText: View {
    let text: String

    var body: some View {
        composedText
    }

    private var composedText: Text {
        var result = Text("")
        var currentIndex = text.startIndex

        while currentIndex < text.endIndex {
            if let match = nextKeywordMatch(startingAt: currentIndex) {
                if currentIndex < match.range.lowerBound {
                    result = result + Text(String(text[currentIndex..<match.range.lowerBound]))
                        .foregroundColor(.secondary)
                }

                result = result + Text(match.keyword.rawValue)
                    .bold()
                    .foregroundColor(match.keyword.visualStyle.color)
                currentIndex = match.range.upperBound
            } else {
                result = result + Text(String(text[currentIndex..<text.endIndex]))
                    .foregroundColor(.secondary)
                break
            }
        }

        return result
    }

    private func nextKeywordMatch(startingAt startIndex: String.Index) -> (keyword: Keyword, range: Range<String.Index>)? {
        let searchRange = startIndex..<text.endIndex
        return Keyword.allCases
            .compactMap { keyword -> (Keyword, Range<String.Index>)? in
                guard let range = text.range(of: keyword.rawValue, range: searchRange) else {
                    return nil
                }
                return (keyword, range)
            }
            .min { left, right in
                left.1.lowerBound < right.1.lowerBound
            }
    }
}

private struct VictoryView: View {
    let enemyName: String
    let onBattleAgain: () -> Void

    @State private var bounceCount = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(TrinketDesign.Colors.success)
                    .accessibilityHidden(true)
                    .symbolEffect(.bounce, value: bounceCount)
                    .onAppear {
                        bounceCount += 1
                    }

                VStack(spacing: 8) {
                    Text("Victory")
                        .font(.largeTitle.bold())

                    Text("\(enemyName) is defeated.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VictoryPlaceholderSection(
                    title: "Experience",
                    message: "Hero and Pet experience will appear here later."
                )

                VictoryPlaceholderSection(
                    title: "Rewards",
                    message: "Items, Gold, materials, and unlocks are not implemented yet."
                )

                Button {
                    onBattleAgain()
                } label: {
                    Text("Battle Again")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct VictoryPlaceholderSection: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(TrinketDesign.Materials.card, in: TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}

private struct BattleLogSheet: View {
    @Environment(\.dismiss) private var dismiss

    let entries: [BattleState.LogEntry]

    var body: some View {
        NavigationStack {
            List {
                Section("Battle Log") {
                    ForEach(entries) { entry in
                        Text(entry.text)
                    }
                }
            }
            .navigationTitle("Combat Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct OptionsView: View {
    @AppStorage("options.musicVolume") private var musicVolume = 0.75
    @AppStorage("options.effectsVolume") private var effectsVolume = 0.85
    @AppStorage("options.hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("options.theme") private var theme = TrinketDesign.AppTheme.system

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $theme) {
                    ForEach(TrinketDesign.AppTheme.allCases) { themeOption in
                        Text(themeOption.rawValue).tag(themeOption)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("Theme Picker")
            }

            Section("Audio") {
                VolumeOptionRow(
                    title: "Music",
                    value: $musicVolume
                )

                VolumeOptionRow(
                    title: "Sound Effects",
                    value: $effectsVolume
                )

                Toggle(isOn: $hapticsEnabled) {
                    Label {
                        Text("Haptics")
                    } icon: {
                        Image(systemName: hapticsEnabled ? "iphone.radiowaves.left.and.right" : "iphone")
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .accessibilityIdentifier("Haptics Toggle")
            }

            Section("About") {
                LabeledContent("Version", value: appVersionText)
                LabeledContent("Build", value: appBuildText)
            }
        }
        .navigationTitle("Options")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("Options Screen")
    }

    private var appVersionText: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuildText: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

private struct VolumeOptionRow: View {
    let title: String
    @Binding var value: Double

    private var percentageText: String {
        "\(Int((value * 100).rounded()))%"
    }

    private var dynamicIconName: String {
        if title == "Music" {
            return value == 0 ? "music.note.slash" : "music.note"
        } else {
            if value == 0 {
                return "speaker.slash.fill"
            } else if value < 0.33 {
                return "speaker.wave.1.fill"
            } else if value < 0.66 {
                return "speaker.wave.2.fill"
            } else {
                return "speaker.wave.3.fill"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label {
                    Text(title)
                } icon: {
                    Image(systemName: dynamicIconName)
                        .contentTransition(.symbolEffect(.replace))
                }

                Spacer()

                Text(percentageText)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: $value, in: 0...1, step: 0.05)
                .accessibilityLabel(title)
                .accessibilityValue(percentageText)
        }
        .accessibilityIdentifier("\(title) Volume")
    }
}

private struct PlaceholderTabView: View {
    let title: String

    var body: some View {
        ZStack {
            TrinketDesign.Colors.appBackground
                .ignoresSafeArea()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct ItemCard: View {
    let item: InventoryItem
    var showsAffixCount: Bool
    var showsName: Bool = true

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .fill(TrinketDesign.Materials.card)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    LinearGradient(
                        colors: [
                            item.baseType.slot.visualStyle.accentColor.opacity(0.22),
                            Color(.systemBackground).opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(TrinketDesign.cardShape)
                }
                .overlay {
                    Image(systemName: item.baseType.symbolName)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(item.baseType.slot.visualStyle.accentColor)
                        .accessibilityHidden(true)
                }
                .overlay {
                    TrinketDesign.cardShape
                        .stroke(.quaternary, lineWidth: 1)
                }

            if showsName {
                Text(item.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayName), \(item.baseType.slot.rawValue)")
    }
}

private struct EmptyItemSlotCard: View {
    let slot: ItemSlot

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .fill(TrinketDesign.Materials.card)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    Image(systemName: slot.symbolName)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(slot.visualStyle.accentColor.opacity(0.6))
                        .accessibilityHidden(true)
                }
                .overlay {
                    TrinketDesign.cardShape
                        .stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [5]))
                }

            Text("Empty \(slot.rawValue)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Empty \(slot.rawValue) slot")
    }
}






