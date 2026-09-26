import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct BlacksmithForgePreview: View {
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
    @State private var error: String?

    let recipe: BlacksmithRecipe
    let resultNamespace: Namespace.ID
    let onOpenResult: (InventoryItem, Bool) -> Void

    private var canAfford: Bool {
        recipe.cost.allSatisfy { playerSave.homestead.balance(for: $0.resource, roster: playerSave.roster) >= $0.quantity }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: TrinketDesign.Spacing.large) {
                    previewCard
                        .frame(width: cardWidth(in: geometry.size.width))
                        .frame(maxWidth: .infinity)
                    controls
                }
                .padding(TrinketDesign.Layout.contentMargin)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .accessibilityIdentifier(AccessibilityID.Homestead.forgePreview)
        }
        .trinketScreenBackground()
        .navigationTitle(displayedItem == nil ? "Forge" : "Forged")
        .navigationBarTitleDisplayMode(.inline)
        .trinketFailureAlert("Unable to Forge", message: $error)
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
                    Text(balanced: recipe.baseType.name)
                        .trinketTypography(.cardLabel)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .trinketArtworkCardButtonStyle()
        .disabled(displayedItem == nil)
        .accessibilityLabel(displayedItem?.displayName ?? recipe.baseType.name)
        .accessibilityIdentifier(AccessibilityID.Homestead.forgeResult)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            if displayedItem != nil {
                Label("Added to Inventory", systemImage: "checkmark.circle.fill")
                    .trinketTypography(.rowTitle)
                    .foregroundStyle(TrinketDesign.Colors.accent)
                    .frame(maxWidth: .infinity)
                Button { dismiss() } label: {
                    Text("Done").frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton(accessibilityIdentifier: AccessibilityID.Homestead.forgeDone)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], alignment: .leading) {
                    ForEach(recipe.cost) { amount in
                        HomesteadMaterialValue(
                            resource: amount.resource,
                            value: amount.quantity.formatted(),
                            isInsufficient: playerSave.homestead.balance(for: amount.resource, roster: playerSave.roster) < amount.quantity,
                        )
                    }
                }
                Button(action: forge) {
                    Text(isPending ? "Finishing…" : "Forge").frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton(accessibilityIdentifier: AccessibilityID.Homestead.forgeButton)
                .disabled(!canAfford || isPending || result != nil || playerSave.homestead.tier(for: .blacksmithForge) == 0)
            }
        }
    }

    private func forge() {
        guard !isPending, result == nil else { return }
        hasOpenedResult = false
        isPending = true
        Task {
            let outcome = await playerSave.forgeBlacksmithItem(recipeID: recipe.id)
            isPending = false
            switch outcome {
            case let .success(item): result = item
            case .failure(.insufficientResources): error = "Not enough materials."
            case .failure(.unavailable): error = "Build the Blacksmith to forge equipment."
            case .failure(.alreadyOwned): error = "This item is already in your Inventory."
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var successCount = 0
    @State private var hasAppeared = false

    let item: InventoryItem
    let celebrates: Bool

    var body: some View {
        ItemDetailView(
            item: item,
            heroNote: "Added to Inventory",
            heroNoteAccessibilityID: AccessibilityID.Homestead.forgeAdded,
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Homestead.forgeDetail)
        .trinketSensoryFeedback(.success, trigger: successCount, enabled: options.hapticsEnabled)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            if celebrates, scenePhase == .active {
                successCount += 1
            }
        }
    }
}
