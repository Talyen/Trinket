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
    @State private var salvageDetail = SalvageItemDetailController()
    @State private var selectedCombatant: CombatantDetailContext?
    @State private var showMissingItem = false
    @Namespace private var zoomNamespace

    let consumePendingPresentation: () -> LaunchPresentation?

    init(consumePendingPresentation: @escaping () -> LaunchPresentation? = { nil }) {
        self.consumePendingPresentation = consumePendingPresentation
    }

    var body: some View {
        @Bindable var salvageDetail = salvageDetail
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
            .sheet(item: $salvageDetail.selectedItem) { item in
                SalvageItemDetailSheet(
                    controller: salvageDetail,
                    item: item,
                    zoomNamespace: zoomNamespace,
                    resolveIndex: { resolvedItem in
                        playerSave.inventory.items.firstIndex(where: { $0.id == resolvedItem.id }) ?? 0
                    }
                )
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
                trigger: salvageDetail.salvageSuccessCount,
                enabled: options.hapticsEnabled
            )
    }

    private var collectionBrowseContent: some View {
        let inventoryState = playerSave.inventory
        let rosterState = playerSave.roster
        let shelfLimit = TrinketDesign.Metrics.collectionShelfPreviewLimit
        let shelfItems = SalvageDissolvePresentation.displayedItems(
            Array(inventoryState.items.prefix(shelfLimit)),
            tombstone: salvageDetail.dissolvingTombstone
        )
        let showsInventoryShelf = !inventoryState.items.isEmpty || salvageDetail.dissolvingTombstone != nil

        let heroes = rosterState.collectionHeroes
        let companions = rosterState.collectionCompanions

        return ScrollView {
            VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
                combatantCategorySection(
                    title: "Heroes",
                    accessibilityIdentifier: AccessibilityID.Collection.heroesCategory,
                    kind: .hero,
                    combatants: Array(heroes.prefix(shelfLimit)),
                    totalCount: heroes.count,
                    roster: rosterState
                )

                combatantCategorySection(
                    title: "Companions",
                    accessibilityIdentifier: AccessibilityID.Collection.companionsCategory,
                    kind: .companion,
                    combatants: Array(companions.prefix(shelfLimit)),
                    totalCount: companions.count,
                    roster: rosterState
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
                            let isDissolving = salvageDetail.dissolvingTombstone?.item.id == item.id
                            Group {
                                if isDissolving {
                                    SalvageAwareItemCard(
                                        item: item,
                                        showsAffixCount: false,
                                        showsName: false,
                                        isDissolving: true,
                                        onDissolveFinished: salvageDetail.finishDissolve
                                    )
                                    .collectionShelfCardWidth()
                                    .accessibilityIdentifier("\(item.displayName) item card")
                                } else {
                                    Button {
                                        salvageDetail.select(item, at: index)
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

    private func presentPendingLaunchRoute() {
        guard let presentation = consumePendingPresentation() else { return }

        Task { @MainActor in
            switch presentation {
            case let .collectionCombatant(context):
                selectedCombatant = context
            case let .collectionItem(itemID):
                if let owned = playerSave.inventory.item(matching: itemID) {
                    salvageDetail.select(owned, at: playerSave.inventory.items.firstIndex(where: { $0.id == itemID }))
                } else if let template = GameContent.itemTemplate(matching: itemID) {
                    salvageDetail.select(template, at: nil)
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
        totalCount: Int,
        roster: PlayerRosterState
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
                    isLocked: !roster.isUnlocked(combatant),
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
