import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct BlacksmithForgePreview: View {
    @Environment(\.locale) private var locale
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var result: InventoryItem?
    @State private var displayedItem: InventoryItem?
    @State private var artworkLease: PreparedArtworkLease?
    @State private var previewArtworkLease: PreparedArtworkLease?
    @State private var isPending = false
    @State private var isVisible = false
    @State private var hasOpenedResult = false

    let recipe: BlacksmithRecipe
    let resultNamespace: Namespace.ID
    let onOpenResult: (InventoryItem, Bool) -> Void
    var onViewResearch: ((String) -> Void)?
    var readOnly = false
    var onOpenWorkshop: (() -> Void)?

    private var learned: Bool {
        recipe.researchID == nil || (playerSave.library.isReadable && playerSave.library.progress.unlockedRecipeIDs.contains(recipe.id))
    }

    private var canAfford: Bool {
        recipe.cost.allSatisfy { playerSave.homestead.balance(for: $0.resource, gold: playerSave.roster.gold) >= $0.quantity }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: TrinketDesign.Spacing.small) {
                    previewCard.frame(width: cardWidth(in: geometry.size.width))
                    if recipe.requiredKeyword != nil {
                        Text(LibraryCopy.guarantee(recipe, locale: locale)).foregroundStyle(.secondary)
                        Text(L10n.library_basic_or_astral).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(TrinketDesign.Layout.contentMargin)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                controls
                    .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                    .padding(.vertical, TrinketDesign.Spacing.medium)
                    .trinketScreenBackground()
            }
            .trinketSoftTopScrollEdge()
            .accessibilityIdentifier(AccessibilityID.Homestead.forgePreview)
        }
        .trinketScreenBackground()
        .navigationTitle(recipe.buildingID == .archeryRange ? String(localized: L10n.library_craft) :
            displayedItem == nil ? String(localized: L10n.ui_blacksmithforgepreview_forge_8899e) :
            String(localized: L10n.ui_blacksmithforgepreview_forged_ac158))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: recipe.id) { await preparePreviewArtwork() }
        .task(id: result?.id) { await prepareArtwork() }
        .onChange(of: displayedItem?.id) { _, _ in
            guard let displayedItem, !hasOpenedResult else { return }
            hasOpenedResult = true
            guard isVisible, scenePhase == .active else { return }
            onOpenResult(displayedItem, true)
        }
        .onAppear { isVisible = true }
        .onDisappear {
            isVisible = false
            suppressAutomaticReveal()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                suppressAutomaticReveal()
            }
        }
    }

    private func cardWidth(in width: CGFloat) -> CGFloat {
        min(190, max(150, (width - TrinketDesign.Layout.contentMargin * 2 - TrinketDesign.Spacing.large) / 2))
    }

    private var previewCard: some View {
        Button {
            if let displayedItem {
                onOpenResult(displayedItem, false)
            }
        } label: {
            ProductCardShell {
                ZStack {
                    if let artwork = recipe.forgeArtwork {
                        Image.preparedAsset(artwork, displaySize: previewArtworkLease == nil ? .compact : .full)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .decorativePreparedArtwork()
                    }
                    if let displayedItem {
                        ItemArtwork(item: displayedItem)
                    }
                }
                .matchedTransitionSource(id: recipe.id, in: resultNamespace)
            } label: {
                if let displayedItem {
                    ItemCardLabel(item: displayedItem, showsAffixCount: false)
                } else {
                    Text(balanced: LibraryCopy.recipe(recipe, locale: locale))
                        .trinketTypography(.cardLabel)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .trinketArtworkCardButtonStyle()
        .disabled(displayedItem == nil)
        .accessibilityLabel(displayedItem?.localizedDisplayName(locale: locale) ?? recipe.baseType.localizedName(locale: locale))
        .accessibilityIdentifier(AccessibilityID.Homestead.forgeResult)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            if displayedItem != nil {
                Label(String(localized: L10n.ui_blacksmithforgepreview_added_to_inventory_52337), systemImage: "checkmark.circle.fill")
                    .trinketTypography(.rowTitle)
                    .foregroundStyle(TrinketDesign.Colors.accent)
                    .frame(maxWidth: .infinity)
                Button { dismiss() } label: {
                    Text(L10n.ui_blacksmithforgepreview_done_11a67).frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton(accessibilityIdentifier: AccessibilityID.Homestead.forgeDone)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], alignment: .leading) {
                    ForEach(recipe.cost) { amount in
                        HomesteadMaterialValue(
                            resource: amount.resource,
                            value: amount.quantity.formatted(),
                            isInsufficient: playerSave.homestead.balance(
                                for: amount.resource,
                                gold: playerSave.roster.gold,
                            ) < amount.quantity,
                        )
                    }
                }
                if !learned, let projectID = recipe.researchID {
                    Text(LibraryCopy.title(projectID, locale: locale)).foregroundStyle(.secondary)
                    if readOnly {
                        Button { onViewResearch?(projectID) } label: { Text(L10n.library_view_research) }
                            .disabled(onViewResearch == nil)
                    }
                }
                if readOnly {
                    Button { onOpenWorkshop?() } label: { Text(L10n.library_open_range).frame(maxWidth: .infinity) }
                        .trinketPrimaryActionButton(accessibilityIdentifier: AccessibilityID.Homestead.openWorkshop)
                } else if !learned, let projectID = recipe.researchID {
                    Button { onViewResearch?(projectID) } label: {
                        Text(L10n.library_view_research).frame(maxWidth: .infinity)
                    }
                    .trinketPrimaryActionButton(accessibilityIdentifier: AccessibilityID.Homestead.viewResearch)
                    .disabled(onViewResearch == nil)
                } else {
                    Button(action: forge) {
                        HStack {
                            if isPending {
                                ProgressView()
                            }
                            Text(recipe
                                .buildingID == .blacksmithForge ? String(localized: L10n.ui_blacksmithforgepreview_forge_8899e) :
                                String(localized: L10n.library_craft))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .trinketPrimaryActionButton(accessibilityIdentifier: AccessibilityID.Homestead.forgeButton)
                    .disabled(!canAfford || !learned || isPending || result != nil || playerSave.homestead
                        .tier(for: recipe.buildingID) == 0)
                }
            }
        }
    }

    private func forge() {
        guard !isPending, result == nil else { return }
        hasOpenedResult = false
        isPending = true
        Task {
            let outcome = await playerSave.craftEquipmentItem(recipeID: recipe.id)
            isPending = false
            switch outcome {
            case let .success(item): result = item
            case .failure(.insufficientResources): break
            case .failure(.unavailable): break
            case .failure(.alreadyOwned): break
            case .failure(.invalidated): break
            }
        }
    }

    private func suppressAutomaticReveal() {
        if isPending || result != nil {
            hasOpenedResult = true
        }
    }

    private func prepareArtwork() async {
        let references = [recipe.forgeArtwork, result?.artReference].compactMap(\.self)
        let names = references.flatMap { [$0.imageName, $0.thumbnailImageName].compactMap(\.self) }
        let prepared = await PreparedArtworkLease(names: names)
        guard !Task.isCancelled else { return }
        artworkLease = prepared
        displayedItem = result
    }

    private func preparePreviewArtwork() async {
        let names = [recipe.forgeArtwork?.imageName].compactMap(\.self)
        let prepared = await PreparedArtworkLease(names: names)
        guard !Task.isCancelled else { return }
        previewArtworkLease = prepared
    }
}

struct BlacksmithForgedItemView: View {
    @Environment(OptionsStore.self) private var options
    @Environment(\.playSFX) private var playSFX
    @Environment(\.scenePhase) private var scenePhase
    @State private var successCount = 0
    @State private var hasAppeared = false

    let item: InventoryItem
    let celebrates: Bool

    var body: some View {
        ItemDetailView(
            item: item,
            heroNote: String(localized: L10n.ui_blacksmithforgepreview_added_to_inventory_52337),
            heroNoteAccessibilityID: AccessibilityID.Homestead.forgeAdded,
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Homestead.forgeDetail)
        .trinketSensoryFeedback(.success, trigger: successCount, enabled: options.hapticsEnabled)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            if celebrates, scenePhase == .active {
                playSFX(SFXID.itemForge, options.effectsVolume)
                successCount += 1
            }
        }
    }
}
