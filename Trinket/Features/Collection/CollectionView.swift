import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct CollectionView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedItem: InventoryItem?
    @State private var selectedCombatant: CombatantDetailContext?
    @State private var showMissingItem = false

    var body: some View {
        collectionBrowseContent
            .trinketScreenBackground()
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
                .appFramePacingSignpost(
                    AppFramePacingSignposts.Name.sheetPresent,
                    isActive: true
                )
                .onAppear {
                    AppFramePacingSignposts.event(
                        AppFramePacingSignposts.Name.sheetPresent,
                        detail: "collectionItem=\(item.id)"
                    )
                }
            }
            .sheet(item: $selectedCombatant) { context in
                NavigationStack {
                    RosterCombatantDetailView(
                        kind: context.kind,
                        combatantID: context.combatantID
                    )
                }
                .trinketDetailSheet()
                .appFramePacingSignpost(
                    AppFramePacingSignposts.Name.sheetPresent,
                    isActive: true
                )
                .onAppear {
                    AppFramePacingSignposts.event(
                        AppFramePacingSignposts.Name.sheetPresent,
                        detail: "collectionCombatant=\(context.combatantID)"
                    )
                }
            }
    }

    private var collectionBrowseContent: some View {
        let inventoryState = appState.inventory
        let shelfItems = Array(inventoryState.items.prefix(12))

        return ScrollView {
            VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
                combatantCategorySection(
                    title: "Heroes",
                    accessibilityIdentifier: AccessibilityID.Collection.heroesCategory,
                    kind: .hero,
                    combatants: appState.roster.collectionHeroes
                )

                combatantCategorySection(
                    title: "Companions",
                    accessibilityIdentifier: AccessibilityID.Collection.companionsCategory,
                    kind: .companion,
                    combatants: appState.roster.collectionCompanions
                )

                if !inventoryState.items.isEmpty {
                    collectionCategorySection(
                        title: "Inventory",
                        accessibilityIdentifier: AccessibilityID.Collection.inventoryCategory,
                        destination: InventoryGridView()
                    ) {
                        ForEach(shelfItems) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                ItemCard(
                                    item: item,
                                    showsAffixCount: false,
                                    showsName: false
                                )
                                .collectionShelfCardWidth()
                            }
                            .trinketQuietTapButtonStyle()
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
            if let owned = appState.inventory.item(matching: itemID) {
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
                    isLocked: !appState.roster.isUnlocked(combatant),
                    cardWidth: nil,
                    showsName: false
                ) {
                    selectedCombatant = CombatantDetailContext(kind: kind, combatantID: combatant.id)
                }
                .collectionShelfCardWidth()
            }
        }
    }

    private func collectionCategorySection(
        title: String,
        accessibilityIdentifier: String,
        destination: some View,
        @ViewBuilder shelf: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
            NavigationLink {
                destination
            } label: {
                collectionCategoryHeader(title: title)
            }
            .trinketQuietTapButtonStyle()
            .accessibilityIdentifier(accessibilityIdentifier)

            horizontalShelf(content: shelf)
        }
    }

    private func collectionCategoryHeader(title: String) -> some View {
        HStack(spacing: TrinketDesign.Metrics.denseSpacing) {
            Text(title)
                .trinketTypography(.sectionTitle)
                .foregroundStyle(.primary)
            Image(systemName: "chevron.right")
                .trinketTypography(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .contentShape(Rectangle())
    }

    private func horizontalShelf(@ViewBuilder content: () -> some View) -> some View {
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
