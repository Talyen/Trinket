import SwiftUI

enum CombatantDetailNavigationChrome {
    case visible
    case hidden
}

struct CombatantDetailPane: View {
    let combatant: Combatant
    let progression: CombatantProgression
    @Binding var loadout: AbilityLoadout
    @Binding var equipmentLoadout: EquipmentLoadout
    @Binding var inventoryState: PlayerInventoryState
    let allowsEditing: Bool
    var battleHealth: Int?
    var activeEffectSummaries: [EffectSummary] = []
    var navigationChrome: CombatantDetailNavigationChrome = .visible
    @Binding var selectedItemSlot: ItemSlot?

    @State private var headerHeight: CGFloat = 300
    @State private var titleOpacity: CGFloat = 0

    private let scrollCoordinateSpaceName = "CombatantDetailScroll"

    var body: some View {
        GeometryReader { geometry in
            let baseHeaderHeight = max(geometry.size.width * 4.0 / 3.0, 300)

            ScrollView {
                VStack(spacing: 0) {
                    CombatantHeroHeader(
                        combatant: combatant,
                        progression: progression,
                        baseHeight: baseHeaderHeight,
                        coordinateSpaceName: scrollCoordinateSpaceName
                    )
                    .accessibilityIdentifier("\(combatant.name) detail hero header")

                    VStack(alignment: .leading, spacing: 0) {
                        section("Stats") {
                            statRow("Health", value: "\(currentHealth)/\(combatant.maxHealth)")
                        }

                        if !activeEffectSummaries.isEmpty {
                            section("Active Effects") {
                                ForEach(activeEffectSummaries) { summary in
                                    KeywordDescriptionText(text: summary.text)
                                        .font(.subheadline)
                                        .accessibilityElement(children: .combine)
                                }
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
            .coordinateSpace(name: scrollCoordinateSpaceName)
            .ignoresSafeArea(edges: .top)
            .background(TrinketDesign.Colors.appBackground)
            .combatantDetailNavigationChrome(navigationChrome, title: combatant.name, titleOpacity: titleOpacity)
            .onAppear {
                headerHeight = baseHeaderHeight
            }
            .onChange(of: baseHeaderHeight) { _, newHeight in
                headerHeight = newHeight
            }
            .onScrollGeometryChange(for: ScrollState.self) { geometry in
                ScrollState(
                    offsetY: geometry.contentOffset.y + geometry.contentInsets.top,
                    topInset: geometry.contentInsets.top
                )
            } action: { _, state in
                let threshold = headerHeight - state.topInset - 44
                titleOpacity = min(max((state.offsetY - threshold) / 20, 0), 1)
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

    private var currentHealth: Int {
        battleHealth ?? combatant.maxHealth
    }

    private func statRow(_ title: String, value: String) -> some View {
        LabeledContent {
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        } label: {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }

    private struct ScrollState: Equatable {
        var offsetY: CGFloat
        var topInset: CGFloat
    }
}

private extension View {
    @ViewBuilder
    func combatantDetailNavigationChrome(
        _ chrome: CombatantDetailNavigationChrome,
        title: String,
        titleOpacity: CGFloat
    ) -> some View {
        switch chrome {
        case .visible:
            self
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(title)
                            .font(.headline)
                            .opacity(titleOpacity)
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
        case .hidden:
            self
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}
