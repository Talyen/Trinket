import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct CollectionView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedItem: InventoryItem?
    @State private var selectedCombatant: CombatantDetailContext?
    @State private var showMissingItem = false
    @State private var salvageSuccessCount = 0
    @Namespace private var zoomNamespace

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
                    ItemDetailView.inventorySalvageDetail(item: item, appState: appState) { didSucceed in
                        if didSucceed {
                            salvageSuccessCount += 1
                        }
                        selectedItem = nil
                    }
                }
                .navigationTransition(.zoom(sourceID: item.id, in: zoomNamespace))
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
                .navigationTransition(.zoom(sourceID: context.combatantID, in: zoomNamespace))
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
            .trinketSensoryFeedback(
                .success,
                trigger: salvageSuccessCount,
                enabled: appState.options.hapticsEnabled
            )
    }

    private var collectionBrowseContent: some View {
        let inventoryState = appState.inventory
        let shelfLimit = TrinketDesign.Metrics.collectionShelfPreviewLimit
        let shelfItems = Array(inventoryState.items.prefix(shelfLimit))

        return ScrollView {
            VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
                combatantCategorySection(
                    title: "Heroes",
                    accessibilityIdentifier: AccessibilityID.Collection.heroesCategory,
                    kind: .hero,
                    combatants: Array(
                        appState.roster.collectionHeroes.prefix(shelfLimit)
                    )
                )

                combatantCategorySection(
                    title: "Companions",
                    accessibilityIdentifier: AccessibilityID.Collection.companionsCategory,
                    kind: .companion,
                    combatants: Array(
                        appState.roster.collectionCompanions.prefix(shelfLimit)
                    )
                )

                if !inventoryState.items.isEmpty {
                    CategoryBrowseShelf(
                        title: "Inventory",
                        linkAccessibilityIdentifier: AccessibilityID.Collection.inventoryCategory
                    ) {
                        InventoryGridView()
                    } content: {
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
                            .matchedTransitionSource(id: item.id, in: zoomNamespace)
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

        Task { @MainActor in
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
    }

    private func combatantCategorySection(
        title: String,
        accessibilityIdentifier: String,
        kind: CombatantDetailContext.Kind,
        combatants: [Combatant]
    ) -> some View {
        CategoryBrowseShelf(
            title: title,
            linkAccessibilityIdentifier: accessibilityIdentifier
        ) {
            CollectionCombatantGridView(kind: kind)
        } content: {
            ForEach(combatants) { combatant in
                CollectionCombatantButton(
                    combatant: combatant,
                    isLocked: !appState.roster.isUnlocked(combatant),
                    cardWidth: nil,
                    showsName: false
                ) {
                    selectedCombatant = CombatantDetailContext(kind: kind, combatantID: combatant.id)
                }
                .matchedTransitionSource(id: combatant.id, in: zoomNamespace)
                .collectionShelfCardWidth()
            }
        }
    }
}
