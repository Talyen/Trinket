import SwiftUI
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct SalvageTransmutationEvent: Identifiable {
    let id = UUID()
    let item: InventoryItem
    let yields: [ResourceAmount]
    let inventoryIndex: Int?
    var hasReturned = false
}

struct SalvageItemButton: View {
    @Environment(\.salvageZoomNamespace) private var zoomNamespace
    let item: InventoryItem
    var isLocked = false
    let showsName: Bool
    var isPreparing = false
    var isRetiring = false
    var isTransmuting = false
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ItemCard(
                item: item,
                showsAffixCount: false,
                isLocked: isLocked && !isRetiring,
                showsName: showsName,
                isSelected: isPreparing,
            ) {
                ItemArtwork(item: item, variant: .thumbnail)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .optionalMatchedTransitionSource(id: item.id, in: zoomNamespace)
                    .anchorPreference(key: SalvageArtworkAnchors.self, value: .bounds) { [item.id: $0] }
            }
        }
        .trinketArtworkCardButtonStyle()
        .disabled(isLocked)
        .trinketPresentationVisibility(!isRetiring, opacity: isTransmuting ? 0 : 1)
        .animation(nil, value: isTransmuting)
        .accessibilityLabel(isLocked ? "\(item.displayName), locked" : item.displayName)
        .accessibilityIdentifier(AccessibilityID.Collection.itemCard(itemID: item.id))
    }
}

struct SalvageTransmutationLayer: View {
    let event: SalvageTransmutationEvent
    let sourceFrame: CGRect
    let onFinished: () -> Void

    var body: some View {
        SalvageTransmutationEffect(event: event, onFinished: onFinished)
            .frame(width: sourceFrame.width, height: sourceFrame.height)
            .position(x: sourceFrame.midX, y: sourceFrame.midY)
            .allowsHitTesting(false)
    }
}

struct SalvageArtworkAnchors: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] {
        [:]
    }

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

extension EnvironmentValues {
    @Entry var salvageZoomNamespace: Namespace.ID?
}

private struct SalvageTransmutationEffect: View {
    private static let materialRevealDelay: TimeInterval = 0.30
    private static let materialDisplayDuration: TimeInterval = 0.60

    let event: SalvageTransmutationEvent
    let onFinished: () -> Void

    @State private var showsMaterials = false
    @State private var materialsDeparted = false

    var body: some View {
        ZStack {
            departingArtwork

            HStack(spacing: TrinketDesign.Spacing.small) {
                ForEach(Array(event.yields.enumerated()), id: \.offset) { index, yield in
                    VStack(spacing: TrinketDesign.Spacing.tight) {
                        HomesteadResourceArtwork(resource: yield.resource)
                            .frame(
                                width: TrinketDesign.Layout.walletResourceArtworkSize,
                                height: TrinketDesign.Layout.walletResourceArtworkSize,
                            )
                        Text("+\(yield.quantity)")
                            .trinketTypography(.statValue)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    .padding(TrinketDesign.Spacing.small)
                    .trinketMaterial(
                        .subtleOverlay,
                        cornerRadius: TrinketDesign.Corners.card,
                    )
                    .shadow(
                        color: yield.resource.tint.opacity(0.28),
                        radius: TrinketDesign.Spacing.small,
                    )
                    .scaleEffect(showsMaterials ? 1 : 0.55)
                    .opacity(showsMaterials && !materialsDeparted ? 1 : 0)
                    .animation(
                        TrinketMotion.Reward.reveal.delay(
                            Double(index) * TrinketMotion.Reward.entranceStagger,
                        ),
                        value: showsMaterials,
                    )
                    .animation(TrinketMotion.Content.fade, value: materialsDeparted)
                }
            }
            .zIndex(1)
        }
        .task(id: event.id) {
            await play()
        }
    }

    private var departingArtwork: some View {
        CardDissolveArtwork {
            ItemArtwork(item: event.item, variant: .full)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(TrinketDesign.cardShape)
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
    }

    @MainActor
    private func play() async {
        try? await Task.sleep(for: .seconds(Self.materialRevealDelay))
        guard !Task.isCancelled else { return }
        withAnimation(TrinketMotion.Reward.reveal) {
            showsMaterials = true
        }
        try? await Task.sleep(for: .seconds(Self.materialDisplayDuration))

        guard !Task.isCancelled else { return }
        withAnimation(TrinketMotion.Content.fade) {
            materialsDeparted = true
        }

        try? await Task.sleep(for: .seconds(TrinketMotion.Content.fadeDuration))
        guard !Task.isCancelled else { return }
        onFinished()
    }
}
