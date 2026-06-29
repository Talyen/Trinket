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

    @State private var headerHeight: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var stretch: CGFloat = 0
    @State private var titleOpacity: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                CombatantHeroHeader(
                    combatant: combatant,
                    progression: progression,
                    battleHealth: battleHealth,
                    headerHeight: headerHeight,
                    stretch: stretch,
                    containerWidth: containerWidth
                )
                .accessibilityIdentifier("\(combatant.name) detail hero header")

                VStack(alignment: .leading, spacing: 0) {
                    section("Experience") {
                        ExperienceProgressDetail(progression: progression)
                    }

                    if let battleHealth {
                        section("Health") {
                            CombatantHealthDetail(
                                health: battleHealth,
                                maxHealth: combatant.maxHealth,
                                fillColor: combatant.healthBarColor
                            )
                        }
                    }

                    if !activeStatusSummaries.isEmpty {
                        section("Active Effects") {
                            ForEach(activeStatusSummaries) { summary in
                                KeywordDescriptionText(text: summary.text)
                                    .font(.subheadline)
                                    .accessibilityElement(children: .combine)
                            }
                        }
                    }

                    section("Stats") {
                        HStack {
                            Text("Health")

                            Spacer()

                            Text("\(combatant.maxHealth) HP")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }

                    section("Abilities") {
                        AbilitySummaryGrid(
                            combatant: combatant,
                            loadout: $loadout,
                            allowsEditing: allowsEditing
                        )
                        .padding(.vertical, 4)
                    }

                    section("Items") {
                        EquipmentSlotSummaryGrid(
                            equipmentLoadout: equipmentLoadout,
                            inventoryState: inventoryState,
                            onSelect: allowsEditing ? { selectedItemSlot = $0 } : nil
                        )
                        .padding(.vertical, 4)
                    }
                }
                .background(TrinketDesign.Colors.appBackground)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle(combatant.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(combatant.name)
                    .font(.headline)
                    .opacity(titleOpacity)
            }
        }
        .onScrollGeometryChange(for: ScrollState.self) { geometry in
            ScrollState(
                offsetY: geometry.contentOffset.y,
                topInset: geometry.contentInsets.top
            )
        } action: { _, state in
            stretch = max(0, -state.offsetY)
            let threshold = headerHeight - state.topInset - 44
            titleOpacity = min(max((state.offsetY - threshold) / 20, 0), 1)
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onGeometryChange(for: CGSize.self) { proxy in
                        proxy.size
                    } action: { newSize in
                        setContainerSize(newSize)
                    }
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 24)

            content()
                .padding(.horizontal, 20)
        }
    }

    private func setContainerSize(_ size: CGSize) {
        let height = size.height
        headerHeight = min(max(height * 0.38, 300), height * 0.5)
        containerWidth = size.width
    }

    private struct ScrollState: Equatable {
        var offsetY: CGFloat
        var topInset: CGFloat
    }
}
