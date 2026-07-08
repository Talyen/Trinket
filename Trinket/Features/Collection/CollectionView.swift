import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct CollectionView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedItem: InventoryItem?
    @State private var selectedCombatant: CombatantDetailContext?
    @State private var showMissingItem = false

    var body: some View {
        let inventoryState = appState.inventory.current

        ScrollView {
            VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
                combatantCategorySection(
                    title: "Heroes",
                    accessibilityIdentifier: "Heroes collection category",
                    kind: .hero,
                    combatants: appState.roster.collectionHeroes
                )

                combatantCategorySection(
                    title: "Pets",
                    accessibilityIdentifier: "Pets collection category",
                    kind: .pet,
                    combatants: appState.roster.collectionPets
                )

                if !inventoryState.items.isEmpty {
                    collectionCategorySection(
                        title: "Inventory",
                        accessibilityIdentifier: AccessibilityID.Collection.inventoryCategory,
                        destination: InventoryGridView()
                    ) {
                        ForEach(Array(inventoryState.items.prefix(12))) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                ItemCard(
                                    item: item,
                                    showsAffixCount: false,
                                    showsName: false,
                                    showsNewMarker: appState.showsCollectionNewMarker(forItem: item.id)
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
        .trinketScreenBackground(.collection)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .accessibilityIdentifier("Collection Screen")
        .navigationTitle("Collection")
        .navigationBarTitleDisplayMode(.large)
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
        combatants: [Combatant]
    ) -> some View {
        collectionCategorySection(
            title: title,
            accessibilityIdentifier: accessibilityIdentifier,
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
        destination: Destination,
        @ViewBuilder shelf: () -> ShelfContent
    ) -> some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
            NavigationLink {
                destination
            } label: {
                collectionCategoryHeader(title: title)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(accessibilityIdentifier)

            horizontalShelf(content: shelf)
        }
    }

    private func collectionCategoryHeader(title: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
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
