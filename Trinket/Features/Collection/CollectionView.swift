import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct CollectionView: View {
    @Environment(\.requestFullGameOffer) private var requestOffer
    @Environment(\.isLaunchPresentationReady) private var isLaunchPresentationReady
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(OptionsStore.self) private var options
    @State private var salvageDetail = SalvageDetailState()
    @State private var selectedCombatant: CombatantDetailContext?
    @State private var showMissingItem = false
    @State private var pinnedDetailArtwork: [String] = []
    @Namespace private var zoomNamespace

    let consumePendingPresentation: () -> LaunchPresentation?

    init(consumePendingPresentation: @escaping () -> LaunchPresentation? = { nil }) {
        self.consumePendingPresentation = consumePendingPresentation
    }

    var body: some View {
        collectionBrowseContent
            .trinketScreenBackground()
            .scrollEdgeEffectStyle(.soft, for: .top)
            .accessibilityIdentifier(AccessibilityID.Screen.collection)
            .navigationTitle("Collection")
            .navigationBarTitleDisplayMode(.large)
            .onAppear(perform: presentPendingLaunchRoute)
            .onChange(of: isLaunchPresentationReady) { _, _ in
                presentPendingLaunchRoute()
            }
            .task(id: imminentDetailArtworkPinKey) {
                await refreshImminentDetailArtworkPins()
            }
            .onDisappear {
                PreparedArtworkCache.shared.releasePins(names: pinnedDetailArtwork)
                pinnedDetailArtwork = []
            }
            .alert("Item Not Found", isPresented: $showMissingItem) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("That item isn't in your collection.")
            }
            .salvageInventoryPresentation(
                salvageDetail: $salvageDetail,
                hapticsEnabled: options.hapticsEnabled,
            )
            .modifier(
                CollectionCombatantDetailSheet(
                    selection: $selectedCombatant,
                    zoomNamespace: zoomNamespace,
                    issuesSignposts: true,
                ),
            )
    }

    private var collectionBrowseContent: some View {
        let inventoryState = playerSave.inventory
        let rosterState = playerSave.roster
        let ownedIDs = Set(inventoryState.items.map(\.id))
        let shelfLimit = TrinketDesign.Layout.collectionShelfPreviewLimit

        let heroes = rosterState.collectionHeroes
        let companions = rosterState.collectionCompanions

        return ScrollView {
            VStack(spacing: TrinketDesign.Layout.sectionSpacing) {
                combatantCategorySection(
                    title: "Heroes",
                    accessibilityIdentifier: AccessibilityID.Collection.heroesCategory,
                    kind: .hero,
                    combatants: Array(heroes.prefix(shelfLimit)),
                    totalCount: heroes.count,
                    roster: rosterState,
                )

                combatantCategorySection(
                    title: "Companions",
                    accessibilityIdentifier: AccessibilityID.Collection.companionsCategory,
                    kind: .companion,
                    combatants: Array(companions.prefix(shelfLimit)),
                    totalCount: companions.count,
                    roster: rosterState,
                )

                ForEach(CollectionItemCategory.allCases) { category in
                    let items = category.collectionItems(in: inventoryState.items)
                    if !items.isEmpty {
                        CategoryBrowseShelf(
                            title: category.rawValue,
                            linkAccessibilityIdentifier: category.accessibilityIdentifier,
                            totalCount: items.count,
                        ) {
                            InventoryGridView(category: category)
                        } content: {
                            ForEach(Array(items.prefix(shelfLimit))) { item in
                                SalvageItemButton(
                                    item: item,
                                    isLocked: !ownedIDs.contains(item.id),
                                    showsName: false,
                                ) {
                                    salvageDetail.select(item)
                                }
                                .collectionShelfCardWidth()
                            }
                        }
                    }
                }
            }
            .padding(.top, TrinketDesign.Layout.compactContentTopPadding)
            .padding(.bottom, TrinketDesign.Layout.sectionSpacing)
        }
    }

    private var imminentDetailArtworkPinKey: [String] {
        Self.imminentDetailArtworkNames(roster: playerSave.roster).sorted()
    }

    static func imminentDetailArtworkNames(roster: PlayerRosterState) -> [String] {
        let shelfLimit = TrinketDesign.Layout.collectionShelfPreviewLimit
        let combatants = Array(roster.collectionHeroes.prefix(shelfLimit))
            + Array(roster.collectionCompanions.prefix(shelfLimit))
        var names: [String] = []
        for combatant in combatants {
            if let fullName = combatant.artReference?.imageName {
                names.append(fullName)
            }
            for ability in roster.configuredCombatant(combatant).abilities {
                if let reference = ability.artReference {
                    names.append(reference.thumbnailImageName ?? reference.imageName)
                }
            }
            for tree in CombatantTalentCatalog.config(for: combatant.id).trees {
                if let reference = tree.keyword.artReference {
                    names.append(reference.thumbnailImageName ?? reference.imageName)
                }
            }
        }
        return names
    }

    private func refreshImminentDetailArtworkPins() async {
        pinnedDetailArtwork = await ArtworkPinSet.refresh(
            next: Self.imminentDetailArtworkNames(roster: playerSave.roster),
            current: pinnedDetailArtwork,
        )
    }

    private func presentCombatant(_ context: CombatantDetailContext) {
        guard playerSave.contentAccess.allowsCombatant(context.combatantID) else {
            requestOffer(.combatant(context.combatantID))
            return
        }
        selectedCombatant = context
    }

    private func presentPendingLaunchRoute() {
        guard isLaunchPresentationReady,
              let presentation = consumePendingPresentation() else { return }

        Task { @MainActor in
            switch presentation {
            case let .collectionCombatant(context):
                presentCombatant(context)
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
        roster: PlayerRosterState,
    ) -> some View {
        CategoryBrowseShelf(
            title: title,
            linkAccessibilityIdentifier: accessibilityIdentifier,
            totalCount: totalCount,
        ) {
            CollectionCombatantGridView(kind: kind)
        } content: {
            ForEach(combatants) { combatant in
                CollectionCombatantButton(
                    combatant: combatant,
                    isLocked: !roster.isUnlocked(combatant) || !playerSave.contentAccess.allowsCombatant(combatant.id),
                    cardWidth: nil,
                    showsName: false,
                ) {
                    presentCombatant(CombatantDetailContext(kind: kind, combatantID: combatant.id))
                }
                .matchedTransitionSource(id: combatant.id, in: zoomNamespace)
                .collectionShelfCardWidth()
            }
        }
    }
}
