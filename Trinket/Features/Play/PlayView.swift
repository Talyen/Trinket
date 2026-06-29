import SwiftUI

enum PlayRoute: Hashable {
    case heroSelection
    case petSelection(Combatant)
    case combatantDetail(CombatantCardDetail)
}

struct PlayView: View {
    @Environment(AppState.self) private var appState
    @State private var path: [PlayRoute] = []

    var body: some View {
        @Bindable var state = appState
        @Bindable var battle = appState.battle

        NavigationStack(path: $path) {
            content
                .navigationDestination(for: PlayRoute.self) { route in
                    switch route {
                    case .heroSelection:
                        HeroSelectionView { hero in
                            path.append(.petSelection(hero))
                        }
                    case .petSelection(let hero):
                        PetSelectionView(hero: hero) { pet in
                            appState.battle.activeBattle = ActiveBattleConfiguration(
                                hero: hero,
                                pet: pet,
                                heroProgression: appState.roster.current.progression(for: hero),
                                petProgression: appState.roster.current.progression(for: pet),
                                heroEquipmentLoadout: appState.roster.current.equipmentLoadout(for: hero),
                                petEquipmentLoadout: appState.roster.current.equipmentLoadout(for: pet),
                                inventoryState: appState.inventory.current
                            )
                            path.removeAll()
                        }
                    case .combatantDetail(let detail):
                        CombatantDetailPane(
                            combatant: detail.combatant,
                            progression: detail.progression,
                            loadout: .constant(detail.combatant.abilityLoadout),
                            equipmentLoadout: .constant(detail.equipmentLoadout),
                            inventoryState: .constant(detail.inventoryState),
                            allowsEditing: false,
                            battleHealth: detail.health,
                            activeStatusSummaries: detail.activeStatusSummaries,
                            selectedItemSlot: .constant(nil)
                        )
                    }
                }
        }
        .onChange(of: appState.battle.activeBattle?.id) { _, newValue in
            if newValue != nil {
                path.removeAll()
            }
        }
        .onChange(of: path.count) { _, newCount in
            guard appState.battle.activeBattle != nil else { return }
            if newCount > 0 {
                appState.battle.isPaused = true
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let activeBattle = appState.battle.activeBattle {
            BattleView(
                hero: activeBattle.hero,
                pet: activeBattle.pet,
                heroProgression: activeBattle.heroProgression,
                petProgression: activeBattle.petProgression,
                heroEquipmentLoadout: activeBattle.heroEquipmentLoadout,
                petEquipmentLoadout: activeBattle.petEquipmentLoadout,
                inventoryState: activeBattle.inventoryState,
                isBattlePaused: Binding(
                    get: { appState.battle.isPaused },
                    set: { appState.battle.isPaused = $0 }
                ),
                onEndBattle: {
                    appState.battle.isPaused = false
                    appState.battle.activeBattle = nil
                },
                onRestartBattle: {
                    appState.battle.activeBattle = ActiveBattleConfiguration(
                        hero: activeBattle.hero,
                        pet: activeBattle.pet,
                        heroProgression: activeBattle.heroProgression,
                        petProgression: activeBattle.petProgression,
                        heroEquipmentLoadout: activeBattle.heroEquipmentLoadout,
                        petEquipmentLoadout: activeBattle.petEquipmentLoadout,
                        inventoryState: activeBattle.inventoryState
                    )
                },
                onShowCombatantDetail: { detail in
                    path.append(.combatantDetail(detail))
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
    @Environment(AppState.self) private var appState
    let onSelect: (Combatant) -> Void

    var body: some View {
        SelectionGridView(
            title: "Select Hero",
            combatants: appState.roster.current.configuredCombatants(GameContent.heroes),
            onSelect: onSelect
        )
    }
}

private struct PetSelectionView: View {
    @Environment(AppState.self) private var appState
    let hero: Combatant
    let onSelect: (Combatant) -> Void

    var body: some View {
        SelectionGridView(
            title: "Select Pet",
            combatants: appState.roster.current.configuredCombatants(GameContent.pets),
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
