import SwiftUI

struct CollectionView: View {
    @Binding var rosterState: PlayerRosterState
    @Binding var inventoryState: PlayerInventoryState

    @State private var selectedItem: InventoryItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
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

struct HeroesGridView: View {
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

struct PetsGridView: View {
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

struct CombatantCollectionDetailView: View {
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

struct CombatantDetailPane: View {
    let combatant: Combatant
    let progression: CombatantProgression
    @Binding var loadout: AbilityLoadout
    @Binding var equipmentLoadout: EquipmentLoadout
    @Binding var inventoryState: PlayerInventoryState
    let allowsEditing: Bool
    var battleHealth: Int?
    var activeStatusSummaries: [StatusSummary] = []
    @Binding var selectedItemSlot: ItemSlot?

    @State private var heroStretch: CGFloat = 0
    @State private var heroBaseHeight: CGFloat = 400

    var body: some View {
        List {
            Section {
                CombatantHeroHeader(
                    combatant: combatant,
                    progression: progression,
                    battleHealth: battleHealth
                )
                .frame(minHeight: heroBaseHeight + heroStretch)
                .ignoresSafeArea(edges: .top)
                .accessibilityIdentifier("\(combatant.name) detail hero header")
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listSectionMargins(.horizontal, 0)
            .listSectionMargins(.top, 0)

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
        .scrollEdgeEffectStyle(.hard, for: .top)
        .contentMargins(.top, 0, for: .scrollContent)
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle(combatant.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            min(geometry.contentOffset.y, 0)
        } action: { _, overscroll in
            heroStretch = min(-overscroll, heroBaseHeight * 0.6)
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        let width = geometry.size.width
                        heroBaseHeight = max(width * 4.0 / 3.0, 320)
                    }
            }
        }
    }
}

struct CombatantHeroHeader: View {
    let combatant: Combatant
    let progression: CombatantProgression
    let battleHealth: Int?

    var body: some View {
        CombatantArtwork(combatant: combatant)
            .aspectRatio(3.0 / 4.0, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .bottomLeading) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .safeAreaPadding(.bottom)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(combatant.name), \(combatant.role.rawValue), level \(progression.level), \(currentHealth) of \(combatant.maxHealth) health")
    }

    private var currentHealth: Int {
        battleHealth ?? combatant.maxHealth
    }
}
