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
    let sourceFrame: CGRect?
    let showsName: Bool
}

/// Captures the card's visible origin so salvage feedback can leave grid layout
/// immediately while a non-layout ghost completes the transmutation effect.
struct SalvageItemButton: View {
    let item: InventoryItem
    let showsName: Bool
    let zoomNamespace: Namespace.ID
    let onSelect: (CGRect?) -> Void

    @State private var sourceFrame: CGRect?

    var body: some View {
        Button {
            onSelect(sourceFrame)
        } label: {
            ItemCard(
                item: item,
                showsAffixCount: false,
                showsName: showsName
            )
        }
        .trinketQuietTapButtonStyle()
        .matchedTransitionSource(id: item.id, in: zoomNamespace)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            sourceFrame = frame.isUsableSalvageOrigin ? frame : nil
        }
        .accessibilityIdentifier(AccessibilityID.Collection.itemCard(itemID: item.id))
    }
}

private extension CGRect {
    var isUsableSalvageOrigin: Bool {
        !isEmpty
            && !isNull
            && !isInfinite
            && origin.x.isFinite
            && origin.y.isFinite
            && width.isFinite
            && height.isFinite
    }
}

/// Positions transient salvage feedback over the departed card without taking a
/// grid slot. A missing source (for example a deep link) falls back to center.
struct SalvageTransmutationLayer: View {
    let event: SalvageTransmutationEvent
    let zoomNamespace: Namespace.ID
    let onFinished: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let containerFrame = geometry.frame(in: .global)
            if let sourceFrame = event.sourceFrame, sourceFrame.isUsableSalvageOrigin {
                SalvageTransmutationEffect(event: event, showsItem: true, onFinished: onFinished)
                    .frame(width: sourceFrame.width, height: sourceFrame.height)
                    .position(
                        x: sourceFrame.midX - containerFrame.minX,
                        y: sourceFrame.midY - containerFrame.minY
                    )
                    .matchedTransitionSource(id: event.item.id, in: zoomNamespace)
            } else {
                SalvageTransmutationEffect(event: event, showsItem: false, onFinished: onFinished)
                    .frame(maxWidth: geometry.size.width)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct SalvageTransmutationEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let event: SalvageTransmutationEvent
    let showsItem: Bool
    let onFinished: () -> Void

    @State private var isDissolving = false
    @State private var showsMaterials = false
    @State private var materialsDeparted = false

    var body: some View {
        ZStack {
            if showsItem {
                departingItem
            }

            HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                ForEach(Array(event.yields.enumerated()), id: \.offset) { index, yield in
                    VStack(spacing: TrinketDesign.Metrics.tightSpacing) {
                        HomesteadResourceArtwork(resource: yield.resource)
                            .frame(
                                width: TrinketDesign.Metrics.walletResourceArtworkSize,
                                height: TrinketDesign.Metrics.walletResourceArtworkSize
                            )
                        Text("+\(yield.quantity)")
                            .trinketTypography(.statValue)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    .padding(TrinketDesign.Metrics.denseSpacing)
                    .trinketMaterial(
                        .subtleOverlay,
                        cornerRadius: TrinketDesign.Corners.card
                    )
                    .shadow(
                        color: yield.resource.tint.opacity(0.28),
                        radius: TrinketDesign.Metrics.smallSpacing
                    )
                    .scaleEffect(showsMaterials ? 1 : 0.72)
                    .offset(y: materialsDeparted ? -54 : (showsMaterials ? -18 : 8))
                    .opacity(showsMaterials && !materialsDeparted ? 1 : 0)
                    .animation(
                        TrinketMotion.Reward.reveal.delay(
                            Double(index) * TrinketMotion.Reward.resourceStagger
                        ),
                        value: showsMaterials
                    )
                }
            }
            .zIndex(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .task(id: event.id) {
            await play()
        }
    }

    @ViewBuilder
    private var departingItem: some View {
        if reduceMotion {
            ItemCard(
                item: event.item,
                showsAffixCount: false,
                showsName: event.showsName
            )
            .opacity(isDissolving ? 0 : 1)
        } else if isDissolving {
            ItemCard(
                item: event.item,
                showsAffixCount: false,
                showsName: event.showsName,
                fadesLabel: true
            ) {
                BattleDissolveArtwork(celebratesDefeat: false) {
                    ItemArtwork(item: event.item, variant: .thumbnail)
                }
            }
        } else {
            ItemCard(
                item: event.item,
                showsAffixCount: false,
                showsName: event.showsName
            )
        }
    }

    private var accessibilitySummary: String {
        let amounts = ItemDetailView.formattedYieldList(event.yields)
        return "Salvaged \(event.item.displayName). Received \(amounts)."
    }

    @MainActor
    private func play() async {
        try? await Task.sleep(for: .seconds(reduceMotion ? 0.12 : 0.28))
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? TrinketMotion.Content.fade : TrinketMotion.Reward.reveal) {
            isDissolving = true
            showsMaterials = true
        }
        AccessibilityNotification.Announcement(accessibilitySummary).post()

        try? await Task.sleep(for: .seconds(reduceMotion ? 0.45 : 0.62))
        guard !Task.isCancelled else { return }
        withAnimation(TrinketMotion.Content.fade) {
            materialsDeparted = true
        }

        try? await Task.sleep(for: .seconds(reduceMotion ? 0.2 : 0.4))
        guard !Task.isCancelled else { return }
        onFinished()
    }
}
