import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct CollectionView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var selectedItem: InventoryItem?
    @State private var selectedCombatant: CombatantDetailContext?
    @State private var showMissingItem = false

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !trimmedQuery.isEmpty
    }

    var body: some View {
        Group {
            if isSearching {
                CollectionSearchResultsView(
                    query: trimmedQuery,
                    results: CollectionSearch.results(
                        for: trimmedQuery,
                        rosterState: appState.roster.current,
                        inventoryState: appState.inventory.current
                    ),
                    onSelectItem: { selectedItem = $0 },
                    onSelectCombatant: { selectedCombatant = $0 }
                )
            } else {
                collectionBrowseContent
            }
        }
        .trinketScreenBackground(isSearching ? .denseList : .collection)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .accessibilityIdentifier("Collection Screen")
        .navigationTitle("Collection")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search collection")
        .onAppear(perform: presentPendingLaunchRoute)
        .alert("Item Not Found", isPresented: $showMissingItem) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("That item isn't in your collection.")
        }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                ItemDetailView(item: item)
            }
            .trinketDetailSheet()
        }
        .sheet(item: $selectedCombatant) { context in
            appState.rosterCombatantDetail(
                kind: context.kind,
                combatantID: context.combatantID
            )
            .trinketDetailSheet()
        }
    }

    private var collectionBrowseContent: some View {
        let inventoryState = appState.inventory.current
        let shelfItems = appState.collectionInventoryShelfItems()

        return ScrollView {
            VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
                combatantCategorySection(
                    title: "Heroes",
                    accessibilityIdentifier: AccessibilityID.Collection.heroesCategory,
                    kind: .hero,
                    combatants: appState.roster.collectionHeroes,
                    unviewedCount: appState.unviewedHeroCount
                )

                combatantCategorySection(
                    title: "Pets",
                    accessibilityIdentifier: AccessibilityID.Collection.petsCategory,
                    kind: .pet,
                    combatants: appState.roster.collectionPets,
                    unviewedCount: appState.unviewedPetCount
                )

                if !inventoryState.items.isEmpty {
                    collectionCategorySection(
                        title: "Inventory",
                        accessibilityIdentifier: AccessibilityID.Collection.inventoryCategory,
                        unviewedCount: appState.unviewedItemCount,
                        destination: InventoryGridView()
                    ) {
                        ForEach(shelfItems) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                ItemCard(
                                    item: item,
                                    showsAffixCount: false,
                                    showsName: false,
                                    showsNewMarker: appState.showsCollectionNewMarker(for: item)
                                )
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
    }

    private func presentPendingLaunchRoute() {
        guard let presentation = appState.consumePendingCollectionPresentation() else { return }

        switch presentation {
        case let .collectionCombatant(context):
            selectedCombatant = context
        case let .collectionItem(itemID):
            if let owned = appState.inventory.current.item(matching: itemID) {
                selectedItem = owned
            } else if let template = GameContent.itemTemplate(matching: itemID) {
                selectedItem = template
            } else {
                showMissingItem = true
            }
        }
    }

    private func combatantCategorySection(
        title: String,
        accessibilityIdentifier: String,
        kind: CombatantDetailContext.Kind,
        combatants: [Combatant],
        unviewedCount: Int
    ) -> some View {
        collectionCategorySection(
            title: title,
            accessibilityIdentifier: accessibilityIdentifier,
            unviewedCount: unviewedCount,
            destination: CollectionCombatantGridView(kind: kind)
        ) {
            ForEach(combatants) { combatant in
                CollectionCombatantButton(
                    combatant: combatant,
                    isLocked: !appState.roster.current.isUnlocked(combatant),
                    cardWidth: nil,
                    showsName: false,
                    showsNewMarker: appState.showsCollectionNewMarker(for: combatant.id)
                ) {
                    selectedCombatant = CombatantDetailContext(kind: kind, combatantID: combatant.id)
                }
                .collectionShelfCardWidth()
            }
        }
    }

    private func collectionCategorySection<Destination: View, ShelfContent: View>(
        title: String,
        accessibilityIdentifier: String,
        unviewedCount: Int,
        destination: Destination,
        @ViewBuilder shelf: () -> ShelfContent
    ) -> some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
            NavigationLink {
                destination
            } label: {
                collectionCategoryHeader(title: title, unviewedCount: unviewedCount)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(accessibilityIdentifier)
            .accessibilityLabel(
                unviewedCount > 0
                    ? "\(title), \(unviewedCount) new"
                    : title
            )

            horizontalShelf(content: shelf)
        }
    }

    private func collectionCategoryHeader(title: String, unviewedCount: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if unviewedCount > 0 {
                Text("\(unviewedCount)")
                    .trinketTypography(.badge)
                    .foregroundStyle(TrinketDesign.Colors.destructive)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .trinketStatusBadge()
                    .accessibilityIdentifier(
                        AccessibilityID.Collection.categoryUnviewedCount(title: title)
                    )
            }
        }
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .contentShape(Rectangle())
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
