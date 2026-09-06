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
            .sheet(item: $selectedCombatant) { context in
                NavigationStack {
                    RosterCombatantDetailView(
                        kind: context.kind,
                        combatantID: context.combatantID,
                        hapticsEnabled: options.hapticsEnabled,
                        effectsVolume: options.effectsVolume,
                    )
                }
                .navigationTransition(.zoom(sourceID: context.combatantID, in: zoomNamespace))
                .trinketDetailSheet()
                .appFramePacingSignpost(
                    AppFramePacingSignposts.Name.sheetPresent,
                    isActive: true,
                )
                .onAppear {
                    AppFramePacingSignposts.event(
                        AppFramePacingSignposts.Name.sheetPresent,
                        detail: "collectionCombatant=\(context.combatantID)",
                    )
                }
            }
    }

    private var collectionBrowseContent: some View {
        let inventoryState = playerSave.inventory
        let rosterState = playerSave.roster
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
                    let items = inventoryState.items.filter(category.contains)
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
        let next = Array(Set(Self.imminentDetailArtworkNames(roster: playerSave.roster))).sorted()
        let previous = Set(pinnedDetailArtwork)
        let added = Set(next).subtracting(previous)
        let removed = previous.subtracting(next)
        if !added.isEmpty {
            let addedNames = Array(added)
            await PreparedArtworkCache.shared.prepareAndPin(names: addedNames)
            guard !Task.isCancelled else {
                PreparedArtworkCache.shared.releasePins(names: addedNames)
                return
            }
        }
        guard !Task.isCancelled else { return }
        if !removed.isEmpty {
            PreparedArtworkCache.shared.releasePins(names: Array(removed))
        }
        pinnedDetailArtwork = next
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
                    isLocked: !roster.isUnlocked(combatant),
                    cardWidth: nil,
                    showsName: false,
                ) {
                    selectedCombatant = CombatantDetailContext(kind: kind, combatantID: combatant.id)
                }
                .matchedTransitionSource(id: combatant.id, in: zoomNamespace)
                .collectionShelfCardWidth()
            }
        }
    }
}
