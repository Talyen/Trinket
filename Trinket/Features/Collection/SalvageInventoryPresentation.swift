import SwiftUI
import TrinketAppState
import TrinketDesignSystem
import TrinketFeatureSupport

private struct SalvageInventoryPresentationModifier: ViewModifier {
    @Binding var salvageDetail: SalvageDetailState
    let hapticsEnabled: Bool

    func body(content: Content) -> some View {
        content
            .sheet(item: $salvageDetail.selectedItem) { item in
                SalvageItemDetailSheet(item: item) { result in
                    salvageDetail.salvageFinished(
                        result: result,
                        item: item,
                    )
                }
            }
            .overlay {
                if let event = salvageDetail.transmutationEvent {
                    SalvageTransmutationLayer(event: event) {
                        salvageDetail.finishTransmutation(id: event.id)
                    }
                }
            }
            .trinketSensoryFeedback(
                .success,
                trigger: salvageDetail.salvageSuccessCount,
                enabled: hapticsEnabled,
            )
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
