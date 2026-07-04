import SwiftUI
import TrinketContent
import TrinketDesignSystem


struct CollectionView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedItem: InventoryItem?
    @State private var selectedCombatant: CombatantCollectionDetailSelection?
    private let initialItemID: String?

    init(
        initialCombatantDetail: CombatantCollectionDetailSelection? = nil,
        initialItemID: String? = nil
    ) {
        _selectedCombatant = State(initialValue: initialCombatantDetail)
        self.initialItemID = initialItemID
    }

    var body: some View {
        let inventoryState = appState.inventory.current

        ScrollView {
            VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                    NavigationLink {
                        HeroesGridView()
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
                        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("Heroes collection category")

                    horizontalShelf {
                        ForEach(appState.roster.collectionHeroes) { combatant in
                            CollectionCombatantButton(
                                combatant: combatant,
                                isLocked: !appState.roster.isUnlocked(combatant),
                                cardWidth: nil,
                                showsName: false
                            ) {
                                selectedCombatant = CombatantCollectionDetailSelection(kind: .hero, combatantID: combatant.id)
                            }
                            .collectionShelfCardWidth()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                    NavigationLink {
                        PetsGridView()
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
                        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("Pets collection category")

                    horizontalShelf {
                        ForEach(appState.roster.collectionPets) { combatant in
                            CollectionCombatantButton(
                                combatant: combatant,
                                isLocked: !appState.roster.isUnlocked(combatant),
                                cardWidth: nil,
                                showsName: false
                            ) {
                                selectedCombatant = CombatantCollectionDetailSelection(kind: .pet, combatantID: combatant.id)
                            }
                            .collectionShelfCardWidth()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                    NavigationLink {
                        InventoryGridView()
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
                        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("Inventory collection category")

                    horizontalShelf {
                        ForEach(Array(inventoryState.items.prefix(12))) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                ItemCard(item: item, showsAffixCount: false, showsName: false)
                                    .collectionShelfCardWidth()
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(item.displayName) item card")
                        }
                    }
                }
            }
            .padding(.top, TrinketDesign.Metrics.compactContentTopPadding)
            .padding(.bottom, TrinketDesign.Metrics.sectionSpacing)
        }
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle("Collection")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            guard selectedItem == nil,
                  let initialItemID,
                  let item = appState.inventory.current.item(matching: initialItemID)
            else { return }
            selectedItem = item
        }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                ItemDetailView(item: item)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .sheet(item: $selectedCombatant) { selection in
            CombatantCollectionDetailSheet(selection: selection)
                .presentationDetents([.large])
                .presentationContentInteraction(.resizes)
                .presentationDragIndicator(.hidden)
        }
    }

    private func horizontalShelf<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: TrinketDesign.Metrics.collectionShelfCardSpacing) {
                content()
            }
            .scrollTargetLayout()
            .padding(.vertical, TrinketDesign.Metrics.shelfVerticalPadding)
        }
        .contentMargins(
            .horizontal,
            TrinketDesign.Metrics.collectionShelfHorizontalMargin,
            for: .scrollContent
        )
        .scrollTargetBehavior(.viewAligned)
    }
}
