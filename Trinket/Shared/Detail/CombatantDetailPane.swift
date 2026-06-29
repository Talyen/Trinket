import SwiftUI

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
