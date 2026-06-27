import SwiftUI

private enum TrinketDesign {
    static let cardCornerRadius: CGFloat = 12

    static var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab
    @State private var rosterState = PlayerRosterState.initial
    @State private var inventoryState = PlayerInventoryState.initial

    init() {
        _selectedTab = State(initialValue: AppTab.launchDefault)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PlayView(rosterState: $rosterState)
            }
            .tabItem {
                Label("Play", systemImage: "play.fill")
            }
            .tag(AppTab.play)

            NavigationStack {
                HeroesCollectionView(
                    rosterState: $rosterState,
                    inventoryState: $inventoryState
                )
            }
            .tabItem {
                Label("Heroes", systemImage: "person.3.fill")
            }
            .tag(AppTab.heroes)

            NavigationStack {
                InventoryView(
                    inventoryState: $inventoryState
                )
            }
            .tabItem {
                Label("Inventory", systemImage: "backpack.fill")
            }
            .tag(AppTab.inventory)

            NavigationStack {
                PlaceholderTabView(
                    title: "Homestead",
                    subtitle: "A future base for crafting, upgrades, and long-term progression.",
                    iconName: "house.fill"
                )
            }
            .tabItem {
                Label("Homestead", systemImage: "house.fill")
            }
            .tag(AppTab.homestead)

            NavigationStack {
                PlaceholderTabView(
                    title: "Options",
                    subtitle: "Settings, account, accessibility, audio, and credits will live here.",
                    iconName: "gearshape.fill"
                )
            }
            .tabItem {
                Label("Options", systemImage: "gearshape.fill")
            }
            .tag(AppTab.options)
        }
    }
}

private enum AppTab: String {
    case play
    case heroes
    case inventory
    case homestead
    case options

    static var launchDefault: AppTab {
        let arguments = ProcessInfo.processInfo.arguments
        guard
            let flagIndex = arguments.firstIndex(of: "-selectedTab"),
            arguments.indices.contains(flagIndex + 1),
            let tab = AppTab(rawValue: arguments[flagIndex + 1].lowercased())
        else {
            return .play
        }

        return tab
    }
}

private struct PlayView: View {
    @Binding var rosterState: PlayerRosterState
    @State private var isShowingDebugBattle = false

    private let debugConfiguration = BattleDebugConfiguration.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(
                    title: "Play",
                    subtitle: "Choose a mode to start building the core loop.",
                    iconName: "gamecontroller.fill"
                )

                NavigationLink {
                    HeroSelectionView(rosterState: $rosterState)
                } label: {
                    ModeCard(mode: .battle)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Play")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isShowingDebugBattle) {
            BattleView(
                hero: debugConfiguration.hero,
                pet: debugConfiguration.pet,
                debugConfiguration: debugConfiguration
            )
        }
        .onAppear {
            guard debugConfiguration.isEnabled else { return }
            isShowingDebugBattle = true
        }
    }
}

private struct HeroSelectionView: View {
    @Binding var rosterState: PlayerRosterState

    var body: some View {
        SelectionGridView(
            title: "Select Hero",
            subtitle: "Pick the Hero who will lead this battle.",
            iconName: "shield.lefthalf.filled",
            combatants: rosterState.configuredCombatants(GameContent.heroes)
        ) { hero in
            PetSelectionView(hero: hero, rosterState: $rosterState)
        }
    }
}

private struct PetSelectionView: View {
    let hero: Combatant
    @Binding var rosterState: PlayerRosterState

    var body: some View {
        SelectionGridView(
            title: "Select Pet",
            subtitle: "\(hero.name) needs a companion for this battle.",
            iconName: "pawprint.fill",
            combatants: rosterState.configuredCombatants(GameContent.pets)
        ) { pet in
            BattleView(hero: hero, pet: pet)
        }
    }
}

private struct SelectionGridView<Destination: View>: View {
    let title: String
    let subtitle: String
    let iconName: String
    let combatants: [Combatant]
    let destination: (Combatant) -> Destination

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(title: title, subtitle: subtitle, iconName: iconName)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(combatants) { combatant in
                        NavigationLink {
                            destination(combatant)
                        } label: {
                            CombatantCard(combatant: combatant)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CombatantCardDetail: Identifiable {
    let combatant: Combatant
    let health: Int
    let activeStatusSummaries: [StatusSummary]

    var id: String { combatant.id }

    static func base(_ combatant: Combatant) -> CombatantCardDetail {
        CombatantCardDetail(
            combatant: combatant,
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
    @State private var activeFeedbackEvents: [BattleState.ActionEvent] = []
    @State private var isDebugPaused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let debugConfiguration: BattleDebugConfiguration
    private let timer = Timer.publish(
        every: ProcessInfo.processInfo.arguments.contains("-disableAnimations") ? 0.5 : 0.8,
        on: .main,
        in: .common
    ).autoconnect()
    private let feedbackLifetime: TimeInterval = 1.15
    private let maximumVisibleFeedbackEvents = 2

    init(
        hero: Combatant,
        pet: Combatant,
        debugConfiguration: BattleDebugConfiguration = .disabled
    ) {
        self.debugConfiguration = debugConfiguration
        _battle = State(initialValue: BattleState(hero: hero, pet: pet))
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
        .background(Color(.systemGroupedBackground))
        .navigationTitle(isShowingVictory ? "Victory" : "Battle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isShowingVictory {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingBattleLog = true
                    } label: {
                        Label("Battle Log", systemImage: "list.bullet.rectangle")
                    }
                }
            }
        }
        .sheet(item: $selectedDetails) { details in
            CombatantCardDetailSheet(
                combatant: details.combatant,
                health: details.health,
                activeStatusSummaries: details.activeStatusSummaries
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingBattleLog) {
            BattleLogSheet(entries: battle.log)
                .presentationDetents([.medium])
        }
        .safeAreaInset(edge: .bottom) {
            if debugConfiguration.isEnabled, !isShowingVictory {
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
            }
        }
        .onReceive(timer) { _ in
            guard canAutoAdvanceBattle else {
                return
            }

            advanceBattleTick()
        }
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
                        showsText: false
                    ) {
                        selectedDetails = CombatantCardDetail(
                            combatant: battle.enemy,
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
                        showsText: false
                    ) {
                        selectedDetails = CombatantCardDetail(
                            combatant: battle.hero,
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
                        showsText: false
                    ) {
                        selectedDetails = CombatantCardDetail(
                            combatant: battle.pet,
                            health: battle.pet.maxHealth,
                            activeStatusSummaries: []
                        )
                    }
                }
            }
            .padding(20)
        }
    }

    private var canAutoAdvanceBattle: Bool {
        selectedDetails == nil &&
            !isShowingBattleLog &&
            !battle.isEnemyDefeated &&
            !isShowingVictory &&
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
                    .foregroundStyle(isPaused ? .orange : .green)
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
        .background(.regularMaterial, in: TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(.quaternary, lineWidth: 1)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

private enum CombatantCollectionKind: String, CaseIterable, Identifiable {
    case heroes = "Heroes"
    case pets = "Pets"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .heroes:
            return "Build a party for the idle battle loop."
        case .pets:
            return "Companions bring abilities, stats, and charm."
        }
    }

    var iconName: String {
        switch self {
        case .heroes:
            return "shield.lefthalf.filled"
        case .pets:
            return "pawprint.fill"
        }
    }

    var combatants: [Combatant] {
        switch self {
        case .heroes:
            return GameContent.heroes
        case .pets:
            return GameContent.pets
        }
    }
}

private struct HeroesCollectionView: View {
    @Binding var rosterState: PlayerRosterState
    @Binding var inventoryState: PlayerInventoryState
    @State private var selectedKind: CombatantCollectionKind = .heroes
 
    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        // Smooth Horizontal Scroll Paging
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 0) {
                rosterGrid(for: CombatantCollectionKind.heroes.combatants)
                    .containerRelativeFrame(.horizontal)
                    .id(CombatantCollectionKind.heroes)

                rosterGrid(for: CombatantCollectionKind.pets.combatants)
                    .containerRelativeFrame(.horizontal)
                    .id(CombatantCollectionKind.pets)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: Binding(
            get: { Optional(selectedKind) },
            set: { newValue in
                if let newValue {
                    withAnimation(.spring(duration: 0.28)) {
                        selectedKind = newValue
                    }
                }
            }
        ))
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Heroes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Collection", selection: Binding(
                    get: { selectedKind },
                    set: { newValue in
                        withAnimation(.spring(duration: 0.28)) {
                            selectedKind = newValue
                        }
                    }
                )) {
                    ForEach(CombatantCollectionKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("Heroes collection switcher")
                .frame(width: 180)
            }
        }
    }

    private func rosterGrid(for combatants: [Combatant]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(rosterState.configuredCombatants(combatants)) { combatant in
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
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
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

private struct ModeCard: View {
    let mode: GameMode

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "bolt.fill")
                .font(.title)
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(mode.rawValue)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text(mode.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.headline)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(.quaternary, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mode.rawValue), \(mode.subtitle)")
    }
}

private struct CombatantCard: View {
    let combatant: Combatant

    var body: some View {
        PlaceholderCard(
            title: combatant.name,
            subtitle: "\(combatant.maxHealth) HP",
            footer: combatant.abilityLoadout.basic?.name ?? "No Ability"
        )
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                BattleArtCard(
                    combatant: combatant,
                    showsText: showsText
                )
                .frame(width: cardWidth)

                CombatHealthBar(
                    health: health,
                    maxHealth: maxHealth,
                    fillColor: prominence == .enemy ? .red : .blue
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

    var body: some View {
        TrinketDesign.cardShape
            .fill(.regularMaterial)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title)
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)

                    if showsText {
                        Text(combatant.name)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
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
                    .fill(.green.opacity(0.45))
                    .frame(width: width * restoreFraction)
                    .opacity(restoreOpacity)

                Capsule()
                    .fill(.orange.opacity(0.45))
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
            Image(systemName: event.keyword.feedbackSymbolName)
                .font(.caption.bold())

            Text(event.floatingText)
                .font(.headline)
                .monospacedDigit()
        }
        .foregroundStyle(event.keyword.feedbackColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(event.keyword.feedbackColor.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: event.keyword.feedbackColor.opacity(0.25), radius: 10, y: 5)
    }
}

private struct CombatFeedbackAnimationState {
    var opacity = 1.0
    var scale = 1.0
    var verticalOffset = 0.0
}

private extension Keyword {
    var feedbackSymbolName: String {
        switch self {
        case .physical:
            return "burst.fill"
        case .burn:
            return "flame.fill"
        }
    }

    var feedbackColor: Color {
        switch self {
        case .physical:
            return .primary
        case .burn:
            return .orange
        }
    }

    var descriptionColor: Color {
        switch self {
        case .physical:
            return .primary
        case .burn:
            return .orange
        }
    }
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

private extension Combatant {
    var healthBarColor: Color {
        role == .enemy ? .red : .blue
    }
}

private extension ItemSlot {
    var accentColor: Color {
        switch self {
        case .weapon:
            return .orange
        case .armor:
            return .blue
        case .accessory:
            return .purple
        }
    }
}

private struct CombatantCollectionDetailView: View {
    let combatant: Combatant
    let progression: CombatantProgression
    @Binding var loadout: AbilityLoadout
    @Binding var equipmentLoadout: EquipmentLoadout
    @Binding var inventoryState: PlayerInventoryState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(spacing: 16) {
                    BattleArtCard(combatant: combatant, showsText: false)
                        .frame(maxWidth: 220)
                        .accessibilityLabel("\(combatant.name) card art")

                    Text(combatant.name)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                DetailSection(title: "Progress") {
                    CombatantProgressionDetail(progression: progression)
                }

                DetailSection(title: "Health") {
                    CombatantHealthDetail(
                        health: combatant.maxHealth,
                        maxHealth: combatant.maxHealth,
                        fillColor: combatant.healthBarColor
                    )
                }

                DetailSection(title: "Abilities") {
                    NavigationLink {
                        AbilityLoadoutScreen(
                            combatant: combatant,
                            loadout: $loadout
                        )
                    } label: {
                        DetailNavigationRow(
                            title: "Ability Loadout",
                            subtitle: abilitySummary
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(combatant.name) ability loadout")
                }

                DetailSection(title: "Items") {
                    NavigationLink {
                        ItemLoadoutView(
                            combatant: combatant,
                            equipmentLoadout: $equipmentLoadout,
                            inventoryState: $inventoryState
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            DetailNavigationRow(
                                title: "Item Loadout",
                                subtitle: equippedItemSummary
                            )

                            EquipmentSlotSummaryGrid(
                                equipmentLoadout: equipmentLoadout,
                                inventoryState: inventoryState
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(combatant.name) item loadout")
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(combatant.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var abilitySummary: String {
        AbilityTier.allCases
            .compactMap { tier in
                loadout.ability(for: tier).map { "\(tier.rawValue): \($0.name)" }
            }
            .joined(separator: " • ")
    }

    private var equippedItemSummary: String {
        let equippedCount = ItemSlot.allCases.filter { slot in
            inventoryState.item(matching: equipmentLoadout.itemID(for: slot)) != nil
        }.count

        return "\(equippedCount)/\(ItemSlot.allCases.count) slots equipped"
    }
}

private struct CombatantProgressionDetail: View {
    let progression: CombatantProgression

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Level \(progression.level)")
                    .font(.headline)

                Spacer()

                Text("\(progression.currentXP)/\(progression.requiredXP) XP")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ExperienceProgressBar(progress: progression.progressFraction)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Level \(progression.level), \(progression.currentXP) of \(progression.requiredXP) experience")
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
                    .fill(.green)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }
}

private struct DetailNavigationRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct AbilityLoadoutScreen: View {
    let combatant: Combatant
    @Binding var loadout: AbilityLoadout

    var body: some View {
        ScrollView {
            AbilityLoadoutEditor(
                combatant: combatant,
                loadout: $loadout
            )
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("\(combatant.name) Abilities")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EquipmentSlotSummaryGrid: View {
    let equipmentLoadout: EquipmentLoadout
    let inventoryState: PlayerInventoryState

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(ItemSlot.allCases) { slot in
                if let item = inventoryState.item(matching: equipmentLoadout.itemID(for: slot)) {
                    ItemMiniCard(item: item, title: slot.rawValue)
                } else {
                    EmptyItemSlotCard(slot: slot)
                }
            }
        }
    }
}

private struct ItemLoadoutView: View {
    let combatant: Combatant
    @Binding var equipmentLoadout: EquipmentLoadout
    @Binding var inventoryState: PlayerInventoryState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(ItemSlot.allCases) { slot in
                    NavigationLink {
                        ItemSlotPickerView(
                            slot: slot,
                            equipmentLoadout: $equipmentLoadout,
                            inventoryState: $inventoryState
                        )
                    } label: {
                        EquipmentSlotRow(
                            slot: slot,
                            item: inventoryState.item(matching: equipmentLoadout.itemID(for: slot))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(slot.rawValue) item slot")
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("\(combatant.name) Items")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EquipmentSlotRow: View {
    let slot: ItemSlot
    let item: InventoryItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DetailNavigationRow(
                title: slot.rawValue,
                subtitle: item?.displayName ?? "Empty slot"
            )

            if let item {
                ItemCard(item: item, showsAffixCount: true)
                    .frame(maxWidth: 170)
            } else {
                EmptyItemSlotCard(slot: slot)
                    .frame(maxWidth: 170)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}

private struct ItemSlotPickerView: View {
    let slot: ItemSlot
    @Binding var equipmentLoadout: EquipmentLoadout
    @Binding var inventoryState: PlayerInventoryState
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button {
                    equipmentLoadout.unequip(slot)
                    dismiss()
                } label: {
                    EmptyItemSlotCard(slot: slot)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 160)
                .accessibilityIdentifier("Empty \(slot.rawValue) slot")

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(inventoryState.items(for: slot)) { item in
                        Button {
                            equipmentLoadout.equip(item, in: slot)
                            dismiss()
                        } label: {
                            ItemCard(item: item, showsAffixCount: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Equip \(item.displayName)")
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Choose \(slot.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum InventoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case weapon = "Weapon"
    case armor = "Armor"
    case accessory = "Accessory"

    var id: String { rawValue }

    var slot: ItemSlot? {
        switch self {
        case .all:
            return nil
        case .weapon:
            return .weapon
        case .armor:
            return .armor
        case .accessory:
            return .accessory
        }
    }
}

private struct InventoryView: View {
    @Binding var inventoryState: PlayerInventoryState
    @State private var searchText = ""
    @State private var selectedFilter: InventoryFilter = .all

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(
                    title: "Inventory",
                    subtitle: "Browse item rewards and inspect their affixes.",
                    iconName: "backpack.fill"
                )

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredItems) { item in
                        NavigationLink {
                            ItemDetailView(item: item)
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
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.inline)
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
                    Label(selectedFilter.rawValue, systemImage: "line.3.horizontal.decrease.circle")
                }
                .accessibilityIdentifier("Inventory filter")
            }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ItemCard(item: item, showsAffixCount: false)
                    .frame(maxWidth: 220)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.displayName)
                        .font(.largeTitle.bold())

                    Text("\(item.baseType.name) • \(item.baseType.slot.rawValue)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                DetailSection(title: "Affixes") {
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
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(item.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CombatantCardDetailSheet: View {
    let combatant: Combatant
    let health: Int
    let activeStatusSummaries: [StatusSummary]
    var editableLoadout: Binding<AbilityLoadout>? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(spacing: 16) {
                        BattleArtCard(combatant: combatant, showsText: false)
                            .frame(maxWidth: 210)
                            .accessibilityLabel("\(combatant.name) card art")

                        VStack(spacing: 4) {
                            Text(combatant.name)
                                .font(.largeTitle.bold())
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    DetailSection(title: "Health") {
                        CombatantHealthDetail(
                            health: health,
                            maxHealth: combatant.maxHealth,
                            fillColor: combatant.healthBarColor
                        )
                    }

                    if !activeStatusSummaries.isEmpty {
                        DetailSection(title: "Active Effects") {
                            ForEach(activeStatusSummaries) { summary in
                                KeywordDescriptionText(text: summary.text)
                                    .font(.subheadline)
                                    .accessibilityElement(children: .combine)
                            }
                        }
                    }

                    if combatant.abilities.isEmpty {
                        DetailSection(title: "Abilities") {
                            Text("No abilities yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if let editableLoadout {
                        AbilityLoadoutEditor(
                            combatant: combatant,
                            loadout: editableLoadout
                        )
                    } else {
                        DetailSection(title: "Abilities") {
                            ForEach(AbilityTier.allCases) { tier in
                                let abilities = combatant.abilityChoices.abilities(for: tier)
                                if !abilities.isEmpty {
                                    AbilityTierDetailGroup(
                                        tier: tier,
                                        abilities: abilities,
                                        selectedAbility: combatant.abilityLoadout.ability(for: tier)
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(combatant.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial, in: TrinketDesign.cardShape)
            .overlay {
                TrinketDesign.cardShape
                    .stroke(.quaternary, lineWidth: 1)
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

private struct AbilityDetailRow: View {
    let ability: Ability
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(ability.name)
                    .font(.headline)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .accessibilityLabel("Selected ability")
                }
            }

            KeywordDescriptionText(text: ability.summary)
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AbilityLoadoutEditor: View {
    let combatant: Combatant
    @Binding var loadout: AbilityLoadout

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Abilities")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach(AbilityTier.allCases) { tier in
                    let abilities = combatant.abilityChoices.abilities(for: tier)
                    if !abilities.isEmpty {
                        AbilityTierLoadoutCard(
                            tier: tier,
                            abilities: abilities,
                            loadout: $loadout
                        )
                    }
                }
            }
        }
    }
}

private struct AbilityTierLoadoutCard: View {
    let tier: AbilityTier
    let abilities: [Ability]
    @Binding var loadout: AbilityLoadout

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(tier.rawValue, systemImage: tier.symbolName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 10)

                Text(tier.cadenceLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }

            HStack(alignment: .top, spacing: 12) {
                ForEach(abilities) { ability in
                    Button {
                        loadout = loadout.selecting(ability)
                    } label: {
                        AbilityChoiceCard(
                            ability: ability,
                            tier: tier,
                            isSelected: ability.id == selectedAbility?.id
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(tier.rawValue) \(ability.name) ability card")
                }
            }

            if let selectedAbility {
                SelectedAbilitySummary(ability: selectedAbility)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(.quaternary, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var selectedAbility: Ability? {
        if let selected = loadout.ability(for: tier),
           let ability = abilities.first(where: { $0.id == selected.id }) {
            return ability
        }

        return abilities.first
    }
}

private struct AbilityChoiceCard: View {
    let ability: Ability
    let tier: AbilityTier
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                TrinketDesign.cardShape
                    .fill(.regularMaterial)

                LinearGradient(
                    colors: [
                        ability.damageKeyword.feedbackColor.opacity(0.24),
                        Color(.systemBackground).opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(TrinketDesign.cardShape)

                VStack(spacing: 10) {
                    Image(systemName: ability.damageKeyword.feedbackSymbolName)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(ability.damageKeyword.feedbackColor)
                        .accessibilityHidden(true)

                    Text(ability.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }
                .padding(10)
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .green)
                        .padding(7)
                        .accessibilityLabel("Selected ability")
                }
            }
            .overlay {
                TrinketDesign.cardShape
                    .stroke(
                        isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary),
                        lineWidth: isSelected ? 3 : 1
                    )
            }
            .shadow(color: isSelected ? Color.accentColor.opacity(0.18) : .clear, radius: 10, y: 4)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ability.name), \(tier.rawValue)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

private struct SelectedAbilitySummary: View {
    let ability: Ability

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ability.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: ability.damageKeyword.feedbackSymbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ability.damageKeyword.feedbackColor)
                    .frame(width: 20)
                    .accessibilityHidden(true)

                KeywordDescriptionText(text: ability.summary)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct AbilityTierDetailGroup: View {
    let tier: AbilityTier
    let abilities: [Ability]
    let selectedAbility: Ability?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tier.rawValue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(orderedAbilities) { ability in
                AbilityDetailRow(
                    ability: ability,
                    isSelected: ability.id == selectedAbility?.id
                )
            }
        }
    }

    private var orderedAbilities: [Ability] {
        guard let selectedAbility else { return abilities }

        return abilities.sorted { first, second in
            if first.id == selectedAbility.id { return true }
            if second.id == selectedAbility.id { return false }
            return first.name < second.name
        }
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
                    .foregroundColor(match.keyword.descriptionColor)
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

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)

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
        .background(.regularMaterial, in: TrinketDesign.cardShape)
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
            List(entries) { entry in
                Text(entry.text)
            }
            .navigationTitle("Battle Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PlaceholderTabView: View {
    let title: String
    let subtitle: String
    let iconName: String

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScreenHeader(title: title, subtitle: subtitle, iconName: iconName)
                .padding(32)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ScreenHeader: View {
    let title: String
    let subtitle: String
    let iconName: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))

                Text(subtitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ItemCard: View {
    let item: InventoryItem
    var showsAffixCount: Bool

    var body: some View {
        TrinketDesign.cardShape
            .fill(.regularMaterial)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                LinearGradient(
                    colors: [
                        item.baseType.slot.accentColor.opacity(0.22),
                        Color(.systemBackground).opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(TrinketDesign.cardShape)
            }
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: item.baseType.symbolName)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(item.baseType.slot.accentColor)
                        .accessibilityHidden(true)

                    Text(item.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(item.baseType.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if showsAffixCount {
                        Text("\(min(item.affixes.count, 4)) affixes")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
            }
            .overlay {
                TrinketDesign.cardShape
                    .stroke(item.baseType.slot.accentColor.opacity(0.35), lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(item.displayName), \(item.baseType.slot.rawValue), \(item.affixes.count) affixes")
    }
}

private struct ItemMiniCard: View {
    let item: InventoryItem
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ItemCard(item: item, showsAffixCount: false)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct EmptyItemSlotCard: View {
    let slot: ItemSlot

    var body: some View {
        TrinketDesign.cardShape
            .fill(.regularMaterial)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: slot.symbolName)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(slot.accentColor.opacity(0.7))
                        .accessibilityHidden(true)

                    Text(slot.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Empty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
            }
            .overlay {
                TrinketDesign.cardShape
                    .stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [5]))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Empty \(slot.rawValue) slot")
    }
}

private struct PlaceholderCard: View {
    let title: String
    var subtitle: String = "Card"
    var footer: String? = nil

    var body: some View {
        TrinketDesign.cardShape
            .fill(.regularMaterial)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)

                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let footer {
                        Text(footer)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .overlay {
                TrinketDesign.cardShape
                    .stroke(.quaternary, lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title) card")
    }
}

#Preview {
    ContentView()
}
