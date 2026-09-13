import SwiftUI
import TrinketAppState
import TrinketDesignSystem
import TrinketFeatureSupport

private struct SalvageInventoryPresentationModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var zoomNamespace
    @State private var pinnedArtwork: [String] = []
    @Binding var salvageDetail: SalvageDetailState
    let hapticsEnabled: Bool

    func body(content: Content) -> some View {
        content
            .environment(\.salvageZoomNamespace, zoomNamespace)
            .sheet(item: $salvageDetail.selectedItem, onDismiss: {
                salvageDetail.detailDismissed()
                releaseUnusedArtwork()
            }, content: { item in
                SalvageItemDetailSheet(item: item) { result in
                    salvageDetail.salvageFinished(
                        result: result,
                        item: item,
                    )
                }
                .navigationTransition(.zoom(sourceID: item.id, in: zoomNamespace))
            })
            .overlayPreferenceValue(SalvageArtworkAnchors.self) { anchors in
                transmutationOverlay(anchors: anchors)
            }
            .task(id: salvageDetail.requestedItem?.id) { await prepareDetail() }
            .onChange(of: salvageDetail.transmutationEvent?.id) { _, _ in releaseUnusedArtwork() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    cancelTransmutation()
                }
            }
            .onDisappear {
                cancelTransmutation()
                PreparedArtworkCache.shared.releasePins(names: pinnedArtwork)
                pinnedArtwork = []
            }
            .trinketSensoryFeedback(
                .success,
                trigger: salvageDetail.salvageSuccessCount,
                enabled: hapticsEnabled,
            )
            .trinketSensoryFeedback(
                .error,
                trigger: salvageDetail.salvageErrorCount,
                enabled: hapticsEnabled,
            )
    }

    private func transmutationOverlay(anchors: [String: Anchor<CGRect>]) -> some View {
        GeometryReader { geometry in
            if let event = salvageDetail.transmutationEvent, event.hasReturned {
                if let anchor = anchors[event.item.id] {
                    let frame = geometry[anchor]
                    let isVisible = frame.intersects(CGRect(origin: .zero, size: geometry.size))
                    SalvageTransmutationLayer(event: event, sourceFrame: frame) {
                        salvageDetail.finishTransmutation(id: event.id)
                    }
                    .onChange(of: isVisible, initial: true) { _, visible in
                        if !visible {
                            salvageDetail.finishTransmutation(id: event.id)
                        }
                    }
                } else {
                    Color.clear.onAppear {
                        salvageDetail.finishTransmutation(id: event.id)
                    }
                }
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func prepareDetail() async {
        guard let item = salvageDetail.requestedItem else { return }
        let names = Array(Set([item.artReference?.imageName, item.artReference?.thumbnailImageName].compactMap(\.self)))
        await PreparedArtworkCache.shared.prepareAndPin(names: names)
        guard !Task.isCancelled, salvageDetail.requestedItem?.id == item.id else {
            PreparedArtworkCache.shared.releasePins(names: names)
            return
        }
        PreparedArtworkCache.shared.releasePins(names: pinnedArtwork)
        pinnedArtwork = names
        salvageDetail.selectedItem = item
        salvageDetail.requestedItem = nil
    }

    private func releaseUnusedArtwork() {
        guard salvageDetail.selectedItem == nil, salvageDetail.requestedItem == nil,
              salvageDetail.transmutationEvent == nil else { return }
        PreparedArtworkCache.shared.releasePins(names: pinnedArtwork)
        pinnedArtwork = []
    }

    private func cancelTransmutation() {
        salvageDetail.requestedItem = nil
        if let event = salvageDetail.transmutationEvent {
            salvageDetail.finishTransmutation(id: event.id)
        }
    }
}

extension View {
    func salvageInventoryPresentation(
        salvageDetail: Binding<SalvageDetailState>,
        hapticsEnabled: Bool,
    ) -> some View {
        modifier(
            SalvageInventoryPresentationModifier(
                salvageDetail: salvageDetail,
                hapticsEnabled: hapticsEnabled,
            ),
        )
    }
}
