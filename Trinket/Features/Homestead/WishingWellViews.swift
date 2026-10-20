import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct WishingWellView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(OptionsStore.self) private var options
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @State private var showsTrinkets = false
    @State private var isPending = false
    @State private var successCount = 0
    @State private var isVisible = false
    @State private var visibleIDs: Set<String> = []

    private var missing: [InventoryItem] {
        let owned = Set(playerSave.inventory.items.map(\.templateID))
        return (showsTrinkets ? GameContent.trinketItems : GameContent.uniqueItems).filter { !owned.contains($0.templateID) }
    }

    private var hasMissingItems: Bool {
        let owned = Set(playerSave.inventory.items.map(\.templateID))
        return (GameContent.uniqueItems + GameContent.trinketItems).contains { !owned.contains($0.templateID) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.large) {
                Text(L10n.homestead_wish_choose)
                Text(L10n.homestead_wish_help(50)).foregroundStyle(.secondary)
                Text(L10n.homestead_wish_rates).foregroundStyle(.secondary)
                Text(L10n.homestead_wish_last).foregroundStyle(.secondary)
                if let id = playerSave.homestead.wishedTemplateID,
                   let item = (GameContent.uniqueItems + GameContent.trinketItems).first(where: { $0.templateID == id }) {
                    Text(L10n.homestead_wishing_for(item.localizedDisplayName(locale: locale))).trinketTypography(.rowTitle)
                    Button(action: clearWish) {
                        HStack {
                            if isPending {
                                ProgressView()
                            }
                            Text(L10n.homestead_clear_wish)
                        }
                    }.disabled(isPending)
                        .accessibilityIdentifier(AccessibilityID.Homestead.clearWish)
                }
                if hasMissingItems {
                    Picker(selection: $showsTrinkets) {
                        Text(L10n.homestead_uniques).tag(false)
                        Text(L10n.homestead_trinkets).tag(true)
                    } label: { Text(L10n.homestead_make_wish) }
                        .pickerStyle(.segmented)
                    LazyVGrid(columns: TrinketDesign.Layout.collectionGridItems, spacing: TrinketDesign.Spacing.large) {
                        ForEach(missing) { item in
                            NavigationLink {
                                WishItemDetail(item: item)
                            } label: {
                                ProductCardShell {
                                    ItemArtwork(item: item, variant: .thumbnail)
                                } label: {
                                    ItemCardLabel(item: item, showsAffixCount: false)
                                }
                            }
                            .trinketArtworkCardButtonStyle()
                            .accessibilityLabel(item.localizedDisplayName(locale: locale))
                            .accessibilityIdentifier(AccessibilityID.Homestead.wishItem(item.templateID))
                            .onAppear { visibleIDs.insert(item.id) }
                            .onDisappear { visibleIDs.remove(item.id) }
                        }
                    }
                } else {
                    Text(L10n.homestead_all_collected)
                }
            }
            .padding(TrinketDesign.Layout.contentMargin)
        }
        .trinketScreenBackground()
        .trinketSoftTopScrollEdge()
        .navigationTitle(String(localized: L10n.homestead_make_wish))
        .trinketSensoryFeedback(.success, trigger: successCount, enabled: options.hapticsEnabled)
        .task(id: visibleIDs) {
            await ArtworkViewportPrewarm.prewarm(
                orderedItems: missing, visibleIDs: visibleIDs, currentVisibleIDs: { visibleIDs },
                thumbnailName: { $0.artReference?.thumbnailImageName ?? $0.artReference?.imageName },
                prefetchRows: ArtworkViewportPrewarm.defaultPrefetchRows,
                estimatedColumns: ArtworkViewportPrewarm.collectionEstimatedColumns,
            )
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }

    private func clearWish() {
        guard !isPending else { return }
        isPending = true
        let generation = playerSave.sessionGeneration
        Task {
            let outcome = await playerSave.setItemWish(nil)
            isPending = false
            guard generation == playerSave.sessionGeneration, isVisible, scenePhase == .active else { return }
            if case .success = outcome {
                successCount += 1
            }
        }
    }
}

private struct WishItemDetail: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(OptionsStore.self) private var options
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let item: InventoryItem
    @State private var isPending = false
    @State private var isVisible = false
    @State private var artworkPins = PreparedArtworkPinSet()
    @State private var successCount = 0

    var body: some View {
        ItemDetailView(
            item: item,
            primaryActionTitle: LibraryCopy.localized(L10n.homestead_wish_for(item.localizedDisplayName(locale: locale)), locale: locale),
            primaryActionAccessibilityID: AccessibilityID.Homestead.wish,
            onPrimaryAction: makeWish,
        )
        .disabled(isPending || ItemWish.validTarget(item.templateID, inventory: playerSave.inventory.items) == nil)
        .overlay {
            if isPending {
                ProgressView()
            }
        }
        .trinketSensoryFeedback(.success, trigger: successCount, enabled: options.hapticsEnabled)
        .task(id: item.id) { await artworkPins.prepare(names: [item.artReference?.imageName].compactMap(\.self)) }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false; artworkPins.release() }
    }

    private func makeWish() {
        guard !isPending else { return }
        isPending = true
        let generation = playerSave.sessionGeneration
        Task {
            let outcome = await playerSave.setItemWish(item.templateID)
            isPending = false
            guard generation == playerSave.sessionGeneration, isVisible, scenePhase == .active else { return }
            if case .success = outcome {
                successCount += 1
                dismiss()
            }
        }
    }
}
