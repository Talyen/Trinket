import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct CollectionView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedCombatant: CombatantDetailContext?
    @State private var showMissingItem = false
    private let initialCombatantDetail: CombatantDetailContext?
    private let initialItemID: String?
    @Binding var collectionPath: NavigationPath

    init(
        initialCombatantDetail: CombatantDetailContext? = nil,
        initialItemID: String? = nil,
        collectionPath: Binding<NavigationPath> = .constant(NavigationPath())
    ) {
        self.initialCombatantDetail = initialCombatantDetail
        self.initialItemID = initialItemID
        _collectionPath = collectionPath
    }

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
                            NavigationLink(value: item) {
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
        .trinketScreenBackground(.collection)
        .accessibilityIdentifier("Collection Screen")
        .navigationTitle("Collection")
        .navigationBarTitleDisplayMode(.large)
        // Items use navigationDestination (push) — no sheet conflict.
        .navigationDestination(for: InventoryItem.self) { item in
            ItemDetailView(item: item)
        }
        // Combatant detail is a sheet, owned here at the NavigationStack root.
        // This prevents the UITransitionView from overlapping the tab bar during dismissal.
        // The sheet header (drag indicator and navigation bar) is hidden — the hero art
        // runs edge-to-edge with a close button overlaid.
        .sheet(item: $selectedCombatant) { context in
            CombatantDetailSheet(
                kind: context.kind,
                combatantID: context.combatantID
            )
            .presentationDetents([.large])
            .presentationContentInteraction(.resizes)
            .presentationDragIndicator(.hidden)
            .presentationBackgroundInteraction(.enabled)
        }
        .onAppear {
            handleDeepLink()
        }
        .alert("Item Not Found", isPresented: $showMissingItem) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("That item isn't in your collection.")
        }
    }

    private func handleDeepLink() {
        if let context = initialCombatantDetail {
            selectedCombatant = context
        } else if let itemID = initialItemID {
            if let owned = appState.inventory.current.item(matching: itemID) {
                collectionPath.append(owned)
            } else if let template = GameContent.itemTemplate(matching: itemID) {
                collectionPath.append(template)
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
            destination: CollectionCombatantGridView(kind: kind, selectedCombatant: $selectedCombatant)
        ) {
            ForEach(combatants) { combatant in
                let isLocked = !appState.roster.current.isUnlocked(combatant)
                CollectionCombatantButton(
                    combatant: combatant,
                    isLocked: isLocked,
                    cardWidth: nil,
                    showsName: false
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

// MARK: - Sheet content for combatant detail.
// The sheet header (drag indicator + navigation bar) is removed so the hero
// artwork runs edge-to-edge.
private struct CombatantDetailSheet: View {
    let kind: CombatantDetailContext.Kind
    let combatantID: String
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            appState.rosterCombatantDetail(
                kind: kind,
                combatantID: combatantID,
                hidesNavigationBar: true
            )
        }
    }
}
