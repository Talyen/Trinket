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
                    zoomNamespace: zoomNamespace
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
            .overlay {
                if let event = salvageDetail.transmutationEvent {
                    SalvageTransmutationLayer(
                        event: event,
                        zoomNamespace: zoomNamespace
                    ) {
                        salvageDetail.finishTransmutation(id: event.id)
                    }
                }
            }
    }

    private var collectionBrowseContent: some View {
        let inventoryState = playerSave.inventory
        let rosterState = playerSave.roster
        let shelfLimit = TrinketDesign.Metrics.collectionShelfPreviewLimit
        let shelfItems = Array(inventoryState.items.prefix(shelfLimit))

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

                if !inventoryState.items.isEmpty {
                    CategoryBrowseShelf(
                        title: "Inventory",
                        linkAccessibilityIdentifier: AccessibilityID.Collection.inventoryCategory,
                        totalCount: inventoryState.items.count
                    ) {
                        InventoryGridView()
                    } content: {
                        ForEach(shelfItems) { item in
                            SalvageItemButton(
                                item: item,
                                showsName: false,
                                zoomNamespace: zoomNamespace
                            ) { sourceFrame in
                                salvageDetail.select(
                                    item,
                                    sourceFrame: sourceFrame,
                                    showsName: false
                                )
                            }
                            .collectionShelfCardWidth()
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
                    salvageDetail.select(owned)
                } else if let template = GameContent.itemTemplate(matching: itemID) {
                    salvageDetail.select(template)
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
