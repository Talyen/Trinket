import SwiftUI
import TrinketDesignSystem

@MainActor
public struct ViewAllShelfCard: View {
    let remainingCount: Int?
    var accessibilityIdentifier: String?

    public init(
        remainingCount: Int? = nil,
        accessibilityIdentifier: String? = nil
    ) {
        self.remainingCount = remainingCount
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        ProductCardShell(
            appliesCardSurface: true,
            showsLabel: false,
            reservesLabelSpace: false,
            accessibilityID: accessibilityIdentifier
        ) {
            VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(TrinketDesign.Colors.accent)

                Text("View All")
                    .trinketTypography(.cardLabel)
                    .foregroundStyle(.primary)

                if let remainingCount, remainingCount > 0 {
                    Text("+\(remainingCount) more")
                        .trinketTypography(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .collectionShelfCardWidth()
    }
}
