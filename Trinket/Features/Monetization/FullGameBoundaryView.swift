import SwiftUI
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport

struct FullGameBoundaryView: View {
    @Environment(\.requestFullGameOffer) private var requestOffer

    let title: String
    let origin: FullGameOfferOrigin

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            Label(title, systemImage: "lock")
                .trinketTypography(.sectionTitle)
            Text("Included with Full Game")
                .trinketTypography(.body)
                .foregroundStyle(.secondary)
            Button("View Full Game") { requestOffer(origin) }
                .frame(maxWidth: .infinity)
                .trinketPrimaryActionButton(accessibilityIdentifier: AccessibilityID.FullGame.boundary)
        }
        .padding(TrinketDesign.Layout.contentMargin)
    }
}
