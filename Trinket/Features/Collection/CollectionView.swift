import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct CollectionView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(OptionsStore.self) private var options
    @State private var selectedItem: InventoryItem?
    @State private var selectedItemIndex: Int?
    @State private var dissolvingTombstone: SalvageDissolveTombstone?
    @State private var selectedCombatant: CombatantDetailContext?
    @State private var showMissingItem = false
    @State private var salvageSuccessCount = 0
    @Namespace private var zoomNamespace

    let consumePendingPresentation: () -> LaunchPresentation?

    init(consumePendingPresentation: @escaping () -> LaunchPresentation? = { nil }) {
        self.consumePendingPresentation = consumePendingPresentation
    }

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
                    ItemDetailView.inventorySalvageDetail(item: item, saveStore: playerSave) { didSucceed in
                        if didSucceed {
                            let index = selectedItemIndex
                                ?? playerSave.inventory.items.firstIndex(where: { $0.id == item.id })
                                ?? 0
                            dissolvingTombstone = SalvageDissolveTombstone(item: item, index: index)
                            salvageSuccessCount += 1
                        }
                        selectedItem = nil
                        selectedItemIndex = nil
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
                        combatantID: context.combatantID,
                        hapticsEnabled: options.hapticsEnabled,
                        effectsVolume: options.effectsVolume
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
                enabled: options.hapticsEnabled
            )
    }

    private var collectionBrowseContent: some View {
        let inventoryState = playerSave.inventory
        let shelfLimit = TrinketDesign.Metrics.collectionShelfPreviewLimit
        let shelfItems = SalvageDissolvePresentation.displayedItems(
            Array(inventoryState.items.prefix(shelfLimit)),
            tombstone: dissolvingTombstone
        )
        let showsInventoryShelf = !inventoryState.items.isEmpty || dissolvingTombstone != nil

        return ScrollView {
            VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
                combatantCategorySection(
                    title: "Heroes",
                    accessibilityIdentifier: AccessibilityID.Collection.heroesCategory,
                    kind: .hero,
                    combatants: Array(
                        playerSave.roster.collectionHeroes.prefix(shelfLimit)
                    ),
                    totalCount: playerSave.roster.collectionHeroes.count
                )

                combatantCategorySection(
                    title: "Companions",
                    accessibilityIdentifier: AccessibilityID.Collection.companionsCategory,
                    kind: .companion,
                    combatants: Array(
                        playerSave.roster.collectionCompanions.prefix(shelfLimit)
                    ),
                    totalCount: playerSave.roster.collectionCompanions.count
                )

                if showsInventoryShelf {
                    CategoryBrowseShelf(
                        title: "Inventory",
                        linkAccessibilityIdentifier: AccessibilityID.Collection.inventoryCategory,
                        totalCount: inventoryState.items.count
                    ) {
                        InventoryGridView()
                    } content: {
                        ForEach(Array(shelfItems.enumerated()), id: \.element.id) { index, item in
                            let isDissolving = dissolvingTombstone?.item.id == item.id
                            Group {
                                if isDissolving {
                                    SalvageAwareItemCard(
                                        item: item,
                                        showsAffixCount: false,
                                        showsName: false,
                                        isDissolving: true,
                                        onDissolveFinished: finishSalvageDissolve
                                    )
                                    .collectionShelfCardWidth()
                                    .accessibilityIdentifier("\(item.displayName) item card")
                                } else {
                                    Button {
                                        selectedItem = item
                                        selectedItemIndex = index
                                    } label: {
                                        SalvageAwareItemCard(
                                            item: item,
                                            showsAffixCount: false,
                                            showsName: false,
                                            isDissolving: false
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
                }
            }
            .padding(.top, TrinketDesign.Metrics.compactContentTopPadding)
            .padding(.bottom, TrinketDesign.Metrics.sectionSpacing)
        }
    }

    private func finishSalvageDissolve() {
        withAnimation(TrinketMotion.Reward.stateChange) {
            dissolvingTombstone = nil
        }
    }

    private func presentPendingLaunchRoute() {
        guard let presentation = consumePendingPresentation() else { return }

        Task { @MainActor in
            switch presentation {
            case let .collectionCombatant(context):
                selectedCombatant = context
            case let .collectionItem(itemID):
                if let owned = playerSave.inventory.item(matching: itemID) {
                    selectedItem = owned
                    selectedItemIndex = playerSave.inventory.items.firstIndex(where: { $0.id == itemID })
                } else if let template = GameContent.itemTemplate(matching: itemID) {
                    selectedItem = template
                    selectedItemIndex = nil
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
        combatants: [Combatant],
        totalCount: Int
    ) -> some View {
        CategoryBrowseShelf(
            title: title,
            linkAccessibilityIdentifier: accessibilityIdentifier,
            totalCount: totalCount
        ) {
            CollectionCombatantGridView(kind: kind)
        } content: {
            ForEach(combatants) { combatant in
                CollectionCombatantButton(
                    combatant: combatant,
                    isLocked: !playerSave.roster.isUnlocked(combatant),
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
