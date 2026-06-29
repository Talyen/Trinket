import SwiftUI

enum PlayRoute: Hashable {
    case heroSelection
    case petSelection(Combatant)
    case combatantDetail(CombatantCardDetail)
}

struct PlayView: View {
    @Binding var rosterState: PlayerRosterState
    @Binding var inventoryState: PlayerInventoryState
    @Binding var activeBattle: ActiveBattleConfiguration?
    @Binding var isBattlePaused: Bool
    @State private var path: [PlayRoute] = []

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
                            let oneShot = AppEnvironment.shared.battlePreset == .oneShot
                            let initialBattle: BattleState? = oneShot
                                ? BattleSimulator.runToHealth(targetHealth: 0, hero: hero, pet: pet)
                                : nil
                            activeBattle = ActiveBattleConfiguration(
                                hero: hero,
                                pet: pet,
                                heroProgression: rosterState.progression(for: hero),
                                petProgression: rosterState.progression(for: pet),
                                heroEquipmentLoadout: rosterState.equipmentLoadout(for: hero),
                                petEquipmentLoadout: rosterState.equipmentLoadout(for: pet),
                                inventoryState: inventoryState,
                                initialBattle: initialBattle
                            )
                            if oneShot {
                                isBattlePaused = true
                            }
                            path.removeAll()
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
        .onChange(of: activeBattle?.id) { _, newValue in
            if newValue != nil {
                path.removeAll()
            }
        }
        .onChange(of: path.count) { _, newCount in
            guard activeBattle != nil else { return }
            if newCount > 0 {
                isBattlePaused = true
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let activeBattle {
            BattleView(
                hero: activeBattle.hero,
                pet: activeBattle.pet,
                initialBattle: activeBattle.initialBattle,
                heroProgression: activeBattle.heroProgression,
                petProgression: activeBattle.petProgression,
                heroEquipmentLoadout: activeBattle.heroEquipmentLoadout,
                petEquipmentLoadout: activeBattle.petEquipmentLoadout,
                inventoryState: activeBattle.inventoryState,
                isBattlePaused: $isBattlePaused,
                onEndBattle: {
                    isBattlePaused = false
                    self.activeBattle = nil
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

struct CombatantCardDetail: Hashable, Identifiable {
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
