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
}

struct SalvageItemButton: View {
    let item: InventoryItem
    let showsName: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ItemCard(
                item: item,
                showsAffixCount: false,
                showsName: showsName,
            )
        }
        .trinketQuietTapButtonStyle()
        .accessibilityLabel(item.displayName)
        .accessibilityIdentifier(AccessibilityID.Collection.itemCard(itemID: item.id))
    }
}

struct SalvageTransmutationLayer: View {
    let event: SalvageTransmutationEvent
    let onFinished: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width * 0.56, geometry.size.height * 0.36)
            SalvageTransmutationEffect(event: event, onFinished: onFinished)
                .frame(width: width)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .allowsHitTesting(false)
    }
}

private struct SalvageTransmutationEffect: View {
    let event: SalvageTransmutationEvent
    let onFinished: () -> Void

    @State private var isDissolving = false
    @State private var showsMaterials = false
    @State private var materialsDeparted = false

    var body: some View {
        ZStack {
            departingArtwork

            HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                ForEach(Array(event.yields.enumerated()), id: \.offset) { index, yield in
                    VStack(spacing: TrinketDesign.Metrics.tightSpacing) {
                        HomesteadResourceArtwork(resource: yield.resource)
                            .frame(
                                width: TrinketDesign.Metrics.walletResourceArtworkSize,
                                height: TrinketDesign.Metrics.walletResourceArtworkSize,
                            )
                        Text("+\(yield.quantity)")
                            .trinketTypography(.statValue)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    .padding(TrinketDesign.Metrics.smallSpacing)
                    .trinketMaterial(
                        .subtleOverlay,
                        cornerRadius: TrinketDesign.Corners.card,
                    )
                    .shadow(
                        color: yield.resource.tint.opacity(0.28),
                        radius: TrinketDesign.Metrics.smallSpacing,
                    )
                    .scaleEffect(showsMaterials ? 1 : 0.55)
                    .opacity(showsMaterials && !materialsDeparted ? 1 : 0)
                    .animation(
                        TrinketMotion.Reward.reveal.delay(
                            Double(index) * TrinketMotion.Reward.resourceStagger,
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

    @ViewBuilder
    private var departingArtwork: some View {
        let art = ItemArtwork(item: event.item, variant: .full)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(TrinketDesign.cardShape)

        Group {
            if isDissolving {
                BattleDissolveArtwork(celebratesDefeat: false) {
                    art
                }
            } else {
                art
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
    }

    @MainActor
    private func play() async {
        try? await Task.sleep(for: .seconds(0.22))
        guard !Task.isCancelled else { return }
        isDissolving = true

        try? await Task.sleep(for: .seconds(TrinketMotion.Content.cardDissolveDuration))
        guard !Task.isCancelled else { return }
        withAnimation(TrinketMotion.Reward.reveal) {
            showsMaterials = true
        }
        try? await Task.sleep(for: .seconds(0.85))

        guard !Task.isCancelled else { return }
        withAnimation(TrinketMotion.Content.fade) {
            materialsDeparted = true
        }

        try? await Task.sleep(for: .seconds(0.35))
        guard !Task.isCancelled else { return }
        onFinished()
    }
}
